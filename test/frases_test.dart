// Pruebas de las frases esenciales (repositorio_frases.dart) con la base REAL:
//   · todas las frases del archivo están, en el orden de la app;
//   · cada frase trae la sílaba de cada carácter y sus palabras;
//   · el repaso espaciado, el avance por situación y el respaldo;
//   · quien ya tenía la app (esquema 6) gana la tabla de progreso.
//   flutter test test/frases_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/frases.dart';
import 'package:hanzi_dojo/datos/practica.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_frases.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/datos/srs.dart';
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

  test('repaso: primero lo que toca, después las nuevas en orden', () async {
    final hoy = DateTime(2026, 3, 10, 9);
    final saludos = await repo.frases(situacion: Situacion.saludos);

    final a = (await repo.siguienteFrase(situacion: Situacion.saludos, permitirNuevas: true, ahora: hoy))!;
    expect(a.id, saludos[0].id);
    await repo.registrarFrase(a, Calificacion.facil, respuesta: '你好', duracionMs: 4000, ahora: hoy);

    // Ya no es nueva y no toca hoy: sigue la segunda.
    final b = await repo.siguienteFrase(situacion: Situacion.saludos, permitirNuevas: true, ahora: hoy);
    expect(b!.id, saludos[1].id);
    expect(await repo.siguienteFrase(permitirNuevas: false, ahora: hoy), isNull);
    expect(await repo.frasesPendientes(ahora: hoy), 0);

    // Dos días después ya toca, y va antes que cualquier nueva.
    final despues = hoy.add(const Duration(days: 2));
    expect(await repo.frasesPendientes(ahora: despues), 1);
    final vencida = await repo.siguienteFrase(permitirNuevas: true, ahora: despues);
    expect(vencida!.id, a.id);
    expect(vencida.progreso!.intervaloDias, 1);
    expect(vencida.progreso!.vecesVisto, 1);
    expect(await repo.siguienteFrase(permitirNuevas: true, excluir: {a.id}, ahora: despues), b);

    // Cada práctica queda en ejercicios.
    final ejercicios = await base.db.query('ejercicios', where: 'tipo = ?', whereArgs: [TipoEjercicio.frase]);
    expect(ejercicios.single['elemento'], '${a.id}');
    expect(ejercicios.single['resultado'], Calificacion.facil.q);
    expect(ejercicios.single['respuesta'], '你好');
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
}
