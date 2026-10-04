// Pruebas del hábito (fase 6): protector de racha, logros, meta diaria,
// recordatorio y respaldo.
//   flutter test test/habito_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/estadisticas.dart';
import 'package:hanzi_dojo/datos/logros.dart';
import 'package:hanzi_dojo/datos/practica.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_habito.dart';
import 'package:hanzi_dojo/datos/repositorio_practica.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

DateTime d(int mes, int dia) => DateTime(2026, mes, dia);

void main() {
  group('Protector de racha', () {
    // Octubre de 2026: el 5 es lunes, el 11 domingo.
    test('cubre ayer si la racha venía viva', () {
      final r = Estadisticas.diasAProteger([d(10, 5), d(10, 6)], const [], DateTime(2026, 10, 8, 9));
      expect(r, [d(10, 7)]);
    });

    test('no hace nada si practicaste ayer o hoy', () {
      expect(Estadisticas.diasAProteger([d(10, 6), d(10, 7)], const [], d(10, 8)), isEmpty);
      expect(Estadisticas.diasAProteger([d(10, 7), d(10, 8)], const [], d(10, 8)), isEmpty);
    });

    test('uno por semana: si ya se usó esta semana, no se gasta otro', () {
      // Se protegió el 7; el 8 tampoco hubo práctica: la racha se rompe.
      expect(Estadisticas.diasAProteger([d(10, 5), d(10, 6)], [d(10, 7)], d(10, 9)), isEmpty);
      // Dos días seguidos en la misma semana: no alcanza, no se gasta nada.
      expect(Estadisticas.diasAProteger([d(10, 5), d(10, 6)], const [], d(10, 9)), isEmpty);
    });

    test('domingo y lunes son de semanas distintas: se cubren los dos', () {
      final r = Estadisticas.diasAProteger([d(10, 9), d(10, 10)], const [], d(10, 13));
      expect(r, [d(10, 11), d(10, 12)]);
    });

    test('no protege una racha de un solo día ni sin historial', () {
      expect(Estadisticas.diasAProteger([d(10, 6)], const [], d(10, 8)), isEmpty);
      expect(Estadisticas.diasAProteger(const [], const [], d(10, 8)), isEmpty);
    });

    test('mejor serie de aciertos', () {
      expect(Estadisticas.mejorSerie([true, true, false, true, true, true, false]), 3);
      expect(Estadisticas.mejorSerie(const []), 0);
    });
  });

  group('Logros', () {
    test('cada clave es única y cada logro tiene meta', () {
      final claves = Logros.todos.map((l) => l.clave).toList();
      expect(claves.toSet().length, claves.length);
      expect(Logros.todos.every((l) => l.meta > 0), isTrue);
      expect(Logros.porClave('racha_7')!.meta, 7);
    });

    test('nuevos: solo los que cumples y no tenías', () {
      const datos = DatosLogros(
        caracteres: 120,
        rachaMaxima: 8,
        estudiadosPorNivel: {1: 300, 2: 10},
        totalPorNivel: {1: 300, 2: 300},
        mejorSerieTonos: 10,
      );
      final nuevos = Logros.nuevos(datos, {'primer_caracter'}).map((l) => l.clave).toSet();
      expect(nuevos, containsAll(['racha_7', 'caracteres_100', 'nivel_1', 'oido_10']));
      expect(nuevos, isNot(contains('primer_caracter'))); // ya lo tenía
      expect(nuevos, isNot(contains('nivel_2')));
      expect(nuevos, isNot(contains('racha_30')));
      expect(Logros.porClave('racha_30')!.avance(datos), closeTo(8 / 30, 1e-9));
    });
  });

  group('Con la base real', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_habito');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      repo = Repositorio(base);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('el protector se aplica una vez y la racha lo cuenta', () async {
      final hao = await repo.caracterPorTexto('好');
      await repo.registrarRespuesta(hao!, Calificacion.facil, ahora: DateTime(2026, 10, 5, 20));
      await repo.registrarRespuesta(hao, Calificacion.facil, ahora: DateTime(2026, 10, 6, 20));
      final jueves = DateTime(2026, 10, 8, 9);
      expect(await repo.aplicarProtector(ahora: jueves), [d(10, 7)]);
      expect(await repo.aplicarProtector(ahora: jueves), isEmpty); // ya estaba
      expect((await repo.rachaConProtector(ahora: jueves)).actual, 3);
      expect(await repo.protectorDisponible(ahora: jueves), isFalse);
      expect(await repo.protectorDisponible(ahora: d(10, 12)), isTrue); // lunes siguiente
    });

    test('logros: se desbloquean una sola vez y se recuerdan', () async {
      expect(await repo.revisarLogros(), isEmpty);
      final ai = await repo.caracterPorTexto('爱');
      await repo.registrarRespuesta(ai!, Calificacion.facil);
      final nuevos = await repo.revisarLogros();
      expect(nuevos.map((l) => l.clave), ['primer_caracter']);
      expect(await repo.revisarLogros(), isEmpty);
      expect((await repo.logrosDesbloqueados()).keys, ['primer_caracter']);
    });

    test('serie de tonos para «Oído fino»', () async {
      for (var i = 0; i < 10; i++) {
        await repo.registrarEjercicio(TipoEjercicio.tono, 'ma1', correcto: true, respuesta: '1');
      }
      final datos = await repo.datosLogros();
      expect(datos.mejorSerieTonos, 10);
      expect((await repo.revisarLogros()).map((l) => l.clave), contains('oido_10'));
    });

    test('meta diaria: actividad de hoy y celebración una sola vez', () async {
      expect(await repo.metaDiaria(), HabitoRepositorio.metaPorDefecto);
      await repo.guardarMetaDiaria(10);
      expect(await repo.metaDiaria(), 10);
      final hao = await repo.caracterPorTexto('好');
      await repo.registrarRespuesta(hao!, Calificacion.facil);
      await repo.registrarEjercicio(TipoEjercicio.escucha, '好', correcto: true);
      expect(await repo.actividadHoy(), 2);
      expect(await repo.metaCelebradaHoy(), isFalse);
      await repo.marcarMetaCelebrada();
      expect(await repo.metaCelebradaHoy(), isTrue);
    });

    test('recordatorio: hora guardada o apagado', () async {
      expect(await repo.recordatorio(), isNull);
      await repo.guardarRecordatorio((7, 5));
      expect(await repo.recordatorio(), (7, 5));
      await repo.guardarRecordatorio(null);
      expect(await repo.recordatorio(), isNull);
    });

    test('el respaldo lleva logros y días protegidos', () async {
      final hao = await repo.caracterPorTexto('好');
      await repo.registrarRespuesta(hao!, Calificacion.facil, ahora: DateTime(2026, 10, 5, 20));
      await repo.registrarRespuesta(hao, Calificacion.facil, ahora: DateTime(2026, 10, 6, 20));
      await repo.aplicarProtector(ahora: DateTime(2026, 10, 8, 9));
      await repo.revisarLogros();
      final datos = Respaldo.leer(await Respaldo.exportar(base.db));
      expect(datos.protecciones.single['dia'], '2026-10-07');
      expect(datos.logros.map((f) => f['clave']), contains('primer_caracter'));
    });
  });
}
