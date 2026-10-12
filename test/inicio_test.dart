// El inicio: la lista de cristal dice lo que toca en cada renglón y lleva a
// su pantalla. (La pregunta de «Chino desde cero» y los candados están en
// desde_cero_test.dart.)
//   flutter test test/inicio_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/desde_cero.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_habito.dart';
import 'package:hanzi_dojo/helpers/actualizaciones.dart';
import 'package:hanzi_dojo/helpers/energia.dart';
import 'package:hanzi_dojo/helpers/sensaciones.dart';
import 'package:hanzi_dojo/screens/pantalla_biblioteca.dart';
import 'package:hanzi_dojo/screens/pantalla_inicio.dart';
import 'package:hanzi_dojo/widgets/boton_voz.dart';
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
    carpeta = await Directory.systemTemp.createTemp('meizi_inicio');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
    // Sin tutorial ni preguntas encima: directo al inicio.
    await repo.marcarTutorialVisto();
    await repo.elegirDesdeCero(false);
    await repo.guardarAvisarVersiones(false);
  });

  tearDown(() async {
    Energia.ahorro.value = false;
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> mostrarInicio(WidgetTester tester) async {
    // Un teléfono chico (360 × 640 dp): nada debe salirse.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async => null);
    await tester.pumpWidget(DatosApp(repo: repo, child: const MaterialApp(home: PantallaInicio())));
    await esperar(tester);
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox()); // apaga los relojes del inicio
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('cada renglón dice lo que toca y lleva a su pantalla', (tester) async {
    final (libro, nuevos) = (await tester.runAsync(() async {
      final libro = (await repo.libros()).firstWhere((l) => l.capitulos > 1);
      await base.db.insert('lectura', {'libro': libro.clave, 'capitulo': 1, 'momento': 1790000000});
      return (libro, await repo.limiteNuevosPorDia());
    }))!;
    await mostrarInicio(tester);

    expect(find.text('Estudiar'), findsOneWidget);
    expect(find.text('$nuevos nuevos'), findsOneWidget); // aún sin repasos pendientes
    expect(find.text('Tonos, escucha, vocabulario y pinyin'), findsOneWidget);
    expect(find.text('Sigue: ${libro.titulo} · capítulo 2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.text('Chino desde cero'), findsNothing); // lo omitió: está en Ajustes
    // Cristal de verdad: el fondo se desenfoca detrás del resumen y la lista.
    expect(find.byType(BackdropFilter), findsNWidgets(2));

    await tester.tap(find.text('Leer'));
    await esperar(tester);
    expect(find.byType(PantallaBiblioteca), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('con el ahorro de batería, el cristal no desenfoca', (tester) async {
    Energia.ahorro.value = true;
    await mostrarInicio(tester);
    expect(find.text('Estudiar'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    await cerrar(tester);
  });

  testWidgets('desde cero: va primero en la lista, con su avance', (tester) async {
    await tester.runAsync(() async {
      await repo.elegirDesdeCero(true);
      await repo.terminarLeccion(0);
      await repo.terminarLeccion(1);
    });
    await mostrarInicio(tester);
    final desdeCero = tester.getTopLeft(find.text('Chino desde cero')).dy;
    expect(desdeCero, lessThan(tester.getTopLeft(find.text('Estudiar')).dy));
    expect(find.text('2 de 6 lecciones'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Con candado: dicen para qué sirven, no lo pendiente.
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));
    expect(find.text('Escribe caracteres, trazo a trazo'), findsOneWidget);
    expect(find.textContaining('nuevos'), findsNothing);
    await cerrar(tester);
  });
}
