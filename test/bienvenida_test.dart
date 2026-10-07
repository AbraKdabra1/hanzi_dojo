// El tutorial de la primera vez: cuándo sale, que se recorre hasta escribir
// el primer carácter y que se puede omitir.
//   flutter test test/bienvenida_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_habito.dart';
import 'package:hanzi_dojo/helpers/sensaciones.dart';
import 'package:hanzi_dojo/painters/geometria.dart';
import 'package:hanzi_dojo/screens/pantalla_bienvenida.dart';
import 'package:hanzi_dojo/widgets/animacion_trazos.dart';
import 'package:hanzi_dojo/widgets/boton_voz.dart';
import 'package:hanzi_dojo/widgets/lienzo_escritura.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Voz.desactivada = true;
    Sensaciones.desactivadas = true;
  });

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('meizi_bienvenida');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  test('sale la primera vez; quien ya tenía progreso no lo ve', () async {
    expect(await repo.tutorialVisto(), isFalse);
    await repo.marcarTutorialVisto();
    expect(await repo.tutorialVisto(), isTrue);
  });

  test('al actualizar con progreso guardado cuenta como visto', () async {
    final hao = await repo.caracterPorTexto('好');
    await base.db.insert('historial', {
      'caracter': hao!.caracter,
      'momento': 1790000000,
      'duracion_ms': 4000,
      'calificacion': 3,
      'errores': 0,
      'al_reves': 0,
      'modo_novato': 1,
      'nuevo': 1,
      'intervalo': 1,
    });
    expect(await repo.tutorialVisto(), isTrue);
    expect(await base.leerAjuste('tutorial_visto'), '1');
  });

  Future<void> mostrar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DatosApp(repo: repo, child: const MaterialApp(home: PantallaBienvenida())));
    // Carga 永 y 人 de la base (consultas de verdad).
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esperarGuardado(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Escribe con el "dedo" cada trazo del lienzo, siguiendo sus medianas.
  Future<void> escribir(WidgetTester tester) async {
    final lienzo = find.byType(LienzoEscritura);
    final medianas = tester.widget<LienzoEscritura>(lienzo).medianas;
    final origen = tester.getTopLeft(lienzo);
    final tamano = tester.getSize(lienzo);
    Offset aPantalla(Offset p) => origen + GeometriaLienzo.aLienzo(p, tamano);
    for (final mediana in medianas) {
      final gesto = await tester.startGesture(aPantalla(mediana.first));
      for (var i = 1; i < mediana.length; i++) {
        for (var j = 1; j <= 6; j++) {
          await gesto.moveTo(aPantalla(Offset.lerp(mediana[i - 1], mediana[i], j / 6)!));
          await tester.pump(const Duration(milliseconds: 8));
        }
      }
      await gesto.up();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('se recorre hasta escribir el primer carácter', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async => null);
    await mostrar(tester);
    expect(find.text('Aprende a escribir chino, trazo a trazo'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);

    for (var i = 1; i < PantallaBienvenida.paginas; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      if (i == 1) {
        // 永 con sus trazos: la animación tiene qué dibujar.
        expect(tester.widget<AnimacionTrazos>(find.byType(AnimacionTrazos)).medianas, hasLength(5));
      }
    }
    expect(find.text('Escribe tu primer carácter'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing); // en la última ya no hace falta
    expect(find.text('Empezar'), findsOneWidget);

    // 人: dos trazos, y al terminarlo la felicitación.
    expect(tester.widget<LienzoEscritura>(find.byType(LienzoEscritura)).medianas, hasLength(2));
    await escribir(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('¡Muy bien! Así se escribe con Meizi Hanzi. Toca «Empezar».'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await esperarGuardado(tester);
    expect(await tester.runAsync(repo.tutorialVisto), isTrue);
    await tester.pump(const Duration(seconds: 2)); // vencen los temporizadores del lienzo
  });

  testWidgets('«Omitir» lo cierra y queda visto', (tester) async {
    await mostrar(tester);
    await tester.tap(find.text('Omitir'));
    await esperarGuardado(tester);
    expect(await tester.runAsync(repo.tutorialVisto), isTrue);
  });
}
