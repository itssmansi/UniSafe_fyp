import 'package:shared_preferences/shared_preferences.dart';

class TrafficConfig {
  /// Optional environment-provided key via `--dart-define=TOMTOM_API_KEY=your_key`
  static const String envTomTomKey = String.fromEnvironment('TOMTOM_API_KEY');

  static const String _prefKey = 'unisafe_tomtom_api_key';

  /// TomTom Orbis v2 Raster Flow Tiles URL
  /// Documented at: https://docs.tomtom.com/traffic-api/documentation/tomtom-orbis-maps/v2/traffic-flow/raster-flow-tiles
  static const String orbisTileUrl =
      'https://api.tomtom.com/maps/orbis/traffic/flow/raster/tile/{z}/{x}/{y}?apiVersion=2&key={key}&style=light';

  /// TomTom Traffic API v4 Raster Flow Tiles URL (automatic fallback for older or standard keys)
  static const String legacyTileUrl =
      'https://api.tomtom.com/traffic/map/4/tile/flow/relative-delay/{z}/{x}/{y}.png?key={key}';

  /// Attribution required by TomTom terms of service
  static const String attribution = 'Traffic data © TomTom';

  /// Get the effective key from environment or local storage
  static Future<String> getEffectiveKey() async {
    if (envTomTomKey.trim().isNotEmpty) {
      return envTomTomKey.trim();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Save API key locally in SharedPreferences for seamless developer/testing usage
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, key.trim());
    }
  }

  /// Remove saved API key
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
