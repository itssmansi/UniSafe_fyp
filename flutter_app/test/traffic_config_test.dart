import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/config/traffic_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrafficConfig', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Tile URLs contain required TomTom parameters', () {
      expect(TrafficConfig.orbisTileUrl, contains('api.tomtom.com'));
      expect(TrafficConfig.orbisTileUrl, contains('apiVersion=2'));
      expect(TrafficConfig.orbisTileUrl, contains('{z}/{x}/{y}'));
      expect(TrafficConfig.orbisTileUrl, contains('key={key}'));

      expect(TrafficConfig.legacyTileUrl, contains('relative-delay'));
      expect(TrafficConfig.legacyTileUrl, contains('{z}/{x}/{y}.png'));
    });

    test('getEffectiveKey retrieves saved key from SharedPreferences when env is blank', () async {
      var key = await TrafficConfig.getEffectiveKey();
      expect(key, isEmpty);

      await TrafficConfig.saveApiKey('test_key_123');
      key = await TrafficConfig.getEffectiveKey();
      expect(key, equals('test_key_123'));

      await TrafficConfig.clearApiKey();
      key = await TrafficConfig.getEffectiveKey();
      expect(key, isEmpty);
    });
  });
}
