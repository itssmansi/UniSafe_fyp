import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://wcksscwgeoysnqiluxoh.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_fm-MbbqWBeDctqRdUflgCg_qQq5pmxt';

  static SupabaseClient get client =>
      Supabase.instance.client;
}
