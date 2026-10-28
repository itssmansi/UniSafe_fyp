import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/heatmap_zone.dart';

class HeatmapService {
  final SupabaseClient _supabase;

  HeatmapService({SupabaseClient? client})
      : _supabase = client ?? SupabaseConfig.client;

  // In-memory cache for fast responsive filtering
  List<HeatmapZone>? _cachedZones;
  DateTime? _lastFetchTime;

  static const List<String> _civicKeywords = [
    'greenery',
    'infrastructure',
    'sanitation',
    'garbage',
    'road',
    'potholes',
    'drainage',
    'water',
    'water logging',
    'streetlight',
    'nonfunctional street lights',
    'road damage',
    'garbage scattered on road',
    'public washroom cleanliness',
    'open manholes',
    'non-existent footpath',
    'garbage dumping near beach/river',
    'poor landscape maintenance',
  ];

  static const List<String> _safetyKeywords = [
    'safety',
    'theft',
    'theft / robbery',
    'assault / violence',
    'harassment / eve-teasing',
    'women safety',
    'stray animal threat',
    'illegal parking',
  ];

  HotspotCategoryGroup classifyCategory(String category) {
    final c = category.trim().toLowerCase();
    if (c.contains('missing')) return HotspotCategoryGroup.missingPerson;
    if (_safetyKeywords.any((k) => c.contains(k) || k.contains(c))) {
      return HotspotCategoryGroup.safety;
    }
    return HotspotCategoryGroup.civic;
  }

  /// Calculates Haversine distance in meters between two coordinates.
  double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371008.8; // Earth radius in meters
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// 4-factor deterministic scoring algorithm matching hackathon implementation
  Map<String, dynamic> scoreCluster(List<Map<String, dynamic>> items, {DateTime? refDate}) {
    final count = items.length;
    if (count == 0) {
      return {'riskScore': 0.0, 'severity': HotspotSeverity.low};
    }

    final reference = refDate ?? DateTime.now();

    // 1. Density Score (up to 40 pts)
    final densityScore = math.min(count / 20.0, 1.0) * 40.0;

    // 2. Upvote Score (up to 25 pts)
    int totalUpvotes = 0;
    for (final it in items) {
      final u = int.tryParse(it['upvote_count']?.toString() ?? '0') ?? 0;
      totalUpvotes += u;
    }
    final upvoteScore = math.min(totalUpvotes / 150.0, 1.0) * 25.0;

    // 3. Unresolved Status Score (up to 20 pts)
    int unresolvedCount = 0;
    for (final it in items) {
      final s = (it['status'] ?? 'open').toString().toLowerCase();
      if (['open', 'pending', 'in_progress', 'manual_review', 'investigating', 'missing'].contains(s)) {
        unresolvedCount++;
      }
    }
    final unresolvedScore = (unresolvedCount / count.toDouble()) * 20.0;

    // 4. Recency Score (up to 15 pts)
    double recencySum = 0.0;
    for (final it in items) {
      final dateStr = it['created_at'] ?? it['last_seen_date'];
      if (dateStr == null) {
        recencySum += 0.5;
        continue;
      }
      final d = DateTime.tryParse(dateStr.toString()) ?? reference;
      final daysDiff = reference.difference(d).inSeconds / (24 * 3600);
      if (daysDiff <= 7) {
        recencySum += 1.0;
      } else if (daysDiff <= 14) {
        recencySum += 0.8;
      } else if (daysDiff <= 30) {
        recencySum += 0.5;
      } else {
        recencySum += 0.2;
      }
    }
    final recencyScore = (recencySum / count.toDouble()) * 15.0;

    final totalRisk = double.parse((densityScore + upvoteScore + unresolvedScore + recencyScore).toStringAsFixed(2));

    HotspotSeverity severity = HotspotSeverity.low;
    if (totalRisk >= 60.0) {
      severity = HotspotSeverity.high;
    } else if (totalRisk >= 30.0) {
      severity = HotspotSeverity.medium;
    }

    return {
      'riskScore': totalRisk,
      'severity': severity,
    };
  }

  /// Fetches citizen heatmap data (combining permitted civic complaints, public safety incidents, and missing persons)
  Future<List<HeatmapZone>> fetchCitizenHeatmap({
    String? categoryFilter, // 'all', 'civic', 'safety', 'missing_person'
    String? severityFilter, // 'ALL', 'HIGH', 'MEDIUM', 'LOW'
    String? timeRange, // 'all', '30d', '7d'
    bool forceRefresh = false,
  }) async {
    // Check in-memory cache (valid for 60 seconds unless forceRefresh)
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedZones != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inSeconds < 60) {
      return _applyClientFilters(_cachedZones!, categoryFilter, severityFilter, timeRange);
    }

    try {
      // 1. Fetch complaints with valid GPS coordinates
      var compQuery = _supabase
          .from('complaints')
          .select('id, category, title, description, latitude, longitude, address, status, upvote_count, created_at, department, jurisdiction')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (timeRange == '7d') {
        final d = now.subtract(const Duration(days: 7));
        compQuery = compQuery.gte('created_at', d.toIso8601String());
      } else if (timeRange == '30d') {
        final d = now.subtract(const Duration(days: 30));
        compQuery = compQuery.gte('created_at', d.toIso8601String());
      }

      final List<dynamic> complaintsData = await compQuery;

      // 2. Fetch public missing persons
      var mpQuery = _supabase
          .from('missing_persons')
          .select('id, full_name, age, gender, last_seen_date, latitude, longitude, description, status, case_code, created_at')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (timeRange == '7d') {
        final d = now.subtract(const Duration(days: 7));
        mpQuery = mpQuery.gte('created_at', d.toIso8601String());
      } else if (timeRange == '30d') {
        final d = now.subtract(const Duration(days: 30));
        mpQuery = mpQuery.gte('created_at', d.toIso8601String());
      }

      final List<dynamic> mpData = await mpQuery;

      // Transform missing persons into clusterable records (sanitized for public citizen privacy)
      final List<Map<String, dynamic>> combinedPoints = [];

      for (final raw in complaintsData) {
        if (raw is Map<String, dynamic>) {
          final lat = double.tryParse(raw['latitude']?.toString() ?? '');
          final lng = double.tryParse(raw['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            final cat = raw['category']?.toString() ?? 'general';
            combinedPoints.add({
              'id': raw['id']?.toString() ?? '',
              'category': cat,
              'categoryGroup': classifyCategory(cat),
              'title': raw['title']?.toString() ?? '$cat issue',
              'description': raw['description']?.toString(),
              'latitude': lat,
              'longitude': lng,
              'address': raw['address']?.toString(),
              'status': raw['status']?.toString() ?? 'open',
              'upvote_count': raw['upvote_count'] ?? 0,
              'created_at': raw['created_at'],
              'jurisdiction': raw['jurisdiction'],
            });
          }
        }
      }

      for (final raw in mpData) {
        if (raw is Map<String, dynamic>) {
          final lat = double.tryParse(raw['latitude']?.toString() ?? '');
          final lng = double.tryParse(raw['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            final code = raw['case_code']?.toString() ?? raw['id']?.toString().substring(0, 6) ?? 'MP';
            final age = raw['age'] != null ? '${raw['age']} yrs' : '';
            final gender = raw['gender']?.toString() ?? '';
            final desc = raw['description']?.toString() ?? '';
            combinedPoints.add({
              'id': raw['id']?.toString() ?? '',
              'category': 'Missing Person',
              'categoryGroup': HotspotCategoryGroup.missingPerson,
              'title': 'Active Missing Person Case #$code',
              'description': '$gender $age. $desc'.trim(),
              'latitude': lat,
              'longitude': lng,
              'address': 'Last reported area',
              'status': raw['status']?.toString() ?? 'Missing',
              'upvote_count': 5,
              'created_at': raw['created_at'] ?? raw['last_seen_date'],
            });
          }
        }
      }

      if (combinedPoints.isEmpty) {
        _cachedZones = [];
        _lastFetchTime = now;
        return [];
      }

      // 3. Perform DBSCAN spatial clustering (eps = 500m, minSamples = 2)
      final zones = _clusterPointsIntoZones(combinedPoints);

      _cachedZones = zones;
      _lastFetchTime = now;

      return _applyClientFilters(zones, categoryFilter, severityFilter, timeRange);
    } catch (e) {
      // Fallback on cached data if network error occurs
      if (_cachedZones != null && _cachedZones!.isNotEmpty) {
        return _applyClientFilters(_cachedZones!, categoryFilter, severityFilter, timeRange);
      }
      rethrow;
    }
  }

  /// Spatial DBSCAN grouping
  List<HeatmapZone> _clusterPointsIntoZones(List<Map<String, dynamic>> points) {
    const double epsMeters = 500.0;
    const int minSamples = 2;
    final int n = points.length;

    final List<bool> visited = List.filled(n, false);
    final List<int> clusterLabels = List.filled(n, -1);
    int clusterId = 0;

    for (int i = 0; i < n; i++) {
      if (visited[i]) continue;
      visited[i] = true;

      final neighbors = <int>[];
      for (int j = 0; j < n; j++) {
        final d = calculateDistanceMeters(
          points[i]['latitude'],
          points[i]['longitude'],
          points[j]['latitude'],
          points[j]['longitude'],
        );
        if (d <= epsMeters) {
          neighbors.push(j);
        }
      }

      if (neighbors.length < minSamples) {
        clusterLabels[i] = -1;
      } else {
        clusterLabels[i] = clusterId;
        final queue = neighbors.where((idx) => idx != i).toList();

        for (int k = 0; k < queue.length; k++) {
          final qIdx = queue[k];
          if (!visited[qIdx]) {
            visited[qIdx] = true;
            final qNeighbors = <int>[];
            for (int j = 0; j < n; j++) {
              final d = calculateDistanceMeters(
                points[qIdx]['latitude'],
                points[qIdx]['longitude'],
                points[j]['latitude'],
                points[j]['longitude'],
              );
              if (d <= epsMeters) {
                qNeighbors.push(j);
              }
            }
            if (qNeighbors.length >= minSamples) {
              for (final qn in qNeighbors) {
                if (!queue.contains(qn) && qn != i) {
                  queue.add(qn);
                }
              }
            }
          }
          if (clusterLabels[qIdx] == -1) {
            clusterLabels[qIdx] = clusterId;
          }
        }
        clusterId++;
      }
    }

    // Group items into cluster buckets
    final Map<int, List<Map<String, dynamic>>> clusterBuckets = {};
    final List<Map<String, dynamic>> unclustered = [];

    for (int i = 0; i < n; i++) {
      final cId = clusterLabels[i];
      if (cId >= 0) {
        clusterBuckets.putIfAbsent(cId, () => []).add(points[i]);
      } else {
        unclustered.add(points[i]);
      }
    }

    final List<HeatmapZone> zones = [];

    // Process clusters
    clusterBuckets.forEach((cId, items) {
      final count = items.length;
      final centerLat = items.fold(0.0, (sum, it) => sum + (it['latitude'] as double)) / count;
      final centerLng = items.fold(0.0, (sum, it) => sum + (it['longitude'] as double)) / count;

      double maxDist = 0.0;
      for (final it in items) {
        final d = calculateDistanceMeters(centerLat, centerLng, it['latitude'], it['longitude']);
        if (d > maxDist) maxDist = d;
      }
      final radius = math.max(maxDist.ceilToDouble(), 150.0);

      // Dominant category
      final Map<String, int> catCounts = {};
      final Map<HotspotCategoryGroup, int> groupCounts = {};
      for (final it in items) {
        final c = it['category']?.toString() ?? 'general';
        final g = it['categoryGroup'] as HotspotCategoryGroup? ?? HotspotCategoryGroup.civic;
        catCounts[c] = (catCounts[c] ?? 0) + 1;
        groupCounts[g] = (groupCounts[g] ?? 0) + 1;
      }

      final dominantCategory = catCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final dominantGroup = groupCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      final scoreRes = scoreCluster(items);
      final isMissing = dominantGroup == HotspotCategoryGroup.missingPerson;

      zones.add(HeatmapZone(
        id: 'cluster-$cId',
        zoneType: dominantCategory,
        categoryGroup: dominantGroup,
        center: LatLng(centerLat, centerLng),
        radiusMeters: radius,
        severity: isMissing ? HotspotSeverity.high : scoreRes['severity'],
        riskScore: isMissing ? 85.0 : scoreRes['riskScore'],
        complaintCount: count,
        jurisdiction: items.first['jurisdiction']?.toString(),
        complaints: items.take(10).map((it) => ComplaintSummary.fromJson(it)).toList(),
      ));
    });

    // Also include single incident points
    for (int i = 0; i < unclustered.length; i++) {
      final p = unclustered[i];
      final group = p['categoryGroup'] as HotspotCategoryGroup? ?? HotspotCategoryGroup.civic;
      final isMissing = group == HotspotCategoryGroup.missingPerson;
      final scoreRes = scoreCluster([p]);

      zones.add(HeatmapZone(
        id: 'single-${p['id'] ?? i}',
        zoneType: p['category']?.toString() ?? 'Incident',
        categoryGroup: group,
        center: LatLng(p['latitude'], p['longitude']),
        radiusMeters: isMissing ? 200.0 : 120.0,
        severity: isMissing ? HotspotSeverity.high : scoreRes['severity'],
        riskScore: isMissing ? 75.0 : scoreRes['riskScore'],
        complaintCount: 1,
        jurisdiction: p['jurisdiction']?.toString(),
        complaints: [ComplaintSummary.fromJson(p)],
      ));
    }

    // Sort: HIGH > MEDIUM > LOW
    zones.sort((a, b) {
      final order = {HotspotSeverity.high: 1, HotspotSeverity.medium: 2, HotspotSeverity.low: 3};
      return (order[a.severity] ?? 4).compareTo(order[b.severity] ?? 4);
    });

    return zones;
  }

  List<HeatmapZone> _applyClientFilters(
    List<HeatmapZone> zones,
    String? categoryFilter,
    String? severityFilter,
    String? timeRange,
  ) {
    var result = List<HeatmapZone>.from(zones);

    if (categoryFilter != null && categoryFilter.toLowerCase() != 'all') {
      final cf = categoryFilter.toLowerCase();
      if (cf == 'civic') {
        result = result.where((z) => z.categoryGroup == HotspotCategoryGroup.civic).toList();
      } else if (cf == 'safety') {
        result = result.where((z) => z.categoryGroup == HotspotCategoryGroup.safety).toList();
      } else if (cf.contains('missing')) {
        result = result.where((z) => z.categoryGroup == HotspotCategoryGroup.missingPerson).toList();
      } else {
        result = result.where((z) => z.zoneType.toLowerCase().contains(cf) || cf.contains(z.zoneType.toLowerCase())).toList();
      }
    }

    if (severityFilter != null && severityFilter.toUpperCase() != 'ALL') {
      final sf = severityFilter.toUpperCase();
      result = result.where((z) => z.severityLabel == sf).toList();
    }

    return result;
  }
}

extension _ListPush<T> on List<T> {
  void push(T val) => add(val);
}
