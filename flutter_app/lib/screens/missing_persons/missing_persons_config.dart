import 'package:shared_preferences/shared_preferences.dart';

class MissingPersonsConfig {
  static const String defaultUrl = 'http://10.188.158.12:5000';
  static const String _prefKey = 'flask_ai_base_url';

  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim().replaceAll(RegExp(r'/+$'), '');
      }
      return defaultUrl;
    } catch (_) {
      return defaultUrl;
    }
  }

  static Future<void> setBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, url.trim().replaceAll(RegExp(r'/+$'), ''));
    } catch (_) {}
  }
}
