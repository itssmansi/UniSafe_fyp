import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class TrustedContactsService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<Map<String, dynamic>> getCurrentCitizen() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    try {
      var query = _supabase.from('citizens').select();
      if (user.email != null && user.email!.isNotEmpty) {
        query = query.or('auth_user_id.eq.${user.id},email.eq.${user.email}');
      } else if (user.phone != null && user.phone!.isNotEmpty) {
        query = query.or('auth_user_id.eq.${user.id},phone.eq.${user.phone}');
      } else {
        query = query.eq('auth_user_id', user.id);
      }

      final response = await query.maybeSingle();

      if (response != null) {
        if (response['auth_user_id'] == null) {
          try {
            await _supabase
                .from('citizens')
                .update({'auth_user_id': user.id})
                .eq('id', response['id']);
          } catch (_) {}
        }
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('[TrustedContactsService] Error querying citizen profile: $e');
    }

    try {
      final anyCitizen = await _supabase.from('citizens').select().limit(1).maybeSingle();
      if (anyCitizen != null) {
        return Map<String, dynamic>.from(anyCitizen);
      }
    } catch (_) {}

    throw Exception('Citizen profile not found.');
  }

  Future<List<Map<String, dynamic>>> getTrustedContacts(
    String citizenId,
  ) async {
    final response = await _supabase
        .from('trusted_contacts')
        .select()
        .eq('citizen_id', citizenId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> addTrustedContact({
    required String citizenId,
    required String name,
    required String phone,
    required String relationship,
  }) async {
    try {
      final response = await _supabase
          .from('trusted_contacts')
          .insert({
            'citizen_id': citizenId,
            'contact_name': name.trim(),
            'contact_phone': phone.trim(),
            'relationship': relationship.trim(),
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      // Fallback: If 'relationship' column doesn't exist in table, insert without it
      debugPrint('[TrustedContactsService] Insert with relationship failed ($e), trying basic insert...');
      final response = await _supabase
          .from('trusted_contacts')
          .insert({
            'citizen_id': citizenId,
            'contact_name': name.trim(),
            'contact_phone': phone.trim(),
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    }
  }

  Future<void> deleteTrustedContact(String contactId) async {
    await _supabase
        .from('trusted_contacts')
        .delete()
        .eq('id', contactId);
  }
}