// Pruebas de la evaluación de trazos (DTW), la geometría del lienzo y los
// colores de pinyin.   flutter test test/trazos_test.dart

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/helpers/dtw_helper.dart';
import 'package:hanzi_dojo/helpers/pinyin_helper.dart';
import 'package:hanzi_dojo/painters/geometria.dart';

void main() {
  group('DTW', () {
    final horizontal = [for (int i = 0; i <= 10; i++) Offset(i * 10.0, 50)];

    test('un trazo idéntico cuesta 0', () {
      expect(DTWHelper.calcular(horizontal, horizontal), closeTo(0, 1e-9));
    });

    test('la velocidad no importa (más o menos puntos, mismo recorrido)', () {
      final lento = [for (int i = 0; i <= 100; i++) Offset(i * 1.0, 50)];
      expect(DTWHelper.calcular(lento, horizontal), lessThan(1.0));
    });

    test('un trazo al revés cuesta mucho más que uno ligeramente movido', () {
      final alReves = horizontal.reversed.toList();
      final movido = [for (final p in horizontal) p + const Offset(0, 5)];
      expect(DTWHelper.calcular(alReves, horizontal),
          greaterThan(DTWHelper.calcular(movido, horizontal) * 5));
    });

    test('menos de 2 puntos = infinito (no se puede comparar)', () {
      expect(DTWHelper.calcular([const Offset(1, 1)], horizontal), double.infinity);
    });
  });

  group('Geometría del lienzo', () {
    const s = Size(400, 400);

    test('el borde superior (y=900) cae en el margen de arriba', () {
      final p = GeometriaLienzo.aLienzo(const Offset(0, 900), s);
      expect(p.dx, closeTo(20, 1e-9));
      expect(p.dy, closeTo(20, 1e-9));
    });

    test('el borde inferior (y=−124) cae en el margen de abajo', () {
      final p = GeometriaLienzo.aLienzo(const Offset(1024, -124), s);
      expect(p.dx, closeTo(380, 1e-9));
      expect(p.dy, closeTo(380, 1e-9));
    });
  });

  group('Pinyin', () {
    test('tono desde número y desde acentos', () {
      expect(PinyinHelper.tonoDeNumero('hao3'), 3);
      expect(PinyinHelper.tonoDeNumero('ma5'), 5);
      expect(PinyinHelper.tonoDeAcentos('nǚ'), 3);
      expect(PinyinHelper.tonoDeAcentos('lǜ'), 4);
      expect(PinyinHelper.tonoDeAcentos('de'), 5);
    });

    test('colores por tono', () {
      expect(PinyinHelper.colorDeTono(1), PinyinHelper.tono1);
      expect(PinyinHelper.colorDeTono(5), PinyinHelper.neutro);
    });
  });
}
