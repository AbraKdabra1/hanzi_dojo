// ─────────────────────────────────────────────────────────────────────────────
// almacen.dart — Archivos propios de la app
//
// La base de contenido, el registro de errores y la copia previa a una
// importación. En el teléfono son archivos normales (almacen_io.dart); en la
// versión web viven en la base del navegador (IndexedDB) a través del mismo
// sqflite que guarda el progreso (almacen_web.dart).
// ─────────────────────────────────────────────────────────────────────────────

export 'almacen_io.dart' if (dart.library.js_interop) 'almacen_web.dart';
