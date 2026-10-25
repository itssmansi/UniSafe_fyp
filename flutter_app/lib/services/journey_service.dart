import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/journey_session.dart';

class JourneyServiceException implements Exception {
  final String message;
  final String? code;

  const JourneyServiceException(this.message, {this.code});

  @override
  String toString() => 'JourneyServiceException: $message (code: $code)';
}

class JourneyService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Cache last updated positions per journey to throttle database writes
  final Map<String, PositionCoordinate> _lastUpdatedCoordinates = {};

  // ------------------------------------------------------------
  // CITIZEN PROFILE HELPER
  // ------------------------------------------------------------

  /// Retrieves the citizen record corresponding to the currently authenticated user.
  Future<Map<String, dynamic>> getCurrentCitizen() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const JourneyServiceException(
        'User is not authenticated.',
        code: 'UNAUTHENTICATED',
      );
    }

    final response = await _supabase
        .from('citizens')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (response == null) {
      throw const JourneyServiceException(
        'Citizen profile not found for this account.',
        code: 'PROFILE_NOT_FOUND',
      );
    }

    return Map<String, dynamic>.from(response);
  }

  // ------------------------------------------------------------
  // START JOURNEY
  // ------------------------------------------------------------

  /// Starts a new Safe Journey session, generates a secure tracking token,
  /// saves the session to Supabase, and triggers SMS notification dispatch.
  Future<JourneySession> startJourney({
    required String citizenId,
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationName,
    Duration tokenValidityDuration = const Duration(hours: 6),
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(tokenValidityDuration);
    final trackingToken = _generateSecureTrackingToken();

    final insertPayload = {
      'citizen_id': citizenId,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'destination_name': destinationName.trim(),
      'latest_latitude': startLatitude,
      'latest_longitude': startLongitude,
      'last_location_update': now.toIso8601String(),
      'status': 'active',
      'started_at': now.toIso8601String(),
      'tracking_token': trackingToken,
      'token_expires_at': expiresAt.toIso8601String(),
    };

    final response = await _supabase
        .from('journey_sessions')
        .insert(insertPayload)
        .select()
        .single();

    final session = JourneySession.fromJson(response);

    // Cache initial position
    _lastUpdatedCoordinates[session.id] = PositionCoordinate(
      latitude: startLatitude,
      longitude: startLongitude,
      timestamp: now,
    );

    // Asynchronously dispatch tracking SMS without blocking the journey creation flow
    sendTrackingSms(journeyId: session.id).catchError((error) {
      debugPrint('SMS notification dispatch warning: $error');
      return <String, dynamic>{'success': false, 'error': error.toString()};
    });

    return session;
  }

  // ------------------------------------------------------------
  // UPDATE JOURNEY LOCATION
  // ------------------------------------------------------------

  /// Updates the latest latitude and longitude for an active journey.
  /// Throttles unnecessary database writes if movement is below [minDistanceMeters]
  /// unless at least [forceIntervalSeconds] have elapsed.
  Future<JourneySession?> updateJourneyLocation({
    required String journeyId,
    required double latitude,
    required double longitude,
    double minDistanceMeters = 10.0,
    int forceIntervalSeconds = 60,
  }) async {
    final now = DateTime.now().toUtc();
    final lastPos = _lastUpdatedCoordinates[journeyId];

    if (lastPos != null) {
      final distance = Geolocator.distanceBetween(
        lastPos.latitude,
        lastPos.longitude,
        latitude,
        longitude,
      );

      final secondsSinceLastUpdate =
          now.difference(lastPos.timestamp).inSeconds;

      // Skip database write if device hasn't moved significantly
      // and minimum update interval has not elapsed.
      if (distance < minDistanceMeters &&
          secondsSinceLastUpdate < forceIntervalSeconds) {
        return null;
      }
    }

    final updatePayload = {
      'latest_latitude': latitude,
      'latest_longitude': longitude,
      'last_location_update': now.toIso8601String(),
    };

    final response = await _supabase
        .from('journey_sessions')
        .update(updatePayload)
        .eq('id', journeyId)
        .eq('status', 'active')
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    _lastUpdatedCoordinates[journeyId] = PositionCoordinate(
      latitude: latitude,
      longitude: longitude,
      timestamp: now,
    );

    return JourneySession.fromJson(response);
  }

  // ------------------------------------------------------------
  // GET ACTIVE JOURNEY
  // ------------------------------------------------------------

  /// Retrieves the active journey session for a citizen, if any.
  Future<JourneySession?> getActiveJourney(String citizenId) async {
    final response = await _supabase
        .from('journey_sessions')
        .select()
        .eq('citizen_id', citizenId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return JourneySession.fromJson(response);
  }

  // ------------------------------------------------------------
  // GET JOURNEY HISTORY
  // ------------------------------------------------------------

  /// Retrieves all journey records for a citizen, sorted with the newest first.
  Future<List<JourneySession>> getJourneyHistory(String citizenId) async {
    final response = await _supabase
        .from('journey_sessions')
        .select()
        .eq('citizen_id', citizenId)
        .order('started_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => JourneySession.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ------------------------------------------------------------
  // END JOURNEY
  // ------------------------------------------------------------

  /// Marks a journey session as completed and immediately invalidates the tracking token.
  Future<JourneySession> endJourney(String journeyId) async {
    final now = DateTime.now().toUtc();

    final response = await _supabase
        .from('journey_sessions')
        .update({
          'status': 'completed',
          'ended_at': now.toIso8601String(),
          'token_expires_at': now.toIso8601String(), // Invalidate token
        })
        .eq('id', journeyId)
        .select()
        .single();

    _lastUpdatedCoordinates.remove(journeyId);
    return JourneySession.fromJson(response);
  }

  // ------------------------------------------------------------
  // CANCEL JOURNEY
  // ------------------------------------------------------------

  /// Marks a journey session as cancelled and immediately invalidates the tracking token.
  Future<JourneySession> cancelJourney(String journeyId) async {
    final now = DateTime.now().toUtc();

    final response = await _supabase
        .from('journey_sessions')
        .update({
          'status': 'cancelled',
          'ended_at': now.toIso8601String(),
          'token_expires_at': now.toIso8601String(), // Invalidate token
        })
        .eq('id', journeyId)
        .select()
        .single();

    _lastUpdatedCoordinates.remove(journeyId);
    return JourneySession.fromJson(response);
  }

  // ------------------------------------------------------------
  // WATCH JOURNEY LOCATION (REALTIME STREAM)
  // ------------------------------------------------------------

  /// Streams real-time updates for a specific journey session using Supabase Realtime.
  /// Listeners can cancel their subscription at any time via StreamSubscription.cancel().
  Stream<JourneySession> watchJourneyLocation(String journeyId) {
    return _supabase
        .from('journey_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', journeyId)
        .map((events) {
          if (events.isEmpty) {
            throw const JourneyServiceException(
              'Journey record not found.',
              code: 'NOT_FOUND',
            );
          }
          return JourneySession.fromJson(events.first);
        });
  }

  // ------------------------------------------------------------
  // PINGRAM SMS DISPATCH VIA EDGE FUNCTION
  // ------------------------------------------------------------

  /// Invokes the secure Supabase Edge Function to send tracking links
  /// to the citizen's trusted contacts via Pingram SMS.
  Future<Map<String, dynamic>> sendTrackingSms({
    required String journeyId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-journey-tracking-sms',
        body: {'journey_id': journeyId},
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }

      return {
        'success': true,
        'message': 'SMS notification request dispatched.',
      };
    } catch (e) {
      debugPrint('Error invoking send-journey-tracking-sms: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  /// Generates a cryptographically secure 256-bit URL-safe token.
  String _generateSecureTrackingToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class PositionCoordinate {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const PositionCoordinate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
