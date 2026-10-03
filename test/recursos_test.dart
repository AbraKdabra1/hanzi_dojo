// Revisa que los recursos que la app carga desde assets existan y estén
// declarados en pubspec.yaml.   flutter test test/recursos_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('la ilustración del Templo del Cielo existe, es JPEG y pesa poco', () {
    final archivo = File('assets/imagenes/fondo_templo.jpg');
    expect(archivo.existsSync(), isTrue);
    final bytes = archivo.readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]); // firma JPEG
    expect(bytes.length, lessThan(400 * 1024));
    expect(pubspec, contains('assets/imagenes/fondo_templo.jpg'));
  });

  test('las tres fuentes Noto Sans SC existen y están declaradas', () {
    for (final peso in ['Regular', 'Medium', 'Bold']) {
      final ruta = 'assets/fonts/NotoSansSC-$peso.ttf';
      expect(File(ruta).existsSync(), isTrue, reason: ruta);
      expect(pubspec, contains(ruta));
    }
  });
}
