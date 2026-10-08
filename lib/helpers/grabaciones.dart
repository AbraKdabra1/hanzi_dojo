// ─────────────────────────────────────────────────────────────────────────────
// grabaciones.dart — Cargar una grabación (assets/audio, assets/sonidos)
//
// Las grabaciones vienen en Opus dentro de Ogg (.opus): pesan poco y Android
// las toca directo. iPhone/iPad no leen el contenedor Ogg, pero sí el mismo
// Opus dentro de CAF, el contenedor de Apple. Así que en iOS, la primera vez
// que suena cada grabación se reempaca a CAF (ogg_a_caf.dart: sin recodificar,
// misma calidad y mismo peso, en milisegundos) y se guarda (plataforma/
// cache_caf.dart); las siguientes veces ya está lista. Lo mismo en la versión
// web cuando el navegador no lee Ogg (Safari y los navegadores de iPhone).
//
// También en iOS: la sesión de audio en modo "voz" para que las
// pronunciaciones suenen aunque el interruptor de silencio esté puesto (como
// cualquier app de idiomas) y bajen un momento la música que esté sonando.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

import '../plataforma/cache_caf.dart';
import '../plataforma/navegador.dart';
import 'ogg_a_caf.dart';

class Grabaciones {
  Grabaciones._();

  /// iPhone/iPad (la app).
  static bool get enIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// ¿Hay que reempacar a CAF? En iOS siempre; en la web, si el navegador no
  /// toca Opus en Ogg (Safari y cualquier navegador de iPhone).
  static bool get necesitaCaf => enIos || (kIsWeb && !Navegador.oggOpus);

  /// Conversiones en curso (dos botones a la vez no convierten dos veces).
  static final Map<String, Future<String>> _enCurso = {};

  /// Deja [reproductor] listo para tocar el asset [ruta] ("assets/audio/…").
  static Future<void> cargar(AudioPlayer reproductor, String ruta) async {
    await reproductor.setAudioSource(await fuente(ruta));
  }

  /// El asset [ruta] como fuente para el reproductor (por ejemplo, para
  /// armar una lista que suene de corrido): el Opus tal cual o, donde hace
  /// falta, ya reempacado a CAF.
  static Future<UriAudioSource> fuente(String ruta) async {
    if (!necesitaCaf) return AudioSource.asset(ruta);
    final caf = await archivoCaf(ruta);
    return CacheCaf.esArchivo ? AudioSource.file(caf) : AudioSource.uri(Uri.parse(caf));
  }

  /// El CAF de [ruta]: una ruta de archivo (iOS) o una dirección blob: (web).
  static Future<String> archivoCaf(String ruta) => _enCurso[ruta] ??= _convertir(ruta).whenComplete(() {
        // Con llaves a propósito: "() => _enCurso.remove(ruta)" devolvería la
        // propia conversión y whenComplete se quedaría esperándose a sí mismo.
        _enCurso.remove(ruta);
      });

  /// "assets/audio/silabas/ma1.opus" → "audio_silabas_ma1.caf".
  @visibleForTesting
  static String nombreCaf(String ruta) =>
      '${ruta.replaceFirst(RegExp(r'^assets/'), '').replaceAll('/', '_').replaceFirst(RegExp(r'\.opus$'), '')}.caf';

  static Future<String> _convertir(String ruta) async {
    final nombre = nombreCaf(ruta);
    final listo = CacheCaf.buscar(nombre);
    if (listo != null) return listo;
    final datos = await rootBundle.load(ruta);
    return CacheCaf.guardar(nombre, OggACaf.convertir(datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes)));
  }

  /// Al arrancar la app (solo hace algo en iOS).
  static Future<void> prepararIos() async {
    if (!enIos) return;
    final sesion = await AudioSession.instance;
    await sesion.configure(const AudioSessionConfiguration.speech());
  }
}
