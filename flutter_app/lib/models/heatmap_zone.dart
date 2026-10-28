import 'package:latlong2/latlong.dart';

enum HotspotCategoryGroup {
  civic,
  safety,
  missingPerson,
}

enum HotspotSeverity {
  low,
  medium,
  high,
}

class ComplaintSummary {
  final String id;
  final String title;
  final String category;
  final String status;
  final DateTime? createdAt;
  final String? address;

  const ComplaintSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    this.createdAt,
    this.address,
  });

  factory ComplaintSummary.fromJson(Map<String, dynamic> json) {
    return ComplaintSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['category']?.toString() ?? 'Community Report',
      category: json['category']?.toString() ?? 'general',
      status: json['status']?.toString() ?? 'open',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      address: json['address']?.toString(),
    );
  }
}

class HeatmapZone {
  final String id;
  final String zoneType;
  final HotspotCategoryGroup categoryGroup;
  final LatLng center;
  final double radiusMeters;
  final HotspotSeverity severity;
  final double riskScore;
  final int complaintCount;
  final String? assignedAuthorityId;
  final String? jurisdiction;
  final List<ComplaintSummary> complaints;

  const HeatmapZone({
    required this.id,
    required this.zoneType,
    required this.categoryGroup,
    required this.center,
    required this.radiusMeters,
    required this.severity,
    required this.riskScore,
    required this.complaintCount,
    this.assignedAuthorityId,
    this.jurisdiction,
    this.complaints = const [],
  });

  String get severityLabel {
    switch (severity) {
      case HotspotSeverity.low:
        return 'LOW';
      case HotspotSeverity.medium:
        return 'MEDIUM';
      case HotspotSeverity.high:
        return 'HIGH';
    }
  }

  String get categoryGroupLabel {
    switch (categoryGroup) {
      case HotspotCategoryGroup.civic:
        return 'Civic';
      case HotspotCategoryGroup.safety:
        return 'Public Safety';
      case HotspotCategoryGroup.missingPerson:
        return 'Missing Person';
    }
  }

  factory HeatmapZone.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['latitude']?.toString() ?? '') ?? 19.0760;
    final lng = double.tryParse(json['longitude']?.toString() ?? '') ?? 72.8777;
    final sevStr = (json['severity'] ?? 'LOW').toString().toUpperCase();
    final sev = sevStr == 'HIGH'
        ? HotspotSeverity.high
        : sevStr == 'MEDIUM'
            ? HotspotSeverity.medium
            : HotspotSeverity.low;

    final groupStr = (json['category_group'] ?? '').toString().toLowerCase();
    HotspotCategoryGroup group = HotspotCategoryGroup.civic;
    if (groupStr.contains('missing')) {
      group = HotspotCategoryGroup.missingPerson;
    } else if (groupStr.contains('safety')) {
      group = HotspotCategoryGroup.safety;
    }

    final rawList = json['complaints'] as List? ?? [];
    final compSummaries = rawList
        .whereType<Map<String, dynamic>>()
        .map((m) => ComplaintSummary.fromJson(m))
        .toList();

    return HeatmapZone(
      id: json['id']?.toString() ?? '',
      zoneType: json['zone_type']?.toString() ?? 'General',
      categoryGroup: group,
      center: LatLng(lat, lng),
      radiusMeters: double.tryParse(json['radius_meters']?.toString() ?? '') ?? 150.0,
      severity: sev,
      riskScore: double.tryParse(json['risk_score']?.toString() ?? '') ?? 0.0,
      complaintCount: int.tryParse(json['complaint_count']?.toString() ?? '') ?? compSummaries.length,
      assignedAuthorityId: json['assigned_authority_id']?.toString(),
      jurisdiction: json['jurisdiction']?.toString(),
      complaints: compSummaries,
    );
  }
}
