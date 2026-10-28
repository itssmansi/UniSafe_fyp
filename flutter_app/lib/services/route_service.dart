import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSearchResult {
  final String title;
  final String subtitle;
  final LatLng coordinates;

  const PlaceSearchResult({
    required this.title,
    required this.subtitle,
    required this.coordinates,
  });
}

enum TransportMode {
  driving,
  walking,
  cycling,
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final int trafficDelayMinutes;
  final String streetName;
  final bool isAccurate;
  final List<RouteOption> alternatives;
  final TransportMode mode;
  final bool isNativeEngine;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.trafficDelayMinutes = 0,
    required this.streetName,
    this.isAccurate = true,
    this.alternatives = const [],
    this.mode = TransportMode.driving,
    this.isNativeEngine = true,
  });
}

class RouteOption {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final int trafficDelayMinutes;
  final String streetName;
  final TransportMode mode;
  final bool isNativeEngine;

  const RouteOption({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.trafficDelayMinutes = 0,
    required this.streetName,
    this.mode = TransportMode.driving,
    this.isNativeEngine = true,
  });
}

class RouteService {
  final Distance _distanceCalc = const Distance();
  static final Map<String, List<PlaceSearchResult>> _searchCache = {};
  static DateTime? _lastSearchAt;
  static int _searchGeneration = 0;

  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final proximityKey = proximity == null
        ? ''
        : '|${proximity.latitude.toStringAsFixed(2)},${proximity.longitude.toStringAsFixed(2)}';
    final cacheKey = '${clean.toLowerCase()}|in$proximityKey';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;
    final generation = ++_searchGeneration;
    final lastSearch = _lastSearchAt;
    if (lastSearch != null) {
      final wait =
          const Duration(seconds: 1) - DateTime.now().difference(lastSearch);
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }
    if (generation != _searchGeneration) return [];
    _lastSearchAt = DateTime.now();

    try {
      final queryParams = <String, String>{
        'q': clean,
        'countrycodes': 'in',
        'format': 'jsonv2',
        'limit': '10',
        'addressdetails': '1',
        'accept-language': 'en-IN,en',
      };

      // When proximity is provided, bias results towards user location in India
      if (proximity != null) {
        final minLon = (proximity.longitude - 0.5).toStringAsFixed(4);
        final maxLat = (proximity.latitude + 0.5).toStringAsFixed(4);
        final maxLon = (proximity.longitude + 0.5).toStringAsFixed(4);
        final minLat = (proximity.latitude - 0.5).toStringAsFixed(4);
        queryParams['viewbox'] = '$minLon,$maxLat,$maxLon,$minLat';
        queryParams['bounded'] = '0'; // Prioritize nearby without excluding rest of India
      }

      final url = Uri.https('nominatim.openstreetmap.org', '/search', queryParams);
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'UniSafeCitizen/1.0 (India journey planner)',
              'Accept-Language': 'en-IN,en',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final places = data
              .map((item) {
                final lat =
                    double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
                final lon =
                    double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
                final displayName = item['display_name']?.toString() ?? clean;
                final parts = displayName.split(',');
                final title = parts.isNotEmpty ? parts.first.trim() : clean;
                final subtitle = parts.length > 1
                    ? parts.sublist(1).take(2).join(',').trim()
                    : '';

                return PlaceSearchResult(
                  title: title,
                  subtitle: subtitle,
                  coordinates: LatLng(lat, lon),
                );
              })
              .where((place) {
                final lat = place.coordinates.latitude;
                final lon = place.coordinates.longitude;
                // Strictly restrict to Indian geographical boundaries
                return lat >= 6.0 && lat <= 38.5 && lon >= 68.0 && lon <= 98.5;
              })
              .toList();

          if (proximity != null) {
            places.sort(
              (left, right) => _distanceCalc
                  .as(LengthUnit.Meter, proximity, left.coordinates)
                  .compareTo(
                    _distanceCalc.as(
                      LengthUnit.Meter,
                      proximity,
                      right.coordinates,
                    ),
                  ),
            );
          }
          _searchCache[cacheKey] = places;
          _lastSearchAt = DateTime.now();
          return places;
        } else {
          // Legitimate empty results for this query in India
          _searchCache[cacheKey] = const [];
          _lastSearchAt = DateTime.now();
          return [];
        }
      }
    } on TimeoutException {
      // Network timeout - do not cache failure
    } catch (_) {
      // Network or parsing error - return empty without caching
    }

    return [];
  }

  Future<RouteResult> getRoute(
    LatLng start,
    LatLng destination, {
    TransportMode mode = TransportMode.driving,
  }) async {
    final osmInstance = mode == TransportMode.walking
        ? 'routed-foot'
        : mode == TransportMode.cycling
            ? 'routed-bike'
            : 'routed-car';
    final osmProfile = mode == TransportMode.walking
        ? 'foot'
        : mode == TransportMode.cycling
            ? 'bicycle'
            : 'driving';

    final coords =
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}';

    // List of candidate endpoints: 1. Native mode-specific engine, 2. Standard car fallback
    final endpoints = [
      (
        'https://routing.openstreetmap.de/$osmInstance/route/v1/$osmProfile/$coords?overview=full&geometries=geojson&steps=true&alternatives=true',
        true,
      ),
      (
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true&alternatives=true',
        mode == TransportMode.driving,
      ),
    ];

    for (final candidate in endpoints) {
      final endpointUrl = candidate.$1;
      final isNativeProfile = candidate.$2;
      try {
        final response = await http
            .get(
              Uri.parse(endpointUrl),
              headers: {'User-Agent': 'UniSafeCitizen/1.0 (Safe Route Planning)'},
            )
            .timeout(const Duration(seconds: 7));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final routes = data['routes'] as List<dynamic>?;

          if (routes != null && routes.isNotEmpty) {
            final parsedRoutes = routes
                .map((r) => _parseRoute(r, mode, isNativeProfile: isNativeProfile))
                .toList();
            final firstRoute = parsedRoutes.first;
            return RouteResult(
              points: firstRoute.points,
              distanceKm: firstRoute.distanceKm,
              durationMinutes: firstRoute.durationMinutes,
              trafficDelayMinutes: firstRoute.trafficDelayMinutes,
              streetName: firstRoute.streetName,
              isAccurate: true,
              alternatives: parsedRoutes,
              mode: mode,
              isNativeEngine: isNativeProfile,
            );
          }
        }
      } catch (_) {
        continue;
      }
    }

    final meters = _distanceCalc.as(LengthUnit.Meter, start, destination);
    final km = double.parse((meters / 1000).toStringAsFixed(1));
    final double speedKmH = mode == TransportMode.walking
        ? 4.8
        : mode == TransportMode.cycling
            ? 15.0
            : 24.0;
    final estMinutes = ((km / speedKmH) * 60).round().clamp(1, 999);
    final freeFlowMins = mode == TransportMode.driving ? ((km / 45.0) * 60).round() : estMinutes;
    final trafficDelay = mode == TransportMode.driving ? math.max(1, estMinutes - freeFlowMins) : 0;

    return RouteResult(
      points: [start, destination],
      distanceKm: km,
      durationMinutes: estMinutes,
      trafficDelayMinutes: trafficDelay,
      streetName: 'Approximate direct line',
      isAccurate: false,
      mode: mode,
      isNativeEngine: false,
    );
  }

  RouteOption _parseRoute(
    dynamic value,
    TransportMode mode, {
    bool isNativeProfile = true,
  }) {
    final firstRoute = value as Map<String, dynamic>;
    final geometry = firstRoute['geometry'] as Map<String, dynamic>;
    final rawCoords = geometry['coordinates'] as List<dynamic>;

    final points = rawCoords.map((coord) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();

    final double distanceMeters =
        (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final double durationSeconds =
        (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

    int durationMinutes;
    int trafficDelayMinutes = 0;

    if (isNativeProfile) {
      final baseMinutes = (durationSeconds / 60).round();
      if (mode == TransportMode.driving) {
        // OSRM calculates theoretical speed limit duration without traffic.
        // Factor in realistic urban traffic flow (~22-26 km/h actual traffic speed).
        final double distanceKm = distanceMeters / 1000.0;
        final double freeFlowSpeedKmH =
            baseMinutes > 0 ? (distanceKm / (baseMinutes / 60.0)) : 40.0;
        if (freeFlowSpeedKmH > 24.0) {
          const double urbanTrafficSpeedKmH = 24.0;
          final int trafficDuration =
              ((distanceKm / urbanTrafficSpeedKmH) * 60).round();
          trafficDelayMinutes = math.max(0, trafficDuration - baseMinutes);
          durationMinutes = baseMinutes + trafficDelayMinutes;
        } else {
          durationMinutes = baseMinutes;
        }
      } else {
        durationMinutes = baseMinutes;
      }
    } else {
      if (mode == TransportMode.walking) {
        durationMinutes = (distanceMeters / 80.0).round();
      } else if (mode == TransportMode.cycling) {
        durationMinutes = (distanceMeters / 250.0).round();
      } else {
        final double distanceKm = distanceMeters / 1000.0;
        final baseMinutes = (durationSeconds / 60).round();
        final trafficDuration = ((distanceKm / 24.0) * 60).round();
        trafficDelayMinutes = math.max(0, trafficDuration - baseMinutes);
        durationMinutes = baseMinutes + trafficDelayMinutes;
      }
    }
    if (durationMinutes < 1) durationMinutes = 1;

    String street = 'Suggested Route';
    final legs = firstRoute['legs'] as List<dynamic>?;
    if (legs != null && legs.isNotEmpty) {
      final steps = legs[0]['steps'] as List<dynamic>?;
      if (steps != null && steps.isNotEmpty) {
        for (final step in steps) {
          final name = step['name']?.toString();
          if (name != null && name.trim().isNotEmpty) {
            street = name;
            break;
          }
        }
      }
    }

    return RouteOption(
      points: points,
      distanceKm: double.parse((distanceMeters / 1000).toStringAsFixed(1)),
      durationMinutes: durationMinutes,
      trafficDelayMinutes: trafficDelayMinutes,
      streetName: street,
      mode: mode,
      isNativeEngine: isNativeProfile,
    );
  }
}
