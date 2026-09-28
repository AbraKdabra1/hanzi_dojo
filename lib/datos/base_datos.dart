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
//   progreso.db   Tu avance (repaso espaciado) y tus ajustes. Se crea vacío y
//                 solo lo modifica la app. Como el progreso se guarda por
//                 CARÁCTER (no por número de fila), al actualizar el
//                 contenido no se pierde nada.
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
  BaseDatos._(this.db);

  /// Conexión principal (progreso.db con contenido.db adjunta como `c`).
  final Database db;

  static const _archivoContenido = 'contenido.db';
  static const _archivoProgreso = 'progreso.db';
  static const _versionEsquemaProgreso = 1;

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
    );

    // 2. ¿Hay que copiar (o reemplazar) la base de contenido?
    final rutaContenido = p.join(dir, _archivoContenido);
    final versionLocal = await _leerAjuste(db, 'version_contenido');
    if (versionLocal != versionEsperada || !await File(rutaContenido).exists()) {
      await _copiarContenido(rutaContenido, cargarContenido);
      await _guardarAjuste(db, 'version_contenido', versionEsperada);
    }

    // 3. Adjuntar el contenido con el alias `c`.
    await db.execute('ATTACH DATABASE ? AS c', [rutaContenido]);
    return BaseDatos._(db);
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

  /// Tablas de progreso.db.
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
