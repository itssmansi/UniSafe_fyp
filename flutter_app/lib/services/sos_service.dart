import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SosService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Triggers an immediate SOS panic event.
  /// 1. Inserts record into `sos_events`
  /// 2. Dispatches SOS SMS via Pingram Edge Function to all trusted contacts
  Future<Map<String, dynamic>> triggerEmergencySos({
    required String citizenId,
    required double latitude,
    required double longitude,
    String? journeyId,
    String? citizenName,
  }) async {
    try {
      // 1. Record in `sos_events` table
      final sosRecord = await _client
          .from('sos_events')
          .insert({
            'citizen_id': citizenId,
            'journey_id': journeyId,
            'latitude': latitude,
            'longitude': longitude,
            'status': 'triggered',
            'triggered_at': DateTime.now().toIso8601String(),
            'metadata': {
              'source': 'mobile_app',
              'citizen_name': citizenName ?? 'UniSafe Citizen',
            },
          })
          .select()
          .maybeSingle();

      final eventId = sosRecord != null ? sosRecord['id']?.toString() : null;

      // 2. Dispatch SMS alert via Edge Function
      final edgeResponse = await _client.functions.invoke(
        'send-journey-tracking-sms',
        body: {
          'is_sos': true,
          'journey_id': journeyId,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      final data = edgeResponse.data;
      final int sentCount = (data is Map && data['sent_count'] is int)
          ? data['sent_count'] as int
          : 0;

      return {
        'success': true,
        'sos_event_id': eventId,
        'sent_count': sentCount,
        'message': sentCount > 0
            ? 'Emergency alert dispatched to $sentCount trusted contact(s).'
            : 'SOS recorded. Alert notifications processed.',
      };
    } catch (e) {
      debugPrint('SOS trigger error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to trigger SOS alert: $e',
      };
    }
  }

  /// Resolves an existing SOS event
  Future<void> resolveSos(String sosEventId) async {
    await _client
        .from('sos_events')
        .update({
          'status': 'resolved',
          'resolved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sosEventId);
  }
}
