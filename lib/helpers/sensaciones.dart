// ─────────────────────────────────────────────────────────────────────────────
// sensaciones.dart — Vibración y sonido al escribir
//
//   · Trazo correcto: un toque de vibración muy corto y, si lo activaste, el
//     roce de un pincel sobre el papel (assets/sonidos/pincel.opus, sintetizado
//     para la app).
//   · Trazo equivocado: una vibración un poco más marcada.
//   · Carácter terminado: un toque doble suave.
// Las dos cosas se apagan en Ajustes (la vibración viene encendida; el sonido,
// apagado). El reproductor del pincel es aparte del de la voz, así que un
// trazo no interrumpe una pronunciación.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../datos/registro_errores.dart';

class Sensaciones {
  Sensaciones._();

  /// Vibrar al trazar (Ajustes).
  static bool vibracion = true;

  /// Sonido de pincel al acertar un trazo (Ajustes).
  static bool sonidoPincel = false;

  /// Solo para las pruebas automáticas (no hay reproductor en la computadora).
  static bool desactivadas = false;

  static AudioPlayer? _pincel;
  static Future<void>? _cargando;

  static Future<void> _prepararPincel() => _cargando ??= () async {
        final p = _pincel = AudioPlayer();
        await p.setAsset('assets/sonidos/pincel.opus');
        await p.setVolume(0.7);
      }();

  static Future<void> trazoBien() async {
    if (desactivadas) return;
    if (vibracion) HapticFeedback.lightImpact();
    if (!sonidoPincel) return;
    try {
      await _prepararPincel();
      final p = _pincel!;
      await p.seek(Duration.zero);
      p.play(); // no se espera: el siguiente trazo puede empezar ya
    } catch (e, pila) {
      RegistroErrores.registrar('Sonido de pincel', e, pila);
      sonidoPincel = false; // que no vuelva a intentarlo en esta sesión
    }
  }

  static void trazoMal() {
    if (desactivadas || !vibracion) return;
    HapticFeedback.mediumImpact();
  }

  static Future<void> caracterCompleto() async {
    if (desactivadas || !vibracion) return;
    HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    HapticFeedback.selectionClick();
  }

  /// Suelta el reproductor del pincel (al apagar el sonido en Ajustes).
  static Future<void> soltar() async {
    final p = _pincel;
    _pincel = null;
    _cargando = null;
    await p?.dispose();
  }
}
