// ─────────────────────────────────────────────────────────────────────────────
// navegador.dart — Lo que en la versión web hace el navegador
//
// En el teléfono estas cosas las hace el sistema (MainActivity.kt,
// AppDelegate.swift); en la web, el navegador:
//   guardar        descarga el archivo
//   abrir          el selector de archivos del navegador
//   abrirEnlace    una pestaña nueva
//   compartir      el menú Compartir del teléfono (Web Share) o, si no hay,
//                  descarga la imagen
//   oggOpus        ¿puede tocar Opus en Ogg? (Safari y todos los navegadores
//                  de iPhone no: ahí las grabaciones se reempacan a CAF)
//   urlDeBytes     una dirección blob: para tocar audio desde memoria
// Fuera de la web (navegador_stub.dart) nada de esto se usa.
// ─────────────────────────────────────────────────────────────────────────────

export 'navegador_stub.dart' if (dart.library.js_interop) 'navegador_web.dart';
