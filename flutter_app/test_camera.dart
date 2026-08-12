import 'dart:mirrors';
import 'package:flutter_map/flutter_map.dart';

void main() {
  ClassMirror classMirror = reflectClass(MapCamera);
  for (var m in classMirror.declarations.values) {
    print(m.simpleName);
  }
}
