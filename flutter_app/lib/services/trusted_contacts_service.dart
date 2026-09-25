import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class TrustedContactsService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<Map<String, dynamic>> getCurrentCitizen() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final response = await _supabase
        .from('citizens')
        .select()
        .eq('auth_user_id', user.id)
        .single();

    return Map<String, dynamic>.from(response);
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
  }

  Future<void> deleteTrustedContact(String contactId) async {
    await _supabase
        .from('trusted_contacts')
        .delete()
        .eq('id', contactId);
  }
}