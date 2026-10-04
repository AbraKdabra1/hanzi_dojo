// Pruebas de la rama de ciruelo del fondo (painters/rama_ciruelo.dart y
// widgets/fondo_tinta.dart).

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/painters/rama_ciruelo.dart';
import 'package:hanzi_dojo/widgets/fondo_tinta.dart';

void main() {
  test('la brisa sube suave, suelta pocos pétalos y al calmarse todo queda quieto', () {
    final viento = VientoCiruelo();
    expect(viento.fuerza, 0); // empieza en reposo
    var maxPetalos = 0;
    for (var i = 0; i < 30 * 20; i++) {
      viento.avanzar(1 / 30);
      maxPetalos = viento.petalosEnElAire > maxPetalos ? viento.petalosEnElAire : maxPetalos;
    }
    expect(viento.fuerza, greaterThan(0.9));
    expect(maxPetalos, greaterThan(0));
    expect(maxPetalos, lessThanOrEqualTo(VientoCiruelo.maxPetalos));
    expect(viento.quieto, isFalse);

    viento.objetivo = 0;
    var segundos = 0.0;
    while (!viento.quieto && segundos < 60) {
      viento.avanzar(1 / 30);
      segundos += 1 / 30;
    }
    expect(viento.quieto, isTrue, reason: 'la animación debe poder apagarse sola');
    expect(viento.fuerza, 0);
  });

  test('la rama se dibuja en reposo, con viento y en versión tenue', () {
    final viento = VientoCiruelo();
    for (var i = 0; i < 300; i++) {
      viento.avanzar(1 / 30);
    }
    for (final tamano in const [Size(390, 844), Size(844, 390), Size(800, 1280)]) {
      final grabadora = ui.PictureRecorder();
      final canvas = Canvas(grabadora);
      dibujarRama(canvas, tamano);
      dibujarRama(canvas, tamano, tenue: true);
      dibujarRama(canvas, tamano, t: viento.t, fuerza: viento.fuerza, viento: viento);
      grabadora.endRecording().dispose();
    }
  });

  test('la escala de la rama no pasa del 55 % del alto', () {
    expect(escalaRama(const Size(390, 844)), 390);
    expect(escalaRama(const Size(844, 390)), closeTo(390 * 0.55, 1e-9));
  });

  testWidgets('el fondo animado se arma y al quitarlo no deja relojes encendidos', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FondoTintaChina(ramaAnimada: true, child: Scaffold(body: Center(child: Text('汉字道场')))),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('汉字道场')); // tocar hace soplar el viento
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); // si quedara un Timer activo, la prueba fallaría
  });

  testWidgets('el fondo tenue se arma sin errores', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FondoTintaChina(child: Scaffold(body: Center(child: Text('Lista')))),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
