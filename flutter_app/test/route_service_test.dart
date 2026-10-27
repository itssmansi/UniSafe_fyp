import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/route_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('RouteService and PlaceSearchResult', () {
    final service = RouteService();

    test('searchPlaces returns empty immediately for blank query', () async {
      final res1 = await service.searchPlaces('');
      final res2 = await service.searchPlaces('   ');
      expect(res1, isEmpty);
      expect(res2, isEmpty);
    });

    test('PlaceSearchResult correctly retains Indian coordinates and titles', () {
      const place = PlaceSearchResult(
        title: 'Andheri West',
        subtitle: 'Mumbai, Maharashtra',
        coordinates: LatLng(19.1197, 72.8468),
      );
      expect(place.title, 'Andheri West');
      expect(place.subtitle, 'Mumbai, Maharashtra');
      expect(place.coordinates.latitude, 19.1197);
      expect(place.coordinates.longitude, 72.8468);
    });

    test('RouteOption supports transport modes', () {
      const routeDriving = RouteOption(
        points: [LatLng(19.0760, 72.8777), LatLng(19.1197, 72.8468)],
        distanceKm: 5.4,
        durationMinutes: 18,
        streetName: 'Western Express Highway',
        mode: TransportMode.driving,
      );
      expect(routeDriving.mode, TransportMode.driving);
      expect(routeDriving.distanceKm, 5.4);

      const routeWalking = RouteOption(
        points: [LatLng(19.0760, 72.8777), LatLng(19.1197, 72.8468)],
        distanceKm: 5.4,
        durationMinutes: 65,
        streetName: 'Western Express Highway',
        mode: TransportMode.walking,
      );
      expect(routeWalking.mode, TransportMode.walking);
      expect(routeWalking.durationMinutes, 65);

      const routeCycling = RouteOption(
        points: [LatLng(19.0760, 72.8777), LatLng(19.1197, 72.8468)],
        distanceKm: 5.4,
        durationMinutes: 22,
        streetName: 'Western Express Highway',
        mode: TransportMode.cycling,
      );
      expect(routeCycling.mode, TransportMode.cycling);
      expect(routeCycling.durationMinutes, 22);
    });

    test('RouteResult reflects selected mode and alternatives', () {
      const result = RouteResult(
        points: [LatLng(19.0760, 72.8777), LatLng(19.1197, 72.8468)],
        distanceKm: 5.4,
        durationMinutes: 65,
        streetName: 'Western Express Highway',
        mode: TransportMode.walking,
      );
      expect(result.mode, TransportMode.walking);
      expect(result.durationMinutes, 65);
      expect(result.isAccurate, isTrue);
    });
  });
}
