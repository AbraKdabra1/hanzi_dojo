// ─────────────────────────────────────────────────────────────────────────────
// base_web.dart — Preparar sqflite según la plataforma
//
// En el teléfono sqflite usa el SQLite del sistema y no hay nada que hacer.
// En la web usa SQLite compilado a WebAssembly (web/sqlite3.wasm) y guarda
// las bases en IndexedDB.
// ─────────────────────────────────────────────────────────────────────────────

export 'base_web_stub.dart' if (dart.library.js_interop) 'base_web_real.dart';
