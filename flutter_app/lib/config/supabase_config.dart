import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'wcksscwgeoysnqiluxoh';
  static const String supabaseAnonKey = 'sb_publishable_fm-MbbqWBeDctqRdUflgCg_qQq5pmxt';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}