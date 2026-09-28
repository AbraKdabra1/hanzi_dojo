// Pruebas del algoritmo de repaso espaciado (SM-2).
// Correr en la computadora:  flutter test test/srs_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/srs.dart';

void main() {
  group('SM-2', () {
    test('primer acierto: 1 día; segundo: 6 días; luego intervalo × factor', () {
      var e = const EstadoSrs();
      e = e.calificar(Calificacion.medio);
      expect(e.intervaloDias, 1);
      e = e.calificar(Calificacion.medio);
      expect(e.intervaloDias, 6);
      final factor = e.factor;
      e = e.calificar(Calificacion.medio);
      expect(e.intervaloDias, (6 * factor).round());
      expect(e.aciertosSeguidos, 3);
    });

    test('"Fácil" sube el factor 0.1 y "Medio" lo baja 0.14', () {
      final facil = const EstadoSrs().calificar(Calificacion.facil);
      expect(facil.factor, closeTo(2.6, 1e-9));
      final medio = const EstadoSrs().calificar(Calificacion.medio);
      expect(medio.factor, closeTo(2.36, 1e-9));
    });

    test('"Difícil" reinicia la racha a 1 día y no cambia el factor', () {
      var e = const EstadoSrs(intervaloDias: 30, factor: 2.2, aciertosSeguidos: 5);
      e = e.calificar(Calificacion.dificil);
      expect(e.intervaloDias, 1);
      expect(e.aciertosSeguidos, 0);
      expect(e.factor, 2.2);
    });

    test('el factor nunca baja de 1.3', () {
      var e = const EstadoSrs(factor: 1.35, aciertosSeguidos: 3, intervaloDias: 10);
      for (int i = 0; i < 5; i++) {
        e = e.calificar(Calificacion.medio);
      }
      expect(e.factor, greaterThanOrEqualTo(EstadoSrs.factorMinimo));
    });

    test('calificación sugerida según errores', () {
      expect(Calificacion.sugerida(0), Calificacion.facil);
      expect(Calificacion.sugerida(2), Calificacion.medio);
      expect(Calificacion.sugerida(5), Calificacion.dificil);
    });
  });
}
