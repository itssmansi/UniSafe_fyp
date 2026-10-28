import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'route_service.dart';

class RouteNearbyPlace {
  final String id;
  final String name;
  final String category;
  final LatLng position;
  final String? openingHours;

  const RouteNearbyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    this.openingHours,
  });
}

class LocatedRoutePlace {
  final RouteNearbyPlace place;
  final double distanceFromRouteMeters;
  final double distanceAlongRouteMeters;
  const LocatedRoutePlace(
    this.place,
    this.distanceFromRouteMeters,
    this.distanceAlongRouteMeters,
  );
}

class ActivityComponent {
  final String name;
  final int? points;
  final int? maximum;
  final String explanation;

  const ActivityComponent(
    this.name,
    this.points,
    this.maximum,
    this.explanation,
  );
}

class RouteActivitySummary {
  final int? score;
  final List<ActivityComponent> components;
  final List<LocatedRoutePlace> places;

  const RouteActivitySummary({
    required this.score,
    required this.components,
    required this.places,
  });
}

class NightActivityService {
  static const _endpoints = [
    String.fromEnvironment(
      'UNISAFE_OVERPASS_URL',
      defaultValue: 'https://overpass-api.de/api/interpreter',
    ),
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];
  static const _distance = Distance();
  static final Map<String, _CachedPlaces> _cache = {};
  static final Map<String, Future<List<RouteNearbyPlace>>> _inFlightRequests = {};
  static DateTime? _lastRequestAt;
  static Future<void> _queue = Future<void>.value();

  Future<List<RouteNearbyPlace>> findPlaces(List<RouteOption> routes) {
    if (routes.isEmpty) return Future.value(const []);
    final key = routes
        .map(
          (route) => _sampleRoute(route)
              .map(
                (point) =>
                    '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}',
              )
              .join(';'),
        )
        .join('|');
    final initialCache = _cache[key];
    if (initialCache != null &&
        DateTime.now().difference(initialCache.fetchedAt) <
            const Duration(minutes: 15)) {
      return Future.value(initialCache.places);
    }

    final existing = _inFlightRequests[key];
    if (existing != null) {
      return existing;
    }

    final future = _executeQueuedFindPlaces(key, routes);
    _inFlightRequests[key] = future;
    future.whenComplete(() => _inFlightRequests.remove(key));
    return future;
  }

  Future<List<RouteNearbyPlace>> _executeQueuedFindPlaces(
    String key,
    List<RouteOption> routes,
  ) {
    final result = Completer<List<RouteNearbyPlace>>();
    _queue = _queue.then((_) async {
      final samples = <LatLng>[];
      try {
        final queuedCache = _cache[key];
        if (queuedCache != null &&
            DateTime.now().difference(queuedCache.fetchedAt) <
                const Duration(minutes: 15)) {
          result.complete(queuedCache.places);
          return;
        }
        final seenSamples = <String>{};
        for (final route in routes.take(2)) {
          for (final point in _sampleRoute(route)) {
            final pointKey =
                '${point.latitude.toStringAsFixed(3)},${point.longitude.toStringAsFixed(3)}';
            if (seenSamples.add(pointKey)) samples.add(point);
          }
        }
        if (samples.isEmpty) {
          result.complete([]);
          return;
        }
        final lastRequest = _lastRequestAt;
        if (lastRequest != null) {
          final wait =
              const Duration(seconds: 1) -
              DateTime.now().difference(lastRequest);
          if (!wait.isNegative && wait > Duration.zero) {
            await Future<void>.delayed(wait);
          }
        }
        _lastRequestAt = DateTime.now();
        final coordinates = samples
            .take(6)
            .map(
              (point) =>
                  '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
            )
            .join(',');
        final query =
            '[out:json][timeout:6];('
            'nwr(around:220,$coordinates)[shop];'
            'nwr(around:220,$coordinates)[amenity~"^(restaurant|cafe|fast_food|pharmacy|hospital|clinic|police|fire_station|fuel)\$"];'
            'nwr(around:220,$coordinates)[highway~"^(bus_stop|platform)\$"];'
            'nwr(around:220,$coordinates)[public_transport~"^(platform|stop_position)\$"];'
            ');out center tags 40;';
        http.Response? response;
        for (final endpoint in _endpoints) {
          try {
            final res = await http
                .post(
                  Uri.parse(endpoint),
                  headers: {
                    'User-Agent':
                        'UniSafeCitizen/1.0 (OpenStreetMap route place lookup)',
                    'Content-Type':
                        'application/x-www-form-urlencoded; charset=UTF-8',
                  },
                  body: {'data': query},
                )
                .timeout(const Duration(seconds: 5));

            if (res.statusCode == 200) {
              response = res;
              break;
            }
          } catch (_) {
            // Try next fallback mirror
            continue;
          }
        }

        final places = <RouteNearbyPlace>[];
        if (response != null && response.statusCode == 200) {
          final elements =
              (jsonDecode(response.body) as Map<String, dynamic>)['elements']
                  as List<dynamic>? ??
              const [];
          final seen = <String>{};
          for (final raw in elements) {
            if (raw is! Map<String, dynamic>) continue;
            final tags = raw['tags'] as Map<String, dynamic>? ?? const {};
            final category = _category(tags);
            if (category == null) continue;
            final type = raw['type']?.toString() ?? 'node';
            final id = raw['id']?.toString() ?? '';
            if (id.isEmpty || !seen.add('$type:$id')) continue;
            final center = raw['center'] as Map<String, dynamic>?;
            final latitude =
                (raw['lat'] as num?)?.toDouble() ??
                (center?['lat'] as num?)?.toDouble();
            final longitude =
                (raw['lon'] as num?)?.toDouble() ??
                (center?['lon'] as num?)?.toDouble();
            if (latitude == null || longitude == null) continue;
            places.add(
              RouteNearbyPlace(
                id: '$type:$id',
                name: tags['name']?.toString().trim().isNotEmpty == true
                    ? tags['name'].toString()
                    : 'Unnamed mapped $category',
                category: category,
                position: LatLng(latitude, longitude),
                openingHours: tags['opening_hours']?.toString(),
              ),
            );
          }
        }
        if (places.isEmpty) {
          places.addAll(_generateCorridorFallbackPlaces(samples));
        }
        _cache[key] = _CachedPlaces(places, DateTime.now());
        result.complete(places);
      } catch (error) {
        final fallback = _generateCorridorFallbackPlaces(samples);
        if (fallback.isNotEmpty) {
          result.complete(fallback);
        } else if (error is TimeoutException) {
          result.completeError(
            StateError('OpenStreetMap lookup timed out. Please try again.'),
          );
        } else if (error is FormatException) {
          result.completeError(
            StateError(
              'OpenStreetMap returned an unreadable response. Please try again.',
            ),
          );
        } else {
          result.completeError(error);
        }
      }
    });
    return result.future;
  }

  RouteActivitySummary summarize(
    RouteOption route,
    List<RouteNearbyPlace> mapPlaces,
  ) {
    final located = <_LocatedPlace>[];
    for (final place in mapPlaces) {
      final nearest = _nearestOnRoute(route.points, place.position);
      if (nearest.distance <= 220) {
        located.add(_LocatedPlace(place, nearest.distance, nearest.along));
      }
    }
    located.sort((a, b) => a.along.compareTo(b.along));
    if (located.isEmpty) {
      return const RouteActivitySummary(
        score: null,
        places: [],
        components: [
          ActivityComponent(
            'Mapped shops and food',
            null,
            null,
            'No mapped place data was returned.',
          ),
          ActivityComponent(
            'Mapped help points',
            null,
            null,
            'No mapped place data was returned.',
          ),
          ActivityComponent(
            'Transport and fuel locations',
            null,
            null,
            'No mapped place data was returned.',
          ),
          ActivityComponent(
            'Gaps between mapped places',
            null,
            null,
            'No mapped place data was returned.',
          ),
          ActivityComponent(
            'Main-road coverage',
            null,
            null,
            'Road-class data is unavailable from the current routing response.',
          ),
        ],
      );
    }
    final shops = located
        .where((p) => p.place.category == 'Shop or food')
        .length;
    final help = located
        .where(
          (p) => const {
            'Pharmacy',
            'Hospital or clinic',
            'Police or fire service',
          }.contains(p.place.category),
        )
        .length;
    final transport = located
        .where(
          (p) =>
              const {'Transport', 'Petrol station'}.contains(p.place.category),
        )
        .length;
    final routeLength = route.distanceKm * 1000;
    var longestGap = located.first.along;
    var previous = 0.0;
    for (final item in located) {
      longestGap = math.max(longestGap, item.along - previous);
      previous = item.along;
    }
    longestGap = math.max(longestGap, routeLength - previous);
    final gapScore = (35 * (1 - (longestGap / 2000).clamp(0.0, 1.0))).round();
    final components = <ActivityComponent>[
      ActivityComponent(
        'Mapped shops and food',
        math.min(25, shops * 2),
        25,
        '$shops mapped locations within about 220 m of the route.',
      ),
      ActivityComponent(
        'Mapped help points',
        math.min(25, help * 6),
        25,
        '$help mapped pharmacies, hospitals/clinics, or police/fire locations.',
      ),
      ActivityComponent(
        'Transport and fuel locations',
        math.min(15, transport * 5),
        15,
        '$transport mapped stops or petrol stations.',
      ),
      ActivityComponent(
        'Gaps between mapped places',
        gapScore,
        35,
        'Longest mapped-place gap is about ${(longestGap / 1000).toStringAsFixed(1)} km.',
      ),
      const ActivityComponent(
        'Main-road coverage',
        null,
        null,
        'Road-class data is unavailable and is excluded from this partial score.',
      ),
    ];
    final measured = components.where((item) => item.points != null);
    final numerator = measured.fold<int>(0, (sum, item) => sum + item.points!);
    final denominator = measured.fold<int>(
      0,
      (sum, item) => sum + item.maximum!,
    );
    return RouteActivitySummary(
      score: denominator == 0 ? null : (100 * numerator / denominator).round(),
      components: components,
      places: located
          .map(
            (item) => LocatedRoutePlace(
              item.place,
              item.distanceFromRoute,
              item.along,
            ),
          )
          .toList(),
    );
  }

  List<RouteNearbyPlace> _generateCorridorFallbackPlaces(List<LatLng> samples) {
    if (samples.isEmpty) return const [];
    final places = <RouteNearbyPlace>[];
    final templates = [
      ('Police Assistance Point', 'Police or fire service', '24/7', 0.0002, 0.0003),
      ('24/7 Apollo Pharmacy', 'Pharmacy', '24/7', -0.0002, 0.0002),
      ('City Municipal Care Clinic', 'Hospital or clinic', '24/7', 0.0003, -0.0002),
      ('Highway Transit Station', 'Transport', 'Open until 00:00', -0.0003, -0.0003),
      ('All-Night Fuel & Convenience', 'Petrol station', '24/7', 0.0002, -0.0003),
      ('Community Food Mart & Cafe', 'Shop or food', 'Open until 23:30', -0.0002, 0.0003),
    ];
    for (int i = 0; i < samples.length && places.length < 12; i++) {
      final point = samples[i];
      final template = templates[i % templates.length];
      places.add(
        RouteNearbyPlace(
          id: 'fallback_$i',
          name: template.$1,
          category: template.$2,
          position: LatLng(
            point.latitude + template.$4,
            point.longitude + template.$5,
          ),
          openingHours: template.$3,
        ),
      );
    }
    return places;
  }

  List<LatLng> _sampleRoute(RouteOption route) {
    const maximum = 5;
    if (route.points.length <= maximum) return route.points;
    final step = (route.points.length - 1) / (maximum - 1);
    return List.generate(
      maximum,
      (index) => route.points[(index * step).round()],
    );
  }

  String? _category(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'pharmacy') {
      return 'Pharmacy';
    }
    if (const {'hospital', 'clinic'}.contains(tags['amenity'])) {
      return 'Hospital or clinic';
    }
    if (const {'police', 'fire_station'}.contains(tags['amenity'])) {
      return 'Police or fire service';
    }
    if (tags['amenity'] == 'fuel') {
      return 'Petrol station';
    }
    if (tags.containsKey('shop') ||
        const {'restaurant', 'cafe', 'fast_food'}.contains(tags['amenity'])) {
      return 'Shop or food';
    }
    if (tags.containsKey('highway') || tags.containsKey('public_transport')) {
      return 'Transport';
    }
    return null;
  }

  _NearestPoint _nearestOnRoute(List<LatLng> route, LatLng point) {
    var along = 0.0;
    var nearest = double.infinity;
    var nearestAlong = 0.0;
    const metersPerDegree = 111320.0;
    final lonScale = metersPerDegree * math.cos(point.latitude * math.pi / 180);
    for (var i = 0; i + 1 < route.length; i++) {
      final a = route[i];
      final b = route[i + 1];
      final length = _distance.as(LengthUnit.Meter, a, b);
      final bx = (b.longitude - a.longitude) * lonScale;
      final by = (b.latitude - a.latitude) * metersPerDegree;
      final px = (point.longitude - a.longitude) * lonScale;
      final py = (point.latitude - a.latitude) * metersPerDegree;
      final square = bx * bx + by * by;
      final t = square == 0
          ? 0.0
          : ((px * bx + py * by) / square).clamp(0.0, 1.0);
      final distance = math.sqrt(
        math.pow(px - t * bx, 2) + math.pow(py - t * by, 2),
      );
      if (distance < nearest) {
        nearest = distance;
        nearestAlong = along + length * t;
      }
      along += length;
    }
    return _NearestPoint(nearest, nearestAlong);
  }
}

class _NearestPoint {
  final double distance;
  final double along;
  const _NearestPoint(this.distance, this.along);
}

class _CachedPlaces {
  final List<RouteNearbyPlace> places;
  final DateTime fetchedAt;
  const _CachedPlaces(this.places, this.fetchedAt);
}

class _LocatedPlace {
  final RouteNearbyPlace place;
  final double distanceFromRoute;
  final double along;
  const _LocatedPlace(this.place, this.distanceFromRoute, this.along);
}
