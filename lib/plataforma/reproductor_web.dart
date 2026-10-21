// En la web (ver reproductor.dart): las grabaciones suenan, una tras otra, en
// el reproductor que web/index.html desbloquea en el primer toque.

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Un tramo de lo que hay que tocar: una grabación ([url]) o una pausa de
/// [pausaMs] milisegundos (url null).
typedef Pista = ({String? url, int pausaMs});

@JS('meiziAudio')
external web.HTMLAudioElement? get _desbloqueado;

@JS('meiziProbarSonido')
external set _probarSonido(JSFunction? funcion);

class ReproductorWeb {
  ReproductorWeb._();

  /// El reproductor de index.html (o uno nuevo si la página no lo trae).
  static web.HTMLAudioElement get _audio => _elemento ??= _desbloqueado ?? web.HTMLAudioElement();
  static web.HTMLAudioElement? _elemento;

  /// Cada [tocar] nuevo interrumpe al anterior.
  static int _turno = 0;

  /// Lo que se está esperando ahora (que acabe una grabación o una pausa).
  static Completer<void>? _espera;

  static bool _pausado = false;
  static double _rapidez = 1;

  /// La dirección de un asset ("assets/audio/…") en el sitio.
  static String urlDeAsset(String ruta) => ui_web.assetManager.getAssetUrl(ruta);

  /// Toca [pistas] de corrido; true al terminar, false si lo interrumpieron.
  /// Si el navegador no deja sonar (o no puede leer el archivo), lanza el
  /// error para que quede en el informe de errores.
  static Future<bool> tocar(List<Pista> pistas, {double rapidez = 1, void Function(int indice)? alCambiar}) async {
    final turno = ++_turno;
    _terminarEspera();
    _pausado = false;
    _rapidez = rapidez;
    final audio = _audio;
    for (var i = 0; i < pistas.length; i++) {
      if (turno != _turno) return false;
      final pista = pistas[i];
      final url = pista.url;
      if (url == null) {
        await _pausa(pista.pausaMs, turno);
        continue;
      }
      audio.src = url;
      audio.defaultPlaybackRate = _rapidez;
      audio.playbackRate = _rapidez;
      alCambiar?.call(i);
      final fin = _esperarFin(audio);
      try {
        await audio.play().toDart;
      } catch (e) {
        _terminarEspera();
        if (turno != _turno) return false;
        throw StateError('El navegador no dejó sonar la grabación: $e');
      }
      audio.playbackRate = _rapidez; // Safari la reinicia al cambiar de archivo
      await fin;
      // Que la pausa no se confunda con el final de la grabación.
      while (_pausado && turno == _turno) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return turno == _turno;
  }

  /// Termina cuando la grabación acaba, falla o la detienen.
  static Future<void> _esperarFin(web.HTMLAudioElement audio) {
    final espera = _espera = Completer<void>();
    audio.onended = ((web.Event _) {
      if (!espera.isCompleted) espera.complete();
    }).toJS;
    audio.onerror = ((web.Event _) {
      final codigo = audio.error?.code;
      if (!espera.isCompleted) espera.completeError(StateError('El navegador no pudo leer la grabación (código $codigo)'));
    }).toJS;
    return espera.future;
  }

  static Future<void> _pausa(int ms, int turno) async {
    var restante = ms / _rapidez;
    while (restante > 0 && turno == _turno) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!_pausado) restante -= 50;
    }
  }

  static void _terminarEspera() {
    final espera = _espera;
    if (espera != null && !espera.isCompleted) espera.complete();
  }

  static void detener() {
    _turno++;
    _pausado = false;
    _elemento?.pause();
    _terminarEspera();
  }

  static void pausar() {
    _pausado = true;
    _elemento?.pause();
  }

  static void reanudar() {
    if (!_pausado) return;
    _pausado = false;
    final audio = _elemento;
    if (audio != null && audio.paused && !audio.ended && audio.src.isNotEmpty) {
      unawaited(audio.play().toDart.then((_) {}, onError: (Object _) {}));
    }
  }

  static void velocidad(double rapidez) {
    _rapidez = rapidez;
    _elemento?.playbackRate = rapidez;
  }

  /// window.meiziProbarSonido(): toca una sílaba por el camino de siempre.
  /// Lo usa la prueba automática (herramientas/capturas_web.mjs) y sirve para
  /// diagnosticar desde la consola del navegador. Devuelve true si sonó.
  static void registrarPrueba(Future<bool> Function() tocar) {
    _probarSonido = (() => tocar().then((sono) => sono.toJS).toJS).toJS;
  }
}
