// ─────────────────────────────────────────────────────────────────────────────
// grabaciones.dart — Cargar una grabación (assets/audio, assets/sonidos)
//
// Las grabaciones vienen en Opus dentro de Ogg (.opus): pesan poco y Android
// las toca directo. iPhone/iPad no leen el contenedor Ogg, pero sí el mismo
// Opus dentro de CAF, el contenedor de Apple. Así que en iOS, la primera vez
// que suena cada grabación se reempaca a CAF (ogg_a_caf.dart: sin recodificar,
// misma calidad y mismo peso, en milisegundos) y se guarda en la carpeta
// temporal; las siguientes veces ya está lista.
//
// También en iOS: la sesión de audio en modo "voz" para que las
// pronunciaciones suenen aunque el interruptor de silencio esté puesto (como
// cualquier app de idiomas) y bajen un momento la música que esté sonando.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

import 'ogg_a_caf.dart';

class Grabaciones {
  Grabaciones._();

  /// En iOS las grabaciones se reempacan a CAF.
  static bool get enIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Conversiones en curso (dos botones a la vez no convierten dos veces).
  static final Map<String, Future<String>> _enCurso = {};

  /// Deja [reproductor] listo para tocar el asset [ruta] ("assets/audio/…").
  static Future<void> cargar(AudioPlayer reproductor, String ruta) async {
    if (!enIos) {
      await reproductor.setAsset(ruta);
      return;
    }
    await reproductor.setFilePath(await archivoCaf(ruta));
  }

  /// Ruta del CAF de [ruta] en la carpeta temporal (lo crea si no existe).
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
    final carpeta = Directory('${Directory.systemTemp.path}/grabaciones_caf');
    final caf = File('${carpeta.path}/${nombreCaf(ruta)}');
    // Archivos de 1-5 KB: las operaciones síncronas tardan microsegundos (y en
    // el simulador de iOS las asíncronas de esta función se quedaban sin
    // responder).
    if (caf.existsSync() && caf.lengthSync() > 0) return caf.path;
    carpeta.createSync(recursive: true);
    final datos = await rootBundle.load(ruta);
    final convertido = OggACaf.convertir(datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes));
    // Primero a un nombre provisional: si la app se cierra a la mitad, no
    // queda un CAF a medias que luego parezca bueno.
    final provisional = File('${caf.path}.tmp')..writeAsBytesSync(convertido);
    provisional.renameSync(caf.path);
    return caf.path;
  }

  /// Al arrancar la app (solo hace algo en iOS).
  static Future<void> prepararIos() async {
    if (!enIos) return;
    final sesion = await AudioSession.instance;
    await sesion.configure(const AudioSessionConfiguration.speech());
  }
}
