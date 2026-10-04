// Revisa que los recursos que la app carga desde assets existan y estén
// declarados en pubspec.yaml.   flutter test test/recursos_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('las grabaciones de pronunciación están declaradas', () {
    for (final ruta in ['assets/audio/', 'assets/audio/silabas/', 'assets/audio/palabras/']) {
      expect(pubspec, contains('- $ruta'), reason: ruta);
      expect(Directory(ruta).existsSync(), isTrue, reason: ruta);
    }
  });

  test('las tres fuentes Noto Sans SC existen y están declaradas', () {
    for (final peso in ['Regular', 'Medium', 'Bold']) {
      final ruta = 'assets/fonts/NotoSansSC-$peso.ttf';
      expect(File(ruta).existsSync(), isTrue, reason: ruta);
      expect(pubspec, contains(ruta));
    }
  });
}
