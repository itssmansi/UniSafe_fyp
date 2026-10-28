import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';

void main() {
  test('TileLayer compiles with TomTom template and fallback', () {
    final layer = TileLayer(
      urlTemplate:
          'https://api.tomtom.com/maps/orbis/traffic/flow/raster/tile/{z}/{x}/{y}?apiVersion=2&key={key}&style=light',
      fallbackUrl:
          'https://api.tomtom.com/traffic/map/4/tile/flow/relative-delay/{z}/{x}/{y}.png?key={key}',
      additionalOptions: const {'key': 'test_key'},
      userAgentPackageName: 'com.example.unisafe',
      maxZoom: 22,
      minZoom: 0,
    );
    expect(layer.urlTemplate, contains('api.tomtom.com'));
    expect(layer.fallbackUrl, contains('relative-delay'));
    expect(layer.additionalOptions['key'], 'test_key');
  });
}
