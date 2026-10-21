// ─────────────────────────────────────────────────────────────────────────────
// reproductor.dart — Cómo suenan las grabaciones en la versión web
//
// En el teléfono las toca just_audio. En la web (sobre todo en Safari de
// iPhone/iPad) el audio solo puede empezar dentro de un toque, y la app tarda
// un momento en preparar cada grabación (cargarla y, en Safari, reempacarla a
// CAF): para cuando la mandaba a sonar, Safari ya la bloqueaba en silencio.
//
// Por eso web/index.html crea UN reproductor (window.meiziAudio) y lo
// «desbloquea» en el primer toque en cualquier parte de la app; después ese
// mismo reproductor puede sonar sin un toque de por medio, y todas las
// grabaciones pasan por él (reproductor_web.dart). Fuera de la web
// (reproductor_stub.dart) no se usa.
// ─────────────────────────────────────────────────────────────────────────────

export 'reproductor_stub.dart' if (dart.library.js_interop) 'reproductor_web.dart';
