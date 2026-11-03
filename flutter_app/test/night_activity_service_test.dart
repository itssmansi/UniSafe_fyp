import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/night_activity_service.dart';
import 'package:flutter_app/services/route_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const route = RouteOption(
    points: [LatLng(19, 72), LatLng(19, 72.02)],
    distanceKm: 2.2,
    durationMinutes: 12,
    streetName: 'Mapped road',
  );

  test('score is unavailable when no route places were returned', () {
    final summary = NightActivityService().summarize(route, const []);

    expect(summary.score, isNull);
    expect(summary.places, isEmpty);
    expect(
      summary.components.every((component) => component.points == null),
      isTrue,
    );
  });

  test(
    'score uses only mapped route places and marks missing road data unknown',
    () {
      final places = [
        const RouteNearbyPlace(
          id: 'node:1',
          name: 'Mapped shop',
          category: 'Shop or food',
          position: LatLng(19, 72.002),
        ),
        const RouteNearbyPlace(
          id: 'node:2',
          name: 'Mapped pharmacy',
          category: 'Pharmacy',
          position: LatLng(19, 72.01),
        ),
        const RouteNearbyPlace(
          id: 'node:3',
          name: 'Mapped bus stop',
          category: 'Transport',
          position: LatLng(19, 72.018),
        ),
      ];

      final summary = NightActivityService().summarize(route, places);
      final shops = summary.components.firstWhere(
        (item) => item.name == 'Mapped shops and food',
      );
      final roads = summary.components.firstWhere(
        (item) => item.name == 'Main-road coverage',
      );

      expect(summary.score, inInclusiveRange(0, 100));
      expect(summary.places, hasLength(3));
      expect(shops.points, 2);
      expect(roads.points, isNull);
      expect(roads.maximum, isNull);
    },
  );
}
