// «Chino desde cero»: qué lecciones se guardan como terminadas, cuándo se
// ofrecen en el inicio y que cada lección se recorre completa (en pantalla
// chica y sin errores), con sonidos que la app sí trae.
//   flutter test test/desde_cero_test.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/desde_cero.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/helpers/sensaciones.dart';
import 'package:hanzi_dojo/screens/pantalla_desde_cero.dart';
import 'package:hanzi_dojo/widgets/boton_voz.dart';
import 'package:hanzi_dojo/widgets/lienzo_escritura.dart';
import 'package:hanzi_dojo/widgets/piezas_desde_cero.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;
  final silabas = File('assets/audio/silabas.txt').readAsLinesSync().where((l) => l.isNotEmpty).toSet();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Voz.desactivada = true;
    Sensaciones.desactivadas = true;
  });

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('meizi_desde_cero');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  test('las lecciones terminadas se guardan sin repetirse', () async {
    expect(await repo.leccionesTerminadas(), isEmpty);
    await repo.terminarLeccion(2);
    await repo.terminarLeccion(0);
    await repo.terminarLeccion(2);
    expect(await repo.leccionesTerminadas(), {0, 2});
    expect(await base.leerAjuste('desde_cero'), '0,2');
  });

  test('se ofrece en el inicio mientras falten lecciones y no lleves muchos repasos', () async {
    expect(await repo.ofrecerDesdeCero(), isTrue);
    for (var i = 0; i < DesdeCeroRepositorio.totalLecciones; i++) {
      await repo.terminarLeccion(i);
    }
    expect(await repo.ofrecerDesdeCero(), isFalse);

    await base.guardarAjuste('desde_cero', '');
    final lote = base.db.batch();
    for (var i = 0; i < DesdeCeroRepositorio.repasosParaOcultar; i++) {
      lote.insert('historial', {
        'caracter': '好',
        'momento': 1790000000 + i,
        'duracion_ms': 3000,
        'calificacion': 3,
        'errores': 0,
        'al_reves': 0,
        'modo_novato': 1,
        'nuevo': 0,
        'intervalo': 1,
      });
    }
    await lote.commit(noResult: true);
    expect(await repo.ofrecerDesdeCero(), isFalse);
  });

  test('seis lecciones, todas con varios pasos', () {
    final lecciones = leccionesDesdeCero();
    expect(lecciones, hasLength(DesdeCeroRepositorio.totalLecciones));
    for (final l in lecciones) {
      expect(l.pasos.length, inInclusiveRange(4, 6), reason: l.titulo);
    }
  });

  Future<void> mostrar(WidgetTester tester, Widget pantalla) async {
    // Un teléfono chico (360 × 640 dp): nada debe salirse.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async => null);
    await tester.pumpWidget(DatosApp(repo: repo, child: MaterialApp(home: pantalla)));
    await esperar(tester);
  }

  for (var indice = 0; indice < DesdeCeroRepositorio.totalLecciones; indice++) {
    testWidgets('la lección ${indice + 1} se recorre completa y queda terminada', (tester) async {
      await mostrar(tester, PantallaLeccion(indice: indice));
      final total = leccionesDesdeCero()[indice].pasos.length;
      for (var paso = 0; paso < total; paso++) {
        expect(find.text('Paso ${paso + 1} de $total'), findsOneWidget);
        // Los sonidos que se tocan en este paso existen.
        for (final t in tester.widgetList<TablaSonidos>(find.byType(TablaSonidos))) {
          for (final s in t.sonidos) {
            expect(silabas, contains(s.silaba), reason: s.letras);
          }
        }
        for (final a in tester.widgetList<AdivinaSonido>(find.byType(AdivinaSonido))) {
          for (final s in a.grupos.expand((g) => g)) {
            expect(silabas, contains(s));
          }
        }
        if (find.byType(AdivinaTono).evaluate().isNotEmpty) {
          for (final b in AdivinaTono.bases) {
            for (var t = 1; t <= 4; t++) {
              expect(silabas, contains('$b$t'));
            }
          }
        }
        // Los caracteres para escribir traen sus trazos.
        for (final l in tester.widgetList<LienzoEscritura>(find.byType(LienzoEscritura))) {
          expect(l.medianas, isNotEmpty, reason: l.caracter);
        }
        await tester.tap(find.text(paso == total - 1 ? 'Terminar' : 'Siguiente'));
        await esperar(tester);
      }
      expect(await tester.runAsync(repo.leccionesTerminadas), {indice});
      await tester.pump(const Duration(seconds: 3)); // vencen los temporizadores de las animaciones
    });
  }

  testWidgets('la lista marca las terminadas y ofrece Estudiar al acabar', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < DesdeCeroRepositorio.totalLecciones - 1; i++) {
        await repo.terminarLeccion(i);
      }
    });
    await mostrar(tester, const PantallaDesdeCero());
    expect(find.byIcon(Icons.check_circle), findsNWidgets(DesdeCeroRepositorio.totalLecciones - 1));
    expect(find.text('Ir a Estudiar'), findsNothing);

    await tester.runAsync(() => repo.terminarLeccion(DesdeCeroRepositorio.totalLecciones - 1));
    await mostrar(tester, const PantallaDesdeCero(key: ValueKey(2)));
    expect(find.text('Ir a Estudiar'), findsOneWidget);
  });

  testWidgets('¿qué tono oíste? cuenta los aciertos y sigue', (tester) async {
    await mostrar(tester, Scaffold(body: Center(child: AdivinaTono(azar: math.Random(7)))));
    expect(find.text('Toca «Escuchar» y elige.'), findsOneWidget);
    // Se elige la primera de las cuatro opciones (sea o no la correcta).
    final opciones = find.descendant(of: find.byType(Wrap), matching: find.byType(Text));
    await tester.tap(opciones.first);
    await tester.pump();
    expect(find.textContaining(' de 1'), findsOneWidget);
    await tester.tap(find.text('Otra'));
    await tester.pump();
    expect(find.text('Toca «Escuchar» y elige.'), findsOneWidget);
  });
}

/// Las consultas a la base (los trazos) son asíncronas de verdad.
Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}
