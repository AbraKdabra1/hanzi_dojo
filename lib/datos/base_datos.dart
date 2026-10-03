// ─────────────────────────────────────────────────────────────────────────────
// base_datos.dart — Abre las dos bases de datos de la app
//
// La app usa DOS archivos SQLite:
//
//   contenido.db  Caracteres, radicales y ejemplos. Viene armado dentro de la
//                 app (assets/db/contenido.db). En el primer arranque, o
//                 cuando una actualización trae contenido nuevo, se copia a la
//                 carpeta de datos del teléfono. Nunca se modifica.
//
//   progreso.db   Tu avance (repaso espaciado), tu historial de repasos y
//                 tus ajustes. Se crea vacío y solo lo modifica la app. Como
//                 todo se guarda por CARÁCTER (no por número de fila), al
//                 actualizar el contenido no se pierde nada.
//
// Versiones del esquema de progreso.db:
//   1  progreso + ajustes
//   2  + historial (una fila por repaso: base de las estadísticas)
//   3  + lectura (capítulos de la sección «Leer» que ya terminaste)
//   4  + mis_libros, mis_capitulos, mis_parrafos (libros que agregaste tú)
//
// Se abre una sola conexión a progreso.db y se "adjunta" contenido.db con el
// alias `c`. Así una misma consulta puede unir ambas:
//     SELECT … FROM c.caracteres LEFT JOIN progreso ON …
//
// Antes (v1) la app leía un JSON de 59 MB e insertaba 9,574 filas en el
// primer arranque. Ahora solo copia un archivo: el arranque es inmediato.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'version_contenido.dart';

/// Carga los bytes de la base de contenido empaquetada en la app.
/// En las pruebas se reemplaza para leer el archivo directamente del disco.
typedef CargadorContenido = Future<ByteData> Function();

Future<ByteData> _cargarDesdeAssets() => rootBundle.load('assets/db/contenido.db');

class BaseDatos {
  BaseDatos._(this.db, this.carpeta);

  /// Conexión principal (progreso.db con contenido.db adjunta como `c`).
  final Database db;

  /// Carpeta donde viven las bases (ahí también se guardan el respaldo
  /// previo a una importación y el registro de errores).
  final String carpeta;

  static const _archivoContenido = 'contenido.db';
  static const _archivoProgreso = 'progreso.db';
  static const _versionEsquemaProgreso = 4;

  /// Abre (y si hace falta, prepara) las bases de datos.
  ///
  /// [carpeta] y [cargarContenido] solo se usan en las pruebas; en la app
  /// se toma la carpeta estándar de bases de datos del teléfono y el asset.
  static Future<BaseDatos> abrir({
    String? carpeta,
    CargadorContenido cargarContenido = _cargarDesdeAssets,
    String versionEsperada = kVersionContenido,
  }) async {
    final dir = carpeta ?? await getDatabasesPath();
    await Directory(dir).create(recursive: true);

    // 1. Base de progreso (se crea la primera vez).
    final db = await openDatabase(
      p.join(dir, _archivoProgreso),
      version: _versionEsquemaProgreso,
      onCreate: _crearEsquemaProgreso,
      onUpgrade: _actualizarEsquemaProgreso,
    );

    // 2. ¿Hay que copiar (o reemplazar) la base de contenido?
    //
    // Ojo: sqflite reutiliza la conexión si sigue abierta de un arranque
    // anterior en el mismo proceso (en Android, al salir con "atrás" el
    // proceso puede seguir vivo; también pasa con el hot restart). En ese caso
    // `c` ya está adjunta y volver a adjuntarla daría "database c is already
    // in use", así que primero se revisa.
    final rutaContenido = p.join(dir, _archivoContenido);
    var adjunta = await _contenidoAdjunto(db);
    final versionLocal = await _leerAjuste(db, 'version_contenido');
    if (versionLocal != versionEsperada || !await File(rutaContenido).exists()) {
      if (adjunta) {
        await db.execute('DETACH DATABASE c');
        adjunta = false;
      }
      await _copiarContenido(rutaContenido, cargarContenido);
      await _guardarAjuste(db, 'version_contenido', versionEsperada);
    }

    // 3. Adjuntar el contenido con el alias `c` (si no lo estaba ya).
    if (!adjunta) {
      await db.execute('ATTACH DATABASE ? AS c', [rutaContenido]);
    }
    return BaseDatos._(db, dir);
  }

  /// ¿La conexión ya tiene adjunta la base de contenido como `c`?
  static Future<bool> _contenidoAdjunto(Database db) async {
    final filas = await db.rawQuery('PRAGMA database_list');
    return filas.any((f) => f['name'] == 'c');
  }

  /// Escribe el archivo de contenido de forma segura: primero a un temporal
  /// y luego se renombra. Si la app se cierra a la mitad, no queda corrupto.
  static Future<void> _copiarContenido(String destino, CargadorContenido cargar) async {
    final datos = await cargar();
    final temporal = File('$destino.tmp');
    await temporal.writeAsBytes(
      datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
      flush: true,
    );
    await temporal.rename(destino);
  }

  /// Tablas de progreso.db (instalación nueva: ya con la última versión).
  static Future<void> _crearEsquemaProgreso(Database db, int version) async {
    // Una fila por carácter que hayas estudiado al menos una vez.
    await db.execute('''
      CREATE TABLE progreso (
        caracter          TEXT PRIMARY KEY,
        intervalo         INTEGER NOT NULL DEFAULT 0,   -- días entre repasos
        factor            REAL    NOT NULL DEFAULT 2.5, -- factor de facilidad SM-2
        aciertos_seguidos INTEGER NOT NULL DEFAULT 0,
        veces_visto       INTEGER NOT NULL DEFAULT 0,
        proximo_repaso    INTEGER NOT NULL DEFAULT 0,   -- segundos Unix
        primera_vez       INTEGER NOT NULL,             -- segundos Unix (límite diario)
        ultima_vez        INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_progreso_repaso ON progreso (proximo_repaso)');
    await db.execute('CREATE INDEX idx_progreso_primera ON progreso (primera_vez)');

    // Ajustes sencillos clave → valor (límite diario, versión del contenido…).
    await db.execute('''
      CREATE TABLE ajustes (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
    await _crearHistorial(db);
    await _crearLectura(db);
    await _crearMisLibros(db);
  }

  /// Quien ya tenía la app: se agregan las tablas nuevas sin tocar su avance.
  static Future<void> _actualizarEsquemaProgreso(Database db, int anterior, int nueva) async {
    if (anterior < 2) await _crearHistorial(db);
    if (anterior < 3) await _crearLectura(db);
    if (anterior < 4) await _crearMisLibros(db);
  }

  /// Libros que agregaste tú (TXT, EPUB o texto pegado). Solo viven en el
  /// teléfono y no van en el respaldo (tienes el archivo original).
  static Future<void> _crearMisLibros(Database db) async {
    await db.execute('''
      CREATE TABLE mis_libros (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo     TEXT    NOT NULL,
        archivo    TEXT    NOT NULL,   -- nombre del archivo original ('' si fue texto pegado)
        formato    TEXT    NOT NULL,   -- txt | epub | texto
        nivel      INTEGER NOT NULL,   -- nivel HSK estimado (1-7; 0 = más difícil que 7-9)
        cobertura  REAL    NOT NULL,   -- fracción de caracteres conocidos en ese nivel
        caracteres INTEGER NOT NULL,   -- caracteres chinos en total
        agregado   INTEGER NOT NULL    -- segundos Unix
      )
    ''');
    await db.execute('''
      CREATE TABLE mis_capitulos (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        libro_id INTEGER NOT NULL,
        orden    INTEGER NOT NULL,
        titulo   TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mis_parrafos (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        capitulo_id INTEGER NOT NULL,
        orden       INTEGER NOT NULL,
        chino       TEXT    NOT NULL,
        pinyin      TEXT    NOT NULL   -- JSON: una sílaba por carácter
      )
    ''');
    await db.execute('CREATE INDEX idx_mis_capitulos ON mis_capitulos (libro_id, orden)');
    await db.execute('CREATE INDEX idx_mis_parrafos ON mis_parrafos (capitulo_id, orden)');
  }

  /// Capítulos de «Leer» que terminaste. Se guardan con la CLAVE del libro
  /// (no su número de fila), igual que el progreso se guarda por carácter.
  static Future<void> _crearLectura(Database db) async {
    await db.execute('''
      CREATE TABLE lectura (
        libro    TEXT    NOT NULL,   -- clave del libro (c.libros.clave)
        capitulo INTEGER NOT NULL,   -- orden del capítulo (1, 2, 3…)
        momento  INTEGER NOT NULL,   -- cuándo lo terminaste (segundos Unix)
        PRIMARY KEY (libro, capitulo)
      )
    ''');
  }

  /// Una fila por cada vez que calificas un carácter.
  static Future<void> _crearHistorial(Database db) async {
    await db.execute('''
      CREATE TABLE historial (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        caracter     TEXT    NOT NULL,
        momento      INTEGER NOT NULL,             -- segundos Unix
        duracion_ms  INTEGER NOT NULL,             -- de que apareció la tarjeta a calificarla
        calificacion INTEGER NOT NULL,             -- q de SM-2: 0 difícil, 3 medio, 5 fácil
        errores      INTEGER NOT NULL,             -- trazos fallados (incluye al revés)
        al_reves     INTEGER NOT NULL,             -- de esos, cuántos fueron al revés
        fallos       TEXT    NOT NULL DEFAULT '',  -- qué trazos: "0,3r,3" (r = al revés)
        modo_novato  INTEGER NOT NULL,             -- 1 novato, 0 experto
        nuevo        INTEGER NOT NULL,             -- 1 si era la primera vez
        intervalo    INTEGER NOT NULL              -- días hasta el siguiente repaso
      )
    ''');
    await db.execute('CREATE INDEX idx_historial_momento ON historial (momento)');
    await db.execute('CREATE INDEX idx_historial_caracter ON historial (caracter)');
  }

  static Future<String?> _leerAjuste(Database db, String clave) async {
    final filas = await db.rawQuery('SELECT valor FROM ajustes WHERE clave = ?', [clave]);
    return filas.isEmpty ? null : filas.first['valor'] as String?;
  }

  static Future<void> _guardarAjuste(Database db, String clave, String valor) =>
      db.rawInsert('INSERT OR REPLACE INTO ajustes (clave, valor) VALUES (?, ?)', [clave, valor]);

  Future<String?> leerAjuste(String clave) => _leerAjuste(db, clave);

  Future<void> guardarAjuste(String clave, String valor) => _guardarAjuste(db, clave, valor);

  Future<void> cerrar() => db.close();
}
