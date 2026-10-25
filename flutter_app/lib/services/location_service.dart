import 'package:geolocator/geolocator.dart';

class LocationServiceException implements Exception {
  final String message;
  final String? code;

  const LocationServiceException(this.message, {this.code});

  @override
  String toString() => 'LocationServiceException: $message (code: $code)';
}

class LocationService {
  /// Checks whether GPS / Location Services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Checks the current location permission state.
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Requests location permissions from the user.
  /// Handles denied, deniedForever, and granted states.
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Verifies location services and permissions.
  /// Throws [LocationServiceException] with specific codes if not usable.
  Future<void> ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are disabled on this device. Please turn on GPS.',
        code: 'LOCATION_SERVICES_DISABLED',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException(
          'Location permissions were denied by the user.',
          code: 'PERMISSION_DENIED',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permissions are permanently denied. Please enable them in app settings.',
        code: 'PERMISSION_DENIED_FOREVER',
      );
    }
  }

  /// Retrieves the current device position with foreground high accuracy.
  Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 15),
  }) async {
    await ensureLocationReady();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } catch (e) {
      throw LocationServiceException(
        'Failed to acquire current GPS location: $e',
        code: 'GPS_ERROR',
      );
    }
  }

  /// Provides a stream of location updates for real-time tracking.
  /// Uses a distance filter (default 10 meters) to avoid jitter and redundant updates.
  Stream<Position> getPositionStream({
    int distanceFilter = 10,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Calculates the distance in meters between two geographical coordinates.
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Opens application settings if permissions were permanently denied.
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Opens device location settings if GPS is switched off.
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
