// ─────────────────────────────────────────────────────────────────────────────
// ios_test.dart — La app de verdad en el simulador de iPhone
//
// Lo corre GitHub en una Mac (.github/workflows/ios.yml), porque para probar
// en iOS hace falta Xcode:
//   1. La app arranca y copia la base de contenido.
//   2. Una sílaba y una palabra se reempacan a CAF y el reproductor de iOS
//      las puede cargar (el iPhone no lee Opus en Ogg); una oración suena de
//      corrido, palabra por palabra (lista de reproducción con recortes).
//   3. Capturas del inicio, la elección de modo, los niveles y el estudio.
//
// Cada captura se guarda en la carpeta temporal de la app (en el simulador es
// una carpeta de la Mac) y se escribe su ruta ("CAPTURA: …"); el flujo las
// recoge y las publica en la rama ci-ios. Con flutter drive y
// test_driver/integration_test.dart también se guardan en build/capturas_ios.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/helpers/grabaciones.dart';
import 'package:hanzi_dojo/main.dart' as app;
import 'package:hanzi_dojo/widgets/boton_voz.dart';
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

  /// En el simulador la app puede escribir en la Mac: el flujo pasa la carpeta
  /// del repositorio (al terminar, flutter test borra la app y su carpeta).
  const carpetaCapturas = String.fromEnvironment('CAPTURAS');

  Future<void> captura(String nombre) async {
    final bytes = await binding.takeScreenshot(nombre);
    final carpeta = carpetaCapturas.isEmpty ? '${Directory.systemTemp.path}/capturas_ios' : carpetaCapturas;
    final archivo = File('$carpeta/$nombre.png');
    archivo.parent.createSync(recursive: true);
    archivo.writeAsBytesSync(bytes);
    debugPrint('CAPTURA: ${archivo.path}');
  }

  /// Cada paso con su límite de tiempo y su renglón en el registro, para saber
  /// exactamente dónde se atora si algo falla.
  Future<T> paso<T>(String nombre, Future<T> Function() hacer, {int segundos = 60}) async {
    debugPrint('PASO $nombre…');
    final r = await hacer().timeout(Duration(seconds: segundos));
    debugPrint('PASO $nombre: listo');
    return r;
  }

  testWidgets('Meizi Hanzi en el simulador de iPhone', timeout: const Timeout(Duration(minutes: 6)), (tester) async {
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
    await captura('01_inicio');

    // Estudiar → modo → niveles.
    await tester.tap(_texto('Estudiar', 'Study'));
    await _esperar(tester, 2);
    await captura('02_modo');
    await tester.tap(_texto('Soy novato', "I'm a beginner"));
    await _esperar(tester, 3);
    await captura('03_niveles');

    // Las grabaciones: Ogg Opus → CAF, y el reproductor de iOS las acepta.
    expect(Grabaciones.enIos, isTrue);
    for (final ruta in ['assets/audio/silabas/ma1.opus', 'assets/audio/palabras/4e00-4e0b.opus' /* 一下 */]) {
      final bytes = await tester.runAsync(() => paso('leer $ruta', () => rootBundle.load(ruta)));
      debugPrint('Asset $ruta: ${bytes?.lengthInBytes} bytes');
      final caf = await tester.runAsync(() => paso('CAF $ruta', () => Grabaciones.archivoCaf(ruta)));
      final archivo = File(caf!);
      final cabecera = String.fromCharCodes(archivo.readAsBytesSync().take(4));
      debugPrint('CAF $ruta: ${archivo.lengthSync()} bytes, cabecera "$cabecera"');
      expect(cabecera, 'caff', reason: ruta);
      final duracion = await tester.runAsync(() async {
        final reproductor = AudioPlayer();
        try {
          return await paso('cargar $ruta', () => reproductor.setFilePath(caf), segundos: 30);
        } finally {
          await reproductor.dispose();
        }
      });
      debugPrint('Grabación $ruta: $duracion');
      expect(duracion, isNotNull, reason: ruta);
      expect(duracion!.inMilliseconds, greaterThan(150), reason: ruta);
    }

    // Una oración de corrido (lista de reproducción con recortes y pausas),
    // como al leer un cuento: suena cada palabra y termina.
    final sonaron = <(int, int)>[];
    final reloj = Stopwatch()..start();
    final completa = await tester.runAsync(() => paso(
          'leer una oración',
          () => Voz.leerResaltando(
            '你好，我很好。',
            pinyin: const ['nǐ', 'hǎo', '', 'wǒ', 'hěn', 'hǎo', ''],
            rapidez: 1.25,
            alSonar: (inicio, fin) {
              if (inicio >= 0) sonaron.add((inicio, fin));
            },
          ),
          segundos: 40,
        ));
    debugPrint('Oración: ${reloj.elapsedMilliseconds} ms, sonaron $sonaron');
    expect(completa, isTrue);
    expect(sonaron.map((s) => s.$1), containsAll([0, 3]));
  });
}
