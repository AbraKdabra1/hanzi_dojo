// Pruebas de las frases esenciales con la base REAL:
//   · todas las frases del archivo están, en el orden de la app;
//   · cada frase trae la sílaba de cada carácter y sus palabras;
//   · el repaso espaciado, el avance por situación y el respaldo;
//   · quien ya tenía la app (esquema 6) gana la tabla de progreso;
//   · las opciones de «Escuchar y elegir» y las fichas de «Armar la frase»;
//   · las pantallas: la lista, los dos ejercicios y la tarjeta en Practicar.
//   flutter test test/frases_test.dart

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/frases.dart';
import 'package:hanzi_dojo/datos/practica.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_frases.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:hanzi_dojo/helpers/sensaciones.dart';
import 'package:hanzi_dojo/screens/pantalla_ejercicio_frases.dart';
import 'package:hanzi_dojo/screens/pantalla_frases.dart';
import 'package:hanzi_dojo/screens/pantalla_practica.dart';
import 'package:hanzi_dojo/widgets/boton_voz.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

/// Frases en el archivo de origen (sin comentarios ni encabezado).
final _enArchivo = File('herramientas_datos/fuentes/frases/frases_esenciales.tsv')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .length -
    1;

final _han = RegExp(r'[㐀-鿿]');

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
    carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_frases');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  test('están todas las frases del archivo, por situación y en orden', () async {
    final frases = await repo.frases();
    expect(frases, hasLength(_enArchivo));
    expect(frases.first.chino, '你好！');
    expect({for (final f in frases) f.situacion}, Situacion.values.toSet());
    for (var i = 1; i < frases.length; i++) {
      final (a, b) = (frases[i - 1], frases[i]);
      expect(a.situacion == b.situacion ? a.orden < b.orden : a.situacion.index < b.situacion.index, isTrue,
          reason: '${a.chino} va antes que ${b.chino}');
    }
    for (final f in frases) {
      expect(f.silabas, hasLength(f.chino.length), reason: f.chino);
      expect(f.palabras.map((w) => w.chino).join(), f.chino.split('').where(_han.hasMatch).join(), reason: f.chino);
      expect(f.espanol, isNotEmpty);
      expect(f.ingles, isNotEmpty);
      expect(f.nivelHsk, inInclusiveRange(1, 7));
      expect(f.progreso, isNull);
    }
    final compras = await repo.frases(situacion: Situacion.compras);
    expect(compras.every((f) => f.situacion == Situacion.compras), isTrue);
    expect(compras.map((f) => f.orden), [for (var i = 1; i <= compras.length; i++) i]);
  });

  test('una frase trae la sílaba de cada carácter y sus palabras', () async {
    final f = (await repo.frase(50))!;
    expect(f.chino, '这个多少钱？');
    expect(f.situacion, Situacion.compras);
    expect(f.silabas, ['zhè', 'ge', 'duō', 'shao', 'qián', '']);
    expect(f.palabras, [(chino: '这个', pinyin: 'zhège'), (chino: '多少', pinyin: 'duōshao'), (chino: '钱', pinyin: 'qián')]);
    expect(f.traduccion, '¿Cuánto cuesta esto?');
    expect(f.nota, isNull);

    // Erhua: el 儿 de 哪儿 va con la sílaba de antes.
    final donde = (await repo.frase(32))!;
    expect(donde.chino, '你住在哪儿？');
    expect(donde.silabas.sublist(3, 5), ['nǎ', 'r']);
    expect(donde.palabras.last, (chino: '哪儿', pinyin: 'nǎr'));

    expect(await repo.frase(99999), isNull);
    expect(Situacion.deClave('no-existe'), isNull);
  });

  test('repaso: primero lo que toca, después las nuevas en orden y luego el resto', () async {
    final hoy = DateTime(2026, 3, 10, 9);
    final azar = Random(1);
    final saludos = await repo.frases(situacion: Situacion.saludos);
    expect(elegirRonda(saludos, azar, ahora: hoy, cantidad: 3), saludos.take(3));

    final a = saludos[0];
    await repo.registrarFrase(a, Calificacion.facil, respuesta: '你好', duracionMs: 4000, ahora: hoy);
    await repo.registrarFrase(saludos[1], Calificacion.facil, ahora: hoy.add(const Duration(days: 5)));

    // Hoy no toca ninguna: primero las nuevas y al final las ya vistas.
    var ronda =
        elegirRonda(await repo.frases(situacion: Situacion.saludos), azar, ahora: hoy, cantidad: saludos.length);
    expect(ronda, hasLength(saludos.length));
    expect(ronda.take(saludos.length - 2), saludos.skip(2));
    expect(ronda.skip(saludos.length - 2).toSet(), {saludos[0], saludos[1]});
    expect(await repo.frasesPendientes(ahora: hoy), 0);

    // Dos días después ya toca la primera, y va antes que cualquier nueva.
    final despues = hoy.add(const Duration(days: 2));
    expect(await repo.frasesPendientes(ahora: despues), 1);
    ronda = elegirRonda(await repo.frases(), azar, ahora: despues, cantidad: 2);
    expect(ronda, [a, saludos[2]]);
    expect(ronda.first.progreso!.intervaloDias, 1);
    expect(ronda.first.progreso!.vecesVisto, 1);

    // Cada práctica queda en ejercicios.
    final ejercicios =
        await base.db.query('ejercicios', where: 'tipo = ?', whereArgs: [TipoEjercicio.frase], orderBy: 'id');
    expect(ejercicios.map((e) => e['elemento']), ['${a.id}', '${saludos[1].id}']);
    expect(ejercicios.first['resultado'], Calificacion.facil.q);
    expect(ejercicios.first['respuesta'], '你好');
  });

  test('avance por situación', () async {
    final emergencias = await repo.frases(situacion: Situacion.emergencias);
    await repo.registrarFrase(emergencias[0], Calificacion.medio);
    await repo.registrarFrase(emergencias[1], Calificacion.dificil);
    final avance = await repo.avanceFrases();
    expect(avance.map((a) => a.situacion), Situacion.values);
    final suya = avance.firstWhere((a) => a.situacion == Situacion.emergencias);
    expect((suya.total, suya.estudiadas, suya.dominadas), (emergencias.length, 2, 0));
    expect(avance.where((a) => a.situacion != Situacion.emergencias).every((a) => a.estudiadas == 0), isTrue);
    expect(avance.fold(0, (n, a) => n + a.total), _enArchivo);
  });

  test('el respaldo lleva el avance de las frases', () async {
    final f = (await repo.frase(12))!;
    await repo.registrarFrase(f, Calificacion.medio);
    final datos = Respaldo.leer(await Respaldo.exportar(base.db));
    expect(datos.progresoFrases.single['frase'], 12);

    final otra = await Directory.systemTemp.createTemp('hanzi_dojo_frases2');
    final base2 = await BaseDatos.abrir(carpeta: otra.path, cargarContenido: _leerContenido);
    try {
      await Respaldo.importar(base2, datos);
      final repo2 = Repositorio(base2);
      expect((await repo2.frase(12))!.progreso, isNotNull);
      expect((await repo2.avanceFrases()).firstWhere((a) => a.situacion == Situacion.cortesia).estudiadas, 1);
    } finally {
      await base2.cerrar();
      await otra.delete(recursive: true);
    }
  });

  test('migración: quien tenía el esquema 6 gana la tabla de frases', () async {
    final otra = await Directory.systemTemp.createTemp('hanzi_dojo_v6');
    BaseDatos? migrada;
    try {
      // progreso.db de la versión anterior (solo las tablas que se usan aquí).
      final v6 = await databaseFactory.openDatabase(
        p.join(otra.path, 'progreso.db'),
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE ajustes (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
            await db.execute('''
              CREATE TABLE ejercicios (
                id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT NOT NULL, elemento TEXT NOT NULL,
                momento INTEGER NOT NULL, resultado INTEGER NOT NULL, respuesta TEXT NOT NULL DEFAULT '',
                duracion_ms INTEGER NOT NULL DEFAULT 0)''');
          },
        ),
      );
      await v6.close();

      migrada = await BaseDatos.abrir(carpeta: otra.path, cargarContenido: _leerContenido);
      final repo6 = Repositorio(migrada);
      final f = (await repo6.frase(1))!;
      await repo6.registrarFrase(f, Calificacion.facil);
      expect((await repo6.frase(1))!.progreso, isNotNull);
    } finally {
      await migrada?.cerrar();
      await otra.delete(recursive: true);
    }
  });

  group('Ejercicios', () {
    test('escuchar y elegir: cuatro traducciones distintas de la misma situación', () async {
      final todas = await repo.frases();
      final azar = Random(7);
      for (final f in todas) {
        final pregunta = PreguntaFrase.armar(f, todas, azar);
        expect(pregunta.opciones, hasLength(4));
        expect(pregunta.opciones.where((o) => o == f), hasLength(1));
        expect(pregunta.opciones[pregunta.correcta], f);
        expect(pregunta.opciones.map((o) => o.traduccion).toSet(), hasLength(4), reason: f.chino);
        expect(pregunta.opciones.every((o) => o.situacion == f.situacion), isTrue, reason: f.chino);
      }
    });

    test('armar la frase: sus piezas más dos que sobran, revueltas', () async {
      final todas = await repo.frases();
      final azar = Random(7);
      for (final f in todas) {
        final armar = ArmarFrase.armar(f, todas, azar);
        final piezas = f.palabras.length > 1 ? f.palabras.length : f.silabas.where((s) => s.isNotEmpty).length;
        expect(armar.fichas, hasLength(piezas + 2), reason: f.chino);
        expect(armar.esCorrecta(f.palabras), isTrue);
      }

      final cuanto = (await repo.frase(50))!; // 这个多少钱？
      final armar = ArmarFrase.armar(cuanto, todas, azar);
      final sobran = armar.fichas.where((p) => !cuanto.palabras.contains(p)).map((p) => p.chino);
      expect(sobran, hasLength(2));
      expect(sobran.any((s) => ['这个', '多少', '钱'].contains(s)), isFalse);
      expect(armar.fichas.take(3).map((p) => p.chino).join(), isNot('这个多少钱'));
      expect(armar.esCorrecta(cuanto.palabras.reversed.toList()), isFalse);
      expect(armar.esCorrecta(const []), isFalse);

      // Una sola palabra: se arma con sus caracteres.
      final mesero = (await repo.frase(61))!; // 服务员！
      final fichas = ArmarFrase.armar(mesero, todas, azar).fichas;
      expect(fichas, containsAll([(chino: '服', pinyin: 'fú'), (chino: '务', pinyin: 'wù'), (chino: '员', pinyin: 'yuán')]));
    });

    test('bien a la primera es Fácil; si no, Difícil', () {
      expect(calificacionFrase(bien: true), Calificacion.facil);
      expect(calificacionFrase(bien: false), Calificacion.dificil);
    });
  });

  group('Pantallas', () {
    Future<void> esperar(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> mostrar(WidgetTester tester, Widget pantalla) async {
      // Un teléfono chico (360 × 640 dp): nada debe salirse.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async => null);
      await tester.pumpWidget(DatosApp(repo: repo, child: MaterialApp(home: pantalla)));
      await esperar(tester);
    }

    testWidgets('la lista muestra las frases por situación y se puede filtrar', (tester) async {
      await mostrar(tester, const PantallaFrases());
      expect(find.text('你好！'), findsOneWidget);
      expect(find.text('Escuchar y elegir'), findsOneWidget);
      expect(find.text('Armar la frase'), findsOneWidget);
      expect(find.text('0 de 11 practicadas'), findsOneWidget);

      final emergencias = find.widgetWithText(ChoiceChip, 'Emergencias');
      await tester.ensureVisible(emergencias);
      await tester.tap(emergencias);
      await esperar(tester);
      expect(find.text('你好！'), findsNothing);
      expect(find.text('救命！'), findsOneWidget);
    });

    testWidgets('escuchar y elegir: al contestar se ve la frase y se guarda el repaso', (tester) async {
      await mostrar(tester, const PantallaEjercicioFrases(modo: ModoFrases.escuchar, situacion: Situacion.saludos));
      expect(find.text('1 / 10'), findsOneWidget); // saludos tiene 11: la ronda es de 10
      await tester.tap(find.text('¡Hola!')); // la primera nueva: 你好！
      await esperar(tester);
      expect(find.text('你好！'), findsOneWidget);
      expect((await tester.runAsync(() => repo.frase(1)))!.progreso, isNotNull);
      await tester.tap(find.text('Siguiente'));
      await esperar(tester);
      expect(find.text('2 / 10'), findsOneWidget);
    });

    testWidgets('armar la frase: en orden está bien; al revés, no', (tester) async {
      await mostrar(tester, const PantallaEjercicioFrases(modo: ModoFrases.armar, situacion: Situacion.saludos));
      expect(find.text('¡Hola!'), findsOneWidget);
      // Tocar una ficha puesta la regresa.
      await tester.tap(find.text('你'));
      await tester.pump();
      await tester.tap(find.text('你'));
      await tester.pump();
      await tester.tap(find.text('好'));
      await tester.pump();
      await tester.tap(find.text('你'));
      await tester.pump();
      await tester.tap(find.text('Comprobar'));
      await esperar(tester);
      expect(find.text('Se dice así:'), findsOneWidget);
      expect(find.text('你好！'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await esperar(tester);
      expect(find.text('¡Hola! (con respeto)'), findsOneWidget); // 您好！
      await tester.tap(find.text('您'));
      await tester.pump();
      await tester.tap(find.text('好'));
      await tester.pump();
      await tester.tap(find.text('Comprobar'));
      await esperar(tester);
      expect(find.text('¡Así se dice!'), findsOneWidget);
      final ejercicios = await tester.runAsync(
          () => base.db.query('ejercicios', columns: ['elemento', 'resultado'], orderBy: 'id'));
      expect(ejercicios, [
        {'elemento': '1', 'resultado': Calificacion.dificil.q},
        {'elemento': '2', 'resultado': Calificacion.facil.q},
      ]);
    });

    testWidgets('Practicar empieza con las frases esenciales', (tester) async {
      await mostrar(tester, const PantallaPractica());
      expect(find.text('Frases esenciales'), findsOneWidget);
      expect(find.text('0 / $_enArchivo'), findsOneWidget);
    });
  });
}
