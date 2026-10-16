// Pruebas de la fase 1 "tus datos": historial de repasos, migración del
// esquema, exportar/importar el progreso y deshacer una importación.
// Usan la base de contenido REAL y SQLite de la computadora.
//   flutter test test/datos_usuario_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/modelos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

Future<BaseDatos> _abrir(String carpeta) =>
    BaseDatos.abrir(carpeta: carpeta, cargarContenido: _leerContenido);

Uint8List _gzipJson(Object json) => Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_datos');
    base = await _abrir(carpeta.path);
    repo = Repositorio(base);
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  /// Practica [n] caracteres nuevos de HSK 1 con distintos detalles.
  Future<List<Caracter>> practicar(int n) async {
    final hechos = <Caracter>[];
    for (int i = 0; i < n; i++) {
      final c = (await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true))!;
      await repo.registrarRespuesta(
        c,
        i.isEven ? Calificacion.facil : Calificacion.dificil,
        detalle: DetallePractica(
          duracion: Duration(seconds: 5 + i),
          fallos: i.isEven ? const [] : const [FalloTrazo(1), FalloTrazo(2, alReves: true)],
          modoNovato: i.isEven,
        ),
      );
      hechos.add(c);
    }
    return hechos;
  }

  group('Historial', () {
    test('cada calificación agrega una fila con los detalles', () async {
      final c = (await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true))!;
      final momento = DateTime(2026, 9, 30, 21, 0);
      await repo.registrarRespuesta(
        c,
        Calificacion.medio,
        ahora: momento,
        detalle: const DetallePractica(
          duracion: Duration(seconds: 12, milliseconds: 300),
          fallos: [FalloTrazo(0), FalloTrazo(3, alReves: true), FalloTrazo(3)],
          modoNovato: false,
        ),
      );
      await repo.registrarRespuesta(c, Calificacion.facil, ahora: momento.add(const Duration(days: 1)));

      final filas = await base.db.rawQuery('SELECT * FROM historial ORDER BY momento');
      expect(filas, hasLength(2));
      final primera = filas.first;
      expect(primera['caracter'], c.caracter);
      expect(primera['momento'], momento.millisecondsSinceEpoch ~/ 1000);
      expect(primera['duracion_ms'], 12300);
      expect(primera['calificacion'], 3);
      expect(primera['errores'], 3);
      expect(primera['al_reves'], 1);
      expect(primera['fallos'], '0,3r,3');
      expect(primera['modo_novato'], 0);
      expect(primera['nuevo'], 1);
      expect(primera['intervalo'], 1);
      // El segundo repaso ya no es "nuevo".
      expect(filas.last['nuevo'], 0);
      expect(await repo.totalRepasos(), 2);
    });

    test('una tarjeta olvidada en pantalla cuenta 10 minutos como máximo', () async {
      final c = (await repo.siguiente(const FiltroEstudio.nivel(1), permitirNuevos: true))!;
      await repo.registrarRespuesta(c, Calificacion.facil,
          detalle: const DetallePractica(duracion: Duration(hours: 2)));
      final fila = (await base.db.rawQuery('SELECT duracion_ms FROM historial')).single;
      expect(fila['duracion_ms'], const Duration(minutes: 10).inMilliseconds);
    });

    test('los fallos se leen igual que se escriben', () {
      const fallos = [FalloTrazo(0), FalloTrazo(12, alReves: true), FalloTrazo(12)];
      final texto = FalloTrazo.escribirLista(fallos);
      expect(texto, '0,12r,12');
      expect(FalloTrazo.leerLista(texto), fallos);
      expect(FalloTrazo.leerLista(''), isEmpty);
    });
  });

  test('migración: quien tenía la versión 1 conserva su avance y gana el historial', () async {
    await base.cerrar();
    final otra = await Directory.systemTemp.createTemp('hanzi_dojo_v1');
    try {
      // progreso.db tal como lo creaba la versión anterior de la app.
      final v1 = await databaseFactory.openDatabase(
        p.join(otra.path, 'progreso.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE progreso (
                caracter TEXT PRIMARY KEY, intervalo INTEGER NOT NULL DEFAULT 0,
                factor REAL NOT NULL DEFAULT 2.5, aciertos_seguidos INTEGER NOT NULL DEFAULT 0,
                veces_visto INTEGER NOT NULL DEFAULT 0, proximo_repaso INTEGER NOT NULL DEFAULT 0,
                primera_vez INTEGER NOT NULL, ultima_vez INTEGER NOT NULL)''');
            await db.execute('CREATE TABLE ajustes (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
          },
        ),
      );
      await v1.insert('progreso', {
        'caracter': '好',
        'intervalo': 6,
        'veces_visto': 2,
        'proximo_repaso': 0,
        'primera_vez': 1,
        'ultima_vez': 2,
      });
      await v1.close();

      base = await _abrir(otra.path);
      repo = Repositorio(base);
      expect(await repo.totalEstudiados(), 1);
      expect(await repo.totalRepasos(), 0); // la tabla nueva existe (vacía)
      final c = (await repo.buscar('好')).first;
      await repo.registrarRespuesta(c, Calificacion.facil);
      expect(await repo.totalRepasos(), 1);
    } finally {
      await base.cerrar();
      await otra.delete(recursive: true);
      base = await _abrir(carpeta.path); // para el tearDown
    }
  });

  group('Respaldo', () {
    test('exportar e importar en otro teléfono deja exactamente lo mismo', () async {
      await practicar(4);
      await repo.guardarLimiteNuevosPorDia(25);
      await repo.guardarAjusteCaligrafico(false);
      final bytes = await Respaldo.exportar(base.db);

      // "Otro teléfono": una instalación nueva.
      final otra = await Directory.systemTemp.createTemp('hanzi_dojo_otro');
      final base2 = await _abrir(otra.path);
      try {
        final datos = Respaldo.leer(bytes);
        expect(datos.caracteres, 4);
        expect(datos.repasos, 4);
        await Respaldo.importar(base2, datos);

        Future<List<Map<String, Object?>>> tabla(Database db, String sql) => db.rawQuery(sql);
        const sqlProgreso = 'SELECT * FROM progreso ORDER BY caracter';
        const sqlHistorial = 'SELECT caracter, momento, duracion_ms, calificacion, errores, '
            'al_reves, fallos, modo_novato, nuevo, intervalo FROM historial ORDER BY momento, id';
        expect(await tabla(base2.db, sqlProgreso), await tabla(base.db, sqlProgreso));
        expect(await tabla(base2.db, sqlHistorial), await tabla(base.db, sqlHistorial));

        final repo2 = Repositorio(base2);
        expect(await repo2.limiteNuevosPorDia(), 25);
        expect(await repo2.ajusteCaligrafico(), isFalse);
        // La versión del contenido es de cada instalación: no se importa.
        expect(await base2.leerAjuste('version_contenido'), await base.leerAjuste('version_contenido'));
      } finally {
        await base2.cerrar();
        await otra.delete(recursive: true);
      }
    });

    test('importar reemplaza y se puede deshacer', () async {
      final originales = await practicar(3);
      final mio = await Respaldo.exportar(base.db);

      // Un respaldo de "otra persona" con un solo carácter.
      final ajeno = _gzipJson({
        'formato': Respaldo.formato,
        'version': 1,
        'creado': '2026-01-02T03:04:05.000',
        'progreso': [
          {
            'caracter': '龙',
            'intervalo': 6,
            'factor': 2.6,
            'aciertos_seguidos': 2,
            'veces_visto': 2,
            'proximo_repaso': 0,
            'primera_vez': 1,
            'ultima_vez': 2,
          },
        ],
        'historial': <Object>[],
        'ajustes': {'nuevos_por_dia': '40'},
      });

      expect(await Respaldo.hayRespaldoPrevio(base), isFalse);
      final datos = Respaldo.leer(ajeno);
      expect(datos.creado, DateTime(2026, 1, 2, 3, 4, 5));
      await Respaldo.importar(base, datos);
      expect(await repo.totalEstudiados(), 1);
      expect(await repo.totalRepasos(), 0);
      expect(await repo.limiteNuevosPorDia(), 40);
      expect(await Respaldo.hayRespaldoPrevio(base), isTrue);

      await Respaldo.deshacerImportacion(base);
      expect(await repo.totalEstudiados(), originales.length);
      expect(await repo.totalRepasos(), originales.length);
      expect(await repo.limiteNuevosPorDia(), Repositorio.limitePorDefecto);
      expect(await Respaldo.hayRespaldoPrevio(base), isFalse);
      // Quedó idéntico a antes de importar.
      expect(Respaldo.leer(await Respaldo.exportar(base.db)).progreso, Respaldo.leer(mio).progreso);
    });

    test('archivos que no sirven se rechazan sin tocar el progreso', () async {
      await practicar(2);
      void rechaza(Uint8List bytes, String contiene) => expect(
            () => Respaldo.leer(bytes),
            throwsA(isA<RespaldoInvalido>().having((e) => e.mensaje, 'mensaje', contains(contiene))),
          );

      rechaza(Uint8List.fromList(utf8.encode('hola, no soy un respaldo')), 'no es un respaldo');
      rechaza(_gzipJson({'formato': 'otra-app', 'version': 1}), 'no es un respaldo');
      rechaza(_gzipJson({'formato': Respaldo.formato, 'version': 99, 'progreso': []}), 'más nueva');
      rechaza(
        _gzipJson({
          'formato': Respaldo.formato,
          'version': 1,
          'progreso': [
            {'caracter': '好', 'intervalo': 'mucho'},
          ],
        }),
        'dañado',
      );
      expect(await repo.totalEstudiados(), 2);
    });

    test('nombre sugerido con la fecha', () {
      expect(Respaldo.nombreSugerido(DateTime(2026, 9, 3)), 'meizi_hanzi_2026-09-03.meizi');
    });
  });
}
