// Pruebas del sentido del trazo ("al revés") y del ajuste caligráfico con
// resorte.   flutter test test/caligrafia_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/helpers/ajuste_trazo.dart';
import 'package:hanzi_dojo/helpers/evaluacion_trazo.dart';
import 'package:hanzi_dojo/widgets/lienzo_escritura.dart';

/// Línea recta de [a] a [b] con [n] + 1 puntos.
List<Offset> linea(Offset a, Offset b, [int n = 20]) =>
    [for (int i = 0; i <= n; i++) Offset.lerp(a, b, i / n)!];

void main() {
  group('Sentido del trazo', () {
    const umbral = 400 * 0.28; // lienzo de 400 px, como en la app
    final mediana = linea(const Offset(75, 200), const Offset(325, 200));

    test('bien hecho: correcto', () {
      final trazo = linea(const Offset(80, 205), const Offset(320, 195));
      expect(EvaluacionTrazo.evaluar(trazo, mediana, umbral), ResultadoTrazo.correcto);
    });

    test('trazo largo al revés: "al revés" (antes solo contaba como error)', () {
      final trazo = linea(const Offset(320, 195), const Offset(80, 205));
      expect(EvaluacionTrazo.evaluar(trazo, mediana, umbral), ResultadoTrazo.alReves);
    });

    test('trazo corto (como 丶) al revés: "al revés" (antes pasaba como correcto)', () {
      final punto = linea(const Offset(180, 150), const Offset(215, 190));
      final alReves = linea(const Offset(213, 188), const Offset(182, 152));
      final bien = linea(const Offset(182, 152), const Offset(213, 188));
      expect(EvaluacionTrazo.evaluar(bien, punto, umbral), ResultadoTrazo.correcto);
      expect(EvaluacionTrazo.evaluar(alReves, punto, umbral), ResultadoTrazo.alReves);
    });

    test('otro trazo lejos: incorrecto', () {
      final trazo = linea(const Offset(75, 380), const Offset(325, 380));
      expect(EvaluacionTrazo.evaluar(trazo, mediana, umbral), ResultadoTrazo.incorrecto);
    });
  });

  group('Ajuste caligráfico (geometría)', () {
    // Contorno de una barra horizontal, como el de un trazo 一.
    final barra = [
      const Offset(0, 40),
      const Offset(100, 40),
      const Offset(100, 60),
      const Offset(0, 60),
    ];

    test('muestrear un Path da puntos sobre su contorno', () {
      final path = Path()..addRect(const Rect.fromLTWH(0, 40, 100, 20));
      final puntos = AjusteTrazo.muestrearPath(path, 60);
      expect(puntos, hasLength(60));
      for (final p in puntos) {
        final enBorde = (p.dx - 0).abs() < 0.01 ||
            (p.dx - 100).abs() < 0.01 ||
            (p.dy - 40).abs() < 0.01 ||
            (p.dy - 60).abs() < 0.01;
        expect(enBorde, isTrue, reason: '$p no está en el borde');
      }
    });

    test('alinear: 2 lados, empieza en el inicio y el segundo lado en el final', () {
      final a = AjusteTrazo.alinear(barra, const Offset(0, 50), const Offset(100, 50));
      expect(a, hasLength(2 * AjusteTrazo.puntosPorLado));
      expect(a.first.dx, lessThan(5));
      expect(a[AjusteTrazo.puntosPorLado].dx, greaterThan(95));
    });

    test('alinear no depende del sentido en que venga el contorno', () {
      final normal = AjusteTrazo.alinear(barra, const Offset(0, 50), const Offset(100, 50));
      final invertido =
          AjusteTrazo.alinear(barra.reversed.toList(), const Offset(0, 50), const Offset(100, 50));
      for (int i = 0; i < normal.length; i++) {
        expect((normal[i] - invertido[i]).distance, lessThan(2));
      }
    });

    test('interpolar: 0 = origen, 1 = destino, >1 se pasa (rebote)', () {
      final a = [const Offset(0, 0), const Offset(10, 0)];
      final b = [const Offset(0, 10), const Offset(10, 10)];
      expect(AjusteTrazo.interpolar(a, b, 0), a);
      expect(AjusteTrazo.interpolar(a, b, 1), b);
      expect(AjusteTrazo.interpolar(a, b, 1.1).first.dy, closeTo(11, 1e-9));
    });
  });

  group('Lienzo', () {
    // Un "carácter" de un solo trazo horizontal (coordenadas de make-me-a-hanzi).
    const svg = ['M 100 400 L 900 400 L 900 360 L 100 360 Z'];
    const mediana = [
      [Offset(100, 380), Offset(500, 380), Offset(900, 380)],
    ];
    // En un lienzo de 400 × 400, la mediana va de (55, 203) a (336, 203).
    const inicio = Offset(55, 203);
    const fin = Offset(336, 203);

    int? errores;

    Future<void> montar(WidgetTester tester, {bool ajuste = true}) async {
      errores = null;
      // La vibración va a la plataforma; en las pruebas se responde "ok".
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (llamada) async => null);
      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: LienzoEscritura(
              caracter: 'prueba',
              trazosSvg: svg,
              medianas: mediana,
              modoNovato: false,
              ajusteCaligrafico: ajuste,
              onCompletado: (e) => errores = e,
            ),
          ),
        ),
      ));
    }

    Future<void> trazar(WidgetTester tester, Offset desde, Offset hasta) async {
      final gesto = await tester.startGesture(desde);
      for (int i = 1; i <= 20; i++) {
        await gesto.moveTo(Offset.lerp(desde, hasta, i / 20)!);
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesto.up();
      await tester.pump(const Duration(milliseconds: 300));
    }

    double opacidadAviso(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(find
            .ancestor(of: find.textContaining('Al revés'), matching: find.byType(AnimatedOpacity))
            .first)
        .opacity;

    testWidgets('trazo correcto: se acomoda con el resorte y completa el carácter', (tester) async {
      await montar(tester);
      await trazar(tester, inicio, fin);
      await tester.pumpAndSettle(); // deja que el resorte se asiente
      expect(errores, 0);
      expect(opacidadAviso(tester), 0);
      await tester.pump(const Duration(seconds: 2)); // vencen los temporizadores
    });

    testWidgets('sin ajuste caligráfico también completa', (tester) async {
      await montar(tester, ajuste: false);
      await trazar(tester, inicio, fin);
      await tester.pumpAndSettle();
      expect(errores, 0);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('trazo al revés: avisa "Al revés" y no completa', (tester) async {
      await montar(tester);
      await trazar(tester, fin, inicio);
      expect(errores, isNull);
      expect(opacidadAviso(tester), 1);
      await tester.pump(const Duration(seconds: 2)); // se apagan el aviso y la guía
      await tester.pumpAndSettle();
      expect(opacidadAviso(tester), 0);
    });

    testWidgets('reiniciar a mitad del resorte no truena', (tester) async {
      await montar(tester);
      final clave = GlobalKey<LienzoEscrituraState>();
      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: LienzoEscritura(
              key: clave,
              caracter: 'prueba',
              trazosSvg: svg,
              medianas: mediana,
              modoNovato: false,
              onCompletado: (e) => errores = e,
            ),
          ),
        ),
      ));
      await trazar(tester, inicio, fin);
      clave.currentState!.reiniciar(); // el resorte seguía en marcha
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
