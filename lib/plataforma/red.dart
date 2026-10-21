// ─────────────────────────────────────────────────────────────────────────────
// red.dart — Pedir un texto a internet (solo el aviso de versión nueva)
//
// En el teléfono se usa el HttpClient de Dart (red_io.dart). En la web no hace
// falta: la versión web se actualiza sola al abrirla (red_web.dart no hace
// nada).
// ─────────────────────────────────────────────────────────────────────────────

export 'red_io.dart' if (dart.library.js_interop) 'red_web.dart';
