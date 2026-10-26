// ─────────────────────────────────────────────────────────────────────────────
// cache_caf.dart — Dónde quedan las grabaciones reempacadas a CAF
//
// iPhone/iPad (cache_caf_io.dart): un archivo en la carpeta temporal de la app.
// Web en Safari (cache_caf_web.dart): una dirección blob: en memoria.
// Ver helpers/grabaciones.dart.
// ─────────────────────────────────────────────────────────────────────────────

export 'cache_caf_io.dart' if (dart.library.js_interop) 'cache_caf_web.dart';
