import 'dart:convert';
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

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String streetName;
  final bool isAccurate;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.streetName,
    this.isAccurate = true,
  });
}

class RouteService {
  final Distance _distanceCalc = const Distance();

  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&limit=5&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'UniSafeApp/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) {
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            final displayName = item['display_name']?.toString() ?? clean;
            final parts = displayName.split(',');
            final title = parts.isNotEmpty ? parts.first.trim() : clean;
            final subtitle =
                parts.length > 1 ? parts.sublist(1).take(2).join(',').trim() : '';

            return PlaceSearchResult(
              title: title,
              subtitle: subtitle,
              coordinates: LatLng(lat, lon),
            );
          }).toList();
        }
      }
    } catch (_) {}

    final base = proximity ?? const LatLng(19.0760, 72.8777);
    return [
      PlaceSearchResult(
        title: clean,
        subtitle: 'Approximate area location',
        coordinates: LatLng(base.latitude + 0.012, base.longitude + 0.008),
      ),
    ];
  }

  Future<RouteResult> getRoute(LatLng start, LatLng destination) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0];
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

          // Attempt to extract the primary street name from legs
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

          return RouteResult(
            points: points,
            distanceKm: double.parse((distanceMeters / 1000).toStringAsFixed(1)),
            durationMinutes: (durationSeconds / 60).round(),
            streetName: street,
            isAccurate: true,
          );
        }
      }
    } catch (_) {
      // Fallback to straight line estimate if offline or rate-limited
    }

    // Direct path fallback
    final meters = _distanceCalc.as(LengthUnit.Meter, start, destination);
    final km = double.parse((meters / 1000).toStringAsFixed(1));
    // Estimate 25 km/h average speed in city
    final estMinutes = ((km / 25) * 60).round().clamp(1, 999);

    return RouteResult(
      points: [start, destination],
      distanceKm: km,
      durationMinutes: estMinutes,
      streetName: 'Direct Suggested Route',
      isAccurate: false,
    );
  }
}
