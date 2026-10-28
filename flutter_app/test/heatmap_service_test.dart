import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:unisafe/models/heatmap_zone.dart';
import 'package:unisafe/services/heatmap_service.dart';

void main() {
  group('HeatmapService Category Classification Tests', () {
    final service = HeatmapService();

    test('Classifies civic categories correctly', () {
      expect(service.classifyCategory('garbage'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('potholes'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('road damage'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('drainage'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('water logging'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('streetlight'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('greenery'), HotspotCategoryGroup.civic);
      expect(service.classifyCategory('Poor Landscape Maintenance'), HotspotCategoryGroup.civic);
    });

    test('Classifies safety categories correctly', () {
      expect(service.classifyCategory('safety'), HotspotCategoryGroup.safety);
      expect(service.classifyCategory('Theft'), HotspotCategoryGroup.safety);
      expect(service.classifyCategory('Theft / Robbery'), HotspotCategoryGroup.safety);
      expect(service.classifyCategory('Assault / Violence'), HotspotCategoryGroup.safety);
      expect(service.classifyCategory('Harassment / Eve-Teasing'), HotspotCategoryGroup.safety);
      expect(service.classifyCategory('Women Safety'), HotspotCategoryGroup.safety);
    });

    test('Classifies missing person category correctly', () {
      expect(service.classifyCategory('Missing Person'), HotspotCategoryGroup.missingPerson);
      expect(service.classifyCategory('missing_person'), HotspotCategoryGroup.missingPerson);
    });
  });

  group('HeatmapService Haversine Distance Tests', () {
    final service = HeatmapService();

    test('Computes accurate Haversine distance in meters', () {
      // Distance between Gateway of India (18.9220, 72.8347) and Marine Drive (18.9432, 72.8230) ~ 2.6 km
      final dist = service.calculateDistanceMeters(18.9220, 72.8347, 18.9432, 72.8230);
      expect(dist, greaterThan(2300));
      expect(dist, lessThan(2800));
    });

    test('Identical points return zero distance', () {
      final dist = service.calculateDistanceMeters(19.0760, 72.8777, 19.0760, 72.8777);
      expect(dist, lessThan(0.001));
    });
  });

  group('HeatmapService Scoring Algorithm Tests', () {
    final service = HeatmapService();

    test('Scores high risk cluster with high density and open complaints', () {
      final now = DateTime.now();
      // 25 open recent complaints with upvotes
      final items = List.generate(
        25,
        (i) => {
          'status': 'open',
          'upvote_count': 10,
          'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        },
      );

      final scoreRes = service.scoreCluster(items, refDate: now);
      expect(scoreRes['riskScore'], greaterThanOrEqualTo(60.0));
      expect(scoreRes['severity'], HotspotSeverity.high);
    });

    test('Scores low risk cluster for few resolved older complaints', () {
      final now = DateTime.now();
      final items = List.generate(
        2,
        (i) => {
          'status': 'resolved',
          'upvote_count': 0,
          'created_at': now.subtract(const Duration(days: 45)).toIso8601String(),
        },
      );

      final scoreRes = service.scoreCluster(items, refDate: now);
      expect(scoreRes['riskScore'], lessThan(30.0));
      expect(scoreRes['severity'], HotspotSeverity.low);
    });
  });

  group('HeatmapZone Model Tests', () {
    test('Constructs HeatmapZone and parses from JSON', () {
      final json = {
        'id': 'zone-123',
        'zone_type': 'potholes',
        'category_group': 'civic',
        'latitude': 19.0760,
        'longitude': 72.8777,
        'radius_meters': 250,
        'severity': 'HIGH',
        'risk_score': 74.5,
        'complaint_count': 12,
        'jurisdiction': 'Ward K-West',
        'complaints': [
          {
            'id': 'c-1',
            'title': 'Deep pothole on SV Road',
            'category': 'potholes',
            'status': 'open',
          }
        ],
      };

      final zone = HeatmapZone.fromJson(json);
      expect(zone.id, 'zone-123');
      expect(zone.zoneType, 'potholes');
      expect(zone.categoryGroup, HotspotCategoryGroup.civic);
      expect(zone.center, const LatLng(19.0760, 72.8777));
      expect(zone.radiusMeters, 250.0);
      expect(zone.severity, HotspotSeverity.high);
      expect(zone.severityLabel, 'HIGH');
      expect(zone.riskScore, 74.5);
      expect(zone.complaintCount, 12);
      expect(zone.jurisdiction, 'Ward K-West');
      expect(zone.complaints.length, 1);
      expect(zone.complaints.first.title, 'Deep pothole on SV Road');
    });
  });
}
