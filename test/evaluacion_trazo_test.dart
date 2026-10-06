// Evaluación de trazos con caracteres reales (medianas de Make Me a Hanzi):
// un horizontal no puede pasar por un vertical (ni al revés), un trazo que
// toca después no cuenta antes de tiempo, y los trazos bien hechos (con
// temblor y algo movidos) sí pasan.
//   flutter test test/evaluacion_trazo_test.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/helpers/dtw_helper.dart';
import 'package:hanzi_dojo/helpers/evaluacion_trazo.dart';
import 'package:hanzi_dojo/painters/geometria.dart';

const _lado = Size(400, 400);
const _ancho = 400.0;

/// Mediana (coordenadas de Make Me a Hanzi) en píxeles del lienzo.
List<Offset> _med(List<List<int>> puntos) =>
    GeometriaLienzo.trazoALienzo([for (final p in puntos) Offset(p[0].toDouble(), p[1].toDouble())], _lado);

/// Como lo dibujaría una persona: algo movido y con temblor suave.
List<Offset> _aMano(List<Offset> mediana, {Offset mover = const Offset(9, -7)}) {
  final p = DTWHelper.normalizar(mediana, 30);
  return [
    for (int i = 0; i < p.length; i++) p[i] + mover + Offset(3 * math.sin(i * 0.7), 3 * math.cos(i * 0.5)),
  ];
}

ResultadoTrazo _evaluar(List<Offset> tuyo, List<Offset> esperado, [List<List<Offset>> pendientes = const []]) =>
    EvaluacionTrazo.evaluar(tuyo, esperado, ancho: _ancho, pendientes: pendientes);

void main() {
  // 十: 一 (horizontal) y luego 丨 (vertical); se cruzan en el centro.
  final shi = [
    _med([[109, 442], [177, 422], [373, 456], [819, 505], [869, 499], [932, 476]]),
    _med([[456, 811], [484, 803], [522, 767], [512, 593], [507, -33]]),
  ];
  // 三: tres horizontales, de arriba abajo.
  final san = [
    _med([[316, 655], [367, 645], [416, 648], [660, 692], [722, 692]]),
    _med([[331, 407], [375, 405], [628, 443], [657, 443], [700, 432]]),
    _med([[127, 152], [158, 142], [195, 139], [500, 178], [846, 204], [881, 200], [955, 174]]),
  ];
  // 口: 丨, 𠃍 (horizontal que dobla hacia abajo) y 一.
  final kou = [
    _med([[229, 584], [272, 548], [287, 517], [330, 203], [348, 152]]),
    _med([[304, 569], [333, 552], [488, 574], [663, 608], [700, 607], [720, 598], [759, 559], [758, 552], [694, 295], [661, 273]]),
    _med([[369, 185], [394, 203], [651, 238], [710, 236], [744, 224]]),
  ];

  group('Horizontal contra vertical', () {
    test('土: el vertical en lugar del horizontal no pasa (antes sí)', () {
      final horizontal = _med([[283, 438], [312, 430], [379, 430], [486, 445], [692, 487], [741, 485]]);
      final vertical = _med([[461, 760], [517, 714], [518, 685], [498, 173], [476, 153]]);
      final tuyo = _aMano(vertical);
      // Así era antes: solo la distancia DTW, con tolerancia 0.28 → pasaba.
      expect(DTWHelper.calcular(tuyo, horizontal), lessThan(0.28 * _ancho));
      expect(_evaluar(tuyo, horizontal, [vertical]), ResultadoTrazo.incorrecto);
      expect(_evaluar(_aMano(horizontal), vertical), ResultadoTrazo.incorrecto);
    });

    test('十: el vertical en lugar del horizontal no pasa', () {
      expect(_evaluar(_aMano(shi[1]), shi[0], [shi[1]]), ResultadoTrazo.incorrecto);
    });

    test('十: el horizontal en lugar del vertical no pasa', () {
      expect(_evaluar(_aMano(shi[0]), shi[1]), ResultadoTrazo.incorrecto);
    });

    test('una cruz que pasa justo por el centro tampoco engaña', () {
      final horizontal = [for (int i = 0; i <= 20; i++) Offset(80 + 12.0 * i, 200)];
      final vertical = [for (int i = 0; i <= 20; i++) Offset(200, 80 + 12.0 * i)];
      expect(_evaluar(vertical, horizontal), ResultadoTrazo.incorrecto);
      expect(_evaluar(horizontal, vertical), ResultadoTrazo.incorrecto);
    });

    test('ni en diagonal: 撇 (／) en lugar de 捺 (＼)', () {
      final pie = [for (int i = 0; i <= 20; i++) Offset(260 - 7.0 * i, 120 + 9.0 * i)];
      final na = [for (int i = 0; i <= 20; i++) Offset(140 + 7.0 * i, 120 + 9.0 * i)];
      expect(_evaluar(pie, na), ResultadoTrazo.incorrecto);
    });
  });

  group('Orden de los trazos', () {
    test('三: dibujar el segundo horizontal cuando toca el primero no pasa', () {
      expect(_evaluar(_aMano(san[1]), san[0], [san[1], san[2]]), ResultadoTrazo.incorrecto);
    });

    test('三: el tercero tampoco', () {
      expect(_evaluar(_aMano(san[2]), san[0], [san[1], san[2]]), ResultadoTrazo.incorrecto);
    });
  });

  group('Trazos bien hechos', () {
    test('十 y 三, en orden: correctos aunque estén algo movidos y temblorosos', () {
      for (final trazos in [shi, san]) {
        for (int i = 0; i < trazos.length; i++) {
          expect(_evaluar(_aMano(trazos[i]), trazos[i], trazos.sublist(i + 1)), ResultadoTrazo.correcto,
              reason: 'trazo ${i + 1}');
        }
      }
    });

    test('口: el trazo que dobla (𠃍) también pasa', () {
      for (int i = 0; i < kou.length; i++) {
        expect(_evaluar(_aMano(kou[i]), kou[i], kou.sublist(i + 1)), ResultadoTrazo.correcto, reason: 'trazo ${i + 1}');
      }
    });

    test('al revés sigue diciendo "al revés"', () {
      expect(_evaluar(_aMano(shi[0]).reversed.toList(), shi[0], [shi[1]]), ResultadoTrazo.alReves);
      expect(_evaluar(_aMano(shi[1]).reversed.toList(), shi[1]), ResultadoTrazo.alReves);
    });

    test('un trazo demasiado corto no pasa', () {
      final h = shi[0];
      final mitad = DTWHelper.normalizar(h, 20);
      final pedacito = mitad.sublist(8, 11); // ~10 % del largo, en el centro
      expect(_evaluar(pedacito, h, [shi[1]]), ResultadoTrazo.incorrecto);
    });
  });
}
