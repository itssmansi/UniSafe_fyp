import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/saved_destination.dart';

class SavedDestinationService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<SavedDestination>> getSavedDestinations(String citizenId) async {
    try {
      final response = await _client
          .from('saved_destinations')
          .select()
          .eq('citizen_id', citizenId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => SavedDestination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<SavedDestination?> saveDestination({
    required String citizenId,
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final response = await _client
        .from('saved_destinations')
        .upsert(
          {
            'citizen_id': citizenId,
            'destination_name': name,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
          },
          onConflict: 'citizen_id,destination_name',
        )
        .select()
        .single();

    return SavedDestination.fromJson(response);
  }

  Future<SavedDestination?> updateDestination({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final response = await _client
        .from('saved_destinations')
        .update({
          'destination_name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return SavedDestination.fromJson(response);
  }

  Future<void> deleteDestination(String id) async {
    await _client.from('saved_destinations').delete().eq('id', id);
  }
}
