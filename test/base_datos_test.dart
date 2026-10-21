// Pruebas de la base de datos REAL (assets/db/contenido.db) usando SQLite de
// la computadora. Antes hay que construirla:
//   python herramientas_datos/construir_db.py
//   flutter test test/base_datos_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _rutaContenido = 'assets/db/contenido.db';

Future<ByteData> _leerContenido() async {
  final bytes = await File(_rutaContenido).readAsBytes();
  return ByteData.sublistView(bytes);
}

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_prueba');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  test('niveles oficiales: 300 por nivel del 1 al 6 y 1,200 en 7-9', () async {
    final niveles = await repo.avancePorNivel();
    expect({for (final n in niveles) n.nivel: n.total},
        {1: 300, 2: 300, 3: 300, 4: 300, 5: 300, 6: 300, 7: 1200});
  });

  test('la familia de 氵 (85) incluye 河 y 汉; la de 讠 (149) incluye 说', () async {
    final agua = (await repo.familia(85)).map((c) => c.caracter).toSet();
    expect(agua, containsAll(['河', '汉', '没']));
    final habla = (await repo.familia(149)).map((c) => c.caracter).toSet();
    expect(habla, contains('说'));
  });

  test('radicales: 214, y 氵 aparece como variante de 水', () async {
    final radicales = await repo.radicales();
    expect(radicales, hasLength(214));
    final agua = radicales.firstWhere((r) => r.numero == 85);
    expect(agua.variantes, contains('氵'));
    expect(agua.totalHsk, greaterThan(50));
  });

  test('búsqueda por carácter, pinyin sin tono e inglés/español', () async {
    expect((await repo.buscar('好')).first.caracter, '好');
    expect((await repo.buscar('hao')).map((c) => c.caracter), contains('好'));
    expect((await repo.buscar('nv')).map((c) => c.caracter), contains('女'));
  });

  test('estudiar: el primer nuevo de HSK 1 es de los más frecuentes y se guarda el progreso', () async {
    final c = await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true);
    expect(c, isNotNull);
    expect(c!.nivelHsk, 1);
    expect(c.trazosSvg, isNotEmpty);
    expect(c.medianas.length, c.trazosSvg.length);

    await repo.registrarRespuesta(c, Calificacion.facil);
    expect(await repo.nuevosHoy(), 1);
    final otraVez = await repo.caracter(c.id);
    expect(otraVez!.progreso, isNotNull);
    expect(otraVez.progreso!.vecesVisto, 1);

    // Ya no es "nuevo": el siguiente debe ser otro.
    final siguiente = await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true);
    expect(siguiente!.id, isNot(c.id));
  });

  test('abrir otra vez sin cerrar (conexión reutilizada) no falla', () async {
    // En Android, al salir con "atrás" el proceso puede seguir vivo y sqflite
    // devuelve la misma conexión, que ya tiene `c` adjunta.
    final otra = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    expect(await Repositorio(otra).totalEstudiados(), 0);
    if (!identical(otra.db, base.db)) await otra.cerrar();
  });

  test('un repaso de 1 día vence desde el inicio del día siguiente', () async {
    final c = (await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true))!;
    final noche = DateTime(2026, 3, 10, 21, 0);
    await repo.registrarRespuesta(c, Calificacion.medio, ahora: noche); // intervalo: 1 día

    expect(await repo.repasosPendientes(ahora: DateTime(2026, 3, 10, 23, 59)), 0);
    final manana = DateTime(2026, 3, 11, 8, 0);
    expect(await repo.repasosPendientes(ahora: manana), 1);
    final vencido = await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: false, ahora: manana);
    expect(vencido?.id, c.id);
  });

  test('calificar con una tarjeta "vieja" parte del progreso guardado', () async {
    final c = (await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true))!;
    await repo.registrarRespuesta(c, Calificacion.facil); // 1.er acierto: 1 día
    await repo.registrarRespuesta(c, Calificacion.facil); // misma foto de la tarjeta: 2.º acierto
    final guardado = (await repo.caracter(c.id))!.progreso!;
    expect(guardado.intervaloDias, 6);
    expect(guardado.vecesVisto, 2);
  });

  test('actualizar el contenido NO borra el progreso', () async {
    final c = (await repo.siguiente(const FiltroEstudio.nivel(2), permitirNuevos: true))!;
    await repo.registrarRespuesta(c, Calificacion.medio);
    await base.cerrar();

    // Simula una actualización de la app con contenido nuevo.
    base = await BaseDatos.abrir(
      carpeta: carpeta.path,
      cargarContenido: _leerContenido,
      versionEsperada: 'version-nueva-de-prueba',
    );
    repo = Repositorio(base);
    final despues = await repo.caracter(c.id);
    expect(despues!.progreso, isNotNull);
    expect(await base.leerAjuste('version_contenido'), 'version-nueva-de-prueba');
  });
}
