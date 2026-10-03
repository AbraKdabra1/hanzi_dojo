// Pruebas de las estadísticas: rachas, trazos que más fallas, calendario y
// consultas sobre el historial real.
//   flutter test test/estadisticas_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/estadisticas.dart';
import 'package:hanzi_dojo/datos/modelos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

DateTime d(int mes, int dia) => DateTime(2026, mes, dia);

void main() {
  group('Racha', () {
    test('sin días, cero', () {
      final r = Estadisticas.racha(const [], d(10, 2));
      expect((r.actual, r.maxima), (0, 0));
    });

    test('cuenta hasta hoy; si hoy no estudiaste, sigue viva desde ayer', () {
      final dias = [d(9, 28), d(9, 29), d(9, 30), d(10, 1)];
      expect(Estadisticas.racha(dias, d(10, 1)).actual, 4);
      expect(Estadisticas.racha(dias, d(10, 2)).actual, 4); // hoy aún no
      expect(Estadisticas.racha(dias, d(10, 3)).actual, 0); // se rompió ayer
    });

    test('la más larga, cruzando meses y con horas distintas', () {
      final dias = [
        DateTime(2026, 8, 30, 23, 50), d(8, 31), DateTime(2026, 9, 1, 7), d(9, 2), // 4
        d(9, 10), d(9, 11), // 2
        d(10, 2), // hoy
      ];
      final r = Estadisticas.racha(dias, DateTime(2026, 10, 2, 20));
      expect(r.maxima, 4);
      expect(r.actual, 1);
    });
  });

  test('trazos que más fallas: por carácter y trazo, con los al revés', () {
    final t = Estadisticas.trazosFallados([
      ('我', '2,2r'),
      ('我', '2r'),
      ('好', '0'),
      ('好', '0,1'),
      ('人', '1'), // una sola vez: no aparece
    ]);
    expect(t.map((x) => (x.caracter, x.indice, x.veces, x.alReves)), [('我', 2, 3, 2), ('好', 0, 2, 0)]);
  });

  test('niveles del calendario y lunes de la semana', () {
    expect([0, 1, 9, 10, 24, 25, 49, 50, 300].map(Estadisticas.nivelCalendario), [0, 1, 1, 2, 2, 3, 3, 4, 4]);
    expect(Estadisticas.lunes(DateTime(2026, 10, 4)), DateTime(2026, 9, 28)); // domingo → lunes anterior
    expect(Estadisticas.lunes(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
  });

  group('Consultas sobre el historial', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_estadisticas');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      repo = Repositorio(base);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    Future<Caracter> buscar(String c) async => (await repo.buscar(c)).first;

    test('actividad por día, difíciles, trazos y precisión', () async {
      final wo = await buscar('我');
      final hao = await buscar('好');
      final ayer = DateTime.now().subtract(const Duration(days: 1));
      final hoy = DateTime.now();

      await repo.registrarRespuesta(wo, Calificacion.dificil,
          ahora: ayer,
          detalle: const DetallePractica(
              duracion: Duration(seconds: 30), fallos: [FalloTrazo(2, alReves: true), FalloTrazo(2)], modoNovato: false));
      await repo.registrarRespuesta(wo, Calificacion.medio,
          ahora: hoy, detalle: const DetallePractica(duracion: Duration(seconds: 20), fallos: [FalloTrazo(2)]));
      await repo.registrarRespuesta(hao, Calificacion.facil,
          ahora: hoy, detalle: const DetallePractica(duracion: Duration(seconds: 10)));

      final dias = await repo.actividadPorDia();
      expect(dias.map((x) => x.repasos), [1, 2]);
      expect(dias.last.dia, DateTime(hoy.year, hoy.month, hoy.day));
      expect(dias.last.segundos, 30);
      expect(Estadisticas.racha(dias.map((x) => x.dia), hoy).actual, 2);

      final dificiles = await repo.caracteresDificiles();
      expect(dificiles.single.caracter.caracter, '我'); // 好 no tuvo errores
      expect(dificiles.single.erroresPromedio, 1.5);
      expect(dificiles.single.dificiles, 1);

      final trazos = await repo.trazosFallados();
      expect(trazos.single.caracter, '我');
      expect((trazos.single.indice, trazos.single.veces, trazos.single.alReves), (2, 3, 1));
      final conTrazos = await repo.caracterConTrazos('我');
      expect(conTrazos!.trazosSvg.length, greaterThan(2));

      final p = await repo.precision();
      expect(p.repasos, 3);
      expect(p.limpios, 1);
      expect(p.experto, 0);
      expect(p.novato, 0.5);
    });
  });
}
