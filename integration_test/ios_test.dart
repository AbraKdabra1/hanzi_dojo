// ─────────────────────────────────────────────────────────────────────────────
// ios_test.dart — La app de verdad en el simulador de iPhone
//
// Lo corre GitHub en una Mac (.github/workflows/ios.yml), porque para probar
// en iOS hace falta Xcode:
//   1. La app arranca y copia la base de contenido.
//   2. Una sílaba y una palabra se reempacan a CAF y el reproductor de iOS
//      las puede cargar (el iPhone no lee Opus en Ogg).
//   3. Capturas del inicio, la elección de modo, los niveles y el estudio.
//
// Las capturas las guarda test_driver/integration_test.dart en
// build/capturas_ios/ y el flujo las publica en la rama ci-ios.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/helpers/grabaciones.dart';
import 'package:hanzi_dojo/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';

/// Deja correr la app [segundos] (sin pumpAndSettle: la rama del inicio se
/// mece varios segundos).
Future<void> _esperar(WidgetTester t, [double segundos = 2]) async {
  for (var i = 0; i < segundos * 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Un texto en español o en inglés (el simulador puede estar en cualquiera).
Finder _texto(String es, String en) =>
    find.byWidgetPredicate((w) => w is Text && (w.data == es || w.data == en));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Hanzi Dojo en el simulador de iPhone', (tester) async {
    // La app instala sus propios avisos de error; se devuelven al final para
    // que la prueba no se queje.
    final antesFlutter = FlutterError.onError;
    final antesPlataforma = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = antesFlutter;
      PlatformDispatcher.instance.onError = antesPlataforma;
    });

    app.main();
    // La primera vez copia la base de contenido (~43 MB).
    for (var i = 0; i < 90 && _texto('Estudiar', 'Study').evaluate().isEmpty; i++) {
      await _esperar(tester, 1);
    }
    expect(_texto('Estudiar', 'Study'), findsOneWidget);
    await _esperar(tester, 3);
    await binding.takeScreenshot('01_inicio');

    // Las grabaciones: Ogg Opus → CAF, y el reproductor de iOS las acepta.
    expect(Grabaciones.enIos, isTrue);
    for (final ruta in ['assets/audio/silabas/ma1.opus', 'assets/audio/palabras/一下.opus']) {
      final caf = await Grabaciones.archivoCaf(ruta);
      final reproductor = AudioPlayer();
      final duracion = await reproductor.setFilePath(caf);
      debugPrint('Grabación $ruta → $caf: $duracion');
      expect(duracion, isNotNull, reason: ruta);
      expect(duracion!.inMilliseconds, greaterThan(150), reason: ruta);
      await reproductor.dispose();
    }

    // Estudiar → modo → niveles.
    await tester.tap(_texto('Estudiar', 'Study'));
    await _esperar(tester, 2);
    await binding.takeScreenshot('02_modo');
    await tester.tap(_texto('Soy novato', "I'm a beginner"));
    await _esperar(tester, 3);
    await binding.takeScreenshot('03_niveles');
  });
}
