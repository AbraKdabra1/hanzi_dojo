// ─────────────────────────────────────────────────────────────────────────────
// boton_voz.dart — Botón para escuchar la pronunciación
//
// Dos fuentes de sonido:
//   1. Grabaciones de hablantes nativos que trae la app (assets/audio/, ver
//      datos/audio.dart). Funcionan en cualquier teléfono, sin internet.
//   2. La voz del teléfono (texto a voz, zh-CN). Suena más natural en
//      oraciones largas, pero muchos teléfonos no la tienen (p. ej. los Huawei
//      sin Google) o falla.
//
// Regla: caracteres y palabras → grabaciones. Oraciones → voz del teléfono si
// funciona; si no, grabaciones palabra por palabra. Si no hay ninguna de las
// dos, el botón lo dice en vez de quedarse callado.
//
// Velocidad: Voz.velocidad (1.0 normal; 0.75 con «Voz lenta» en Ajustes). Los
// ejercicios tienen además un botón 🐢 para repetir algo más despacio, y Leer
// tiene su propia velocidad (0.6× a 1.5×) que se puede cambiar mientras suena.
//
// Varias grabaciones seguidas (una oración, un párrafo) se tocan como UNA lista
// de reproducción: el reproductor encadena una con otra sin huecos, y cada
// una suena sin el margen de silencio que trae a los lados
// (assets/audio/recortes.txt). Antes se cargaba y se tocaba una por una, y
// como play() regresa de inmediato si el reproductor sigue "tocando" (así se
// queda al terminar una grabación), cada palabra cortaba a la anterior.
//
// Batería: el reproductor se detiene (y suelta el decodificador) al terminar.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../datos/audio.dart';
import '../datos/registro_errores.dart';
import '../helpers/grabaciones.dart';
import '../tema.dart';
import '../idioma.dart';

enum ResultadoVoz { grabacion, vozDelTelefono, sinSonido }

/// Motor de voz compartido por toda la app.
class Voz {
  Voz._();

  static final FlutterTts _tts = FlutterTts();
  static AudioPlayer? _reproductor;
  static Future<(Set<String>, Set<String>)>? _listas;
  static Future<bool>? _ttsChino;

  /// La voz del teléfono avisó un error: en esta sesión ya no se usa.
  static bool _ttsFallo = false;

  /// Cada toque nuevo interrumpe al anterior.
  static int _turno = 0;

  /// Velocidad normal de las grabaciones (1.0; 0.75 con «Voz lenta»).
  static double velocidad = 1.0;

  /// Velocidad del botón 🐢 de los ejercicios.
  static const velocidadLenta = 0.7;

  /// Solo para las pruebas automáticas: no se intenta sonar nada (en la
  /// computadora no hay reproductor de audio).
  static bool desactivada = false;

  /// Velocidad a la que quedó configurada la voz del teléfono.
  static double _velocidadTts = 1.0;

  static AudioPlayer get _audio => _reproductor ??= AudioPlayer();

  /// Parte con voz de cada grabación (ver Audio.leerRecortes).
  static Future<Map<String, (int, int)>>? _recortes;

  static Future<Map<String, (int, int)>> _cargarRecortes() => _recortes ??= rootBundle
      .loadString('assets/audio/recortes.txt')
      .then(Audio.leerRecortes)
      .catchError((Object _) => <String, (int, int)>{});

  /// Para las pausas de la puntuación dentro de una lista de reproducción.
  static const _silencio = 'assets/sonidos/silencio.opus';

  /// Palabras y sílabas grabadas: (palabras, sílabas).
  static Future<(Set<String>, Set<String>)> listas() => _cargarListas();

  /// Palabras y sílabas grabadas (se leen una sola vez).
  static Future<(Set<String>, Set<String>)> _cargarListas() => _listas ??= () async {
        Set<String> leer(String texto) => {
              for (final l in texto.split('\n'))
                if (l.trim().isNotEmpty) l.trim(),
            };
        final palabras = leer(await rootBundle.loadString('assets/audio/palabras.txt'));
        final silabas = leer(await rootBundle.loadString('assets/audio/silabas.txt'));
        return (palabras, silabas);
      }();

  /// ¿El teléfono tiene voz en chino que funcione?
  static Future<bool> _hayVozChina() async {
    if (_ttsFallo) return false;
    return _ttsChino ??= () async {
      try {
        _tts.setErrorHandler((mensaje) {
          _ttsFallo = true;
          debugPrint('Voz del teléfono: $mensaje');
        });
        final disponible = await _tts.isLanguageAvailable('zh-CN');
        if (disponible != true) return false;
        if (Grabaciones.enIos) {
          // Que suene aunque el interruptor de silencio esté puesto.
          await _tts.setSharedInstance(true);
          await _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [IosTextToSpeechAudioCategoryOptions.duckOthers],
            IosTextToSpeechAudioMode.spokenAudio,
          );
        }
        final listo = await _tts.setLanguage('zh-CN');
        await _tts.setSpeechRate(0.42); // un poco más lento que lo normal
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        return listo == 1 || listo == true;
      } catch (e, pila) {
        RegistroErrores.registrar('Voz del teléfono', e, pila);
        return false;
      }
    }();
  }

  /// Pronuncia [texto]. [pinyin] (opcional) trae una sílaba por runa y
  /// sirve para leer bien los caracteres de varias lecturas (长 de 长大).
  /// Termina cuando acaba de sonar (con grabaciones) o en cuanto empieza
  /// (con la voz del teléfono).
  ///
  /// [pinyinPorPalabras] es la alternativa cuando el pinyin viene escrito por
  /// palabras ('wǒ xǐhuan…', como en las oraciones de ejemplo).
  static Future<ResultadoVoz> decir(String texto,
      {List<String>? pinyin, String? pinyinPorPalabras, double? rapidez}) async {
    if (desactivada) return ResultadoVoz.sinSonido;
    final v = rapidez ?? velocidad;
    final turno = ++_turno;
    await _detenerSonido();
    try {
      final (palabras, silabas) = await _cargarListas();
      final alineado = pinyin ??
          (pinyinPorPalabras == null ? null : Audio.alinearPinyin(texto, pinyinPorPalabras, silabas));
      final plan = Audio.planDeLectura(texto, pinyin: alineado, palabras: palabras, silabas: silabas);
      final esOracion = plan.grabaciones > 2;
      final grabacionCompleta = plan.completo && !esOracion;

      if (!grabacionCompleta && await _hayVozChina()) {
        if (turno != _turno) return ResultadoVoz.vozDelTelefono;
        if (_velocidadTts != v) {
          await _tts.setSpeechRate(0.42 * v);
          _velocidadTts = v;
        }
        final r = await _tts.speak(texto);
        if (r == 1 || r == true) return ResultadoVoz.vozDelTelefono;
        _ttsFallo = true;
      }
      if (plan.grabaciones == 0) return ResultadoVoz.sinSonido;
      await _tocar(plan.clips, turno, v);
      return ResultadoVoz.grabacion;
    } catch (e, pila) {
      debugPrint('Voz: no se pudo leer "$texto": $e');
      RegistroErrores.registrar('Voz', e, pila);
      return ResultadoVoz.sinSonido;
    }
  }

  /// Lee [texto] solo con grabaciones (no con la voz del teléfono: de ella
  /// no se sabe qué palabra suena) y avisa con [alSonar] qué runas
  /// [inicio, fin) suenan en cada momento; al terminar avisa (-1, -1).
  /// Devuelve false si se interrumpió (otro sonido, detener()).
  static Future<bool> leerResaltando(
    String texto, {
    List<String>? pinyin,
    required void Function(int inicio, int fin) alSonar,
    double? rapidez,
  }) async {
    if (desactivada) return false;
    final turno = ++_turno;
    await _detenerSonido();
    try {
      final (palabras, silabas) = await _cargarListas();
      final plan = Audio.planDeLectura(texto, pinyin: pinyin, palabras: palabras, silabas: silabas);
      return await _reproducir(plan.clips, turno, rapidez ?? velocidad, alCambiar: (k) {
        final clip = plan.clips[k];
        if (!clip.esPausa) alSonar(clip.inicio, clip.fin);
      });
    } catch (e, pila) {
      RegistroErrores.registrar('Voz (leer en voz alta)', e, pila);
      return false;
    } finally {
      alSonar(-1, -1);
    }
  }

  /// Pausa lo que suena (la lectura en voz alta sigue donde iba con
  /// [reanudar]).
  static Future<void> pausar() async {
    await _reproductor?.pause();
  }

  static void reanudar() {
    final audio = _reproductor;
    if (audio != null && !audio.playing) unawaited(audio.play().catchError((Object _) {}));
  }

  /// Cambia la velocidad de lo que está sonando, sin cortarlo.
  static Future<void> cambiarVelocidad(double rapidez) async {
    await _reproductor?.setSpeed(rapidez);
  }

  /// Toca exactamente estas grabaciones (los ejercicios: una sílaba o una
  /// palabra concreta, sin pasar por la voz del teléfono). false si falló.
  static Future<bool> tocar(List<Clip> clips, {double? rapidez}) async {
    if (desactivada) return false;
    final turno = ++_turno;
    await _detenerSonido();
    try {
      await _tocar(clips, turno, rapidez ?? velocidad);
      return true;
    } catch (e, pila) {
      RegistroErrores.registrar('Voz', e, pila);
      return false;
    }
  }

  static Future<void> _tocar(List<Clip> clips, int turno, double rapidez) async {
    await _reproducir(clips, turno, rapidez);
  }

  /// Toca [clips] de corrido y termina cuando acaban de sonar (true) o si
  /// algo lo interrumpe (false). [alCambiar] avisa qué clip empieza.
  ///
  /// Una sola grabación suena completa; varias se recortan a su parte con
  /// voz para que la lectura no suene entrecortada.
  static Future<bool> _reproducir(List<Clip> clips, int turno, double rapidez,
      {void Function(int indice)? alCambiar}) async {
    final grabaciones = clips.where((c) => !c.esPausa).length;
    if (grabaciones == 0) return true;
    final audio = _audio;
    StreamSubscription<int?>? avisos;
    try {
      try {
        final fuentes = await _fuentes(clips, recortar: grabaciones > 1);
        if (turno != _turno) return false;
        await audio.stop(); // play() no hace nada si el reproductor sigue "tocando"
        await audio.setSpeed(rapidez);
        await audio.setAudioSources(fuentes);
      } catch (e, pila) {
        if (turno != _turno) return false; // la interrumpió otro sonido
        // Si la lista no se pudo armar (un formato que este teléfono no
        // recorta, por ejemplo), una por una.
        RegistroErrores.registrar('Voz (lista de reproducción)', e, pila);
        return await _reproducirUnaPorUna(clips, turno, rapidez, alCambiar: alCambiar);
      }
      if (turno != _turno) return false;
      if (alCambiar != null) {
        avisos = audio.currentIndexStream.distinct().listen((k) {
          if (k != null && k < clips.length && turno == _turno) alCambiar(k);
        });
      }
      await _tocarHastaElFinal(audio);
      return turno == _turno;
    } finally {
      await avisos?.cancel();
      // Al terminar se suelta el decodificador (ahorra batería y memoria).
      if (turno == _turno) await audio.stop();
    }
  }

  /// Plan B de [_reproducir]: cada grabación por separado.
  static Future<bool> _reproducirUnaPorUna(List<Clip> clips, int turno, double rapidez,
      {void Function(int indice)? alCambiar}) async {
    final audio = _audio;
    await audio.setSpeed(rapidez);
    for (var k = 0; k < clips.length; k++) {
      if (turno != _turno) return false;
      final clip = clips[k];
      if (clip.esPausa) {
        await Future<void>.delayed(Duration(milliseconds: (clip.pausaMs / rapidez).round()));
        continue;
      }
      await audio.stop();
      await Grabaciones.cargar(audio, clip.ruta);
      if (turno != _turno) return false;
      alCambiar?.call(k);
      await _tocarHastaElFinal(audio);
    }
    return turno == _turno;
  }

  /// Toca lo cargado y espera a que termine o a que lo detengan (una pausa
  /// sigue esperando: [reanudar] continúa).
  static Future<void> _tocarHastaElFinal(AudioPlayer audio) async {
    final fin = audio.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed || s == ProcessingState.idle);
    unawaited(audio.play().catchError((Object _) {}));
    await fin;
  }

  /// [clips] como fuentes para una lista de reproducción. Las pausas son un
  /// trozo de silencio de la duración pedida.
  static Future<List<AudioSource>> _fuentes(List<Clip> clips, {required bool recortar}) async {
    final recortes = recortar ? await _cargarRecortes() : const <String, (int, int)>{};
    final fuentes = <AudioSource>[];
    for (final clip in clips) {
      if (clip.esPausa) {
        // Cada pausa con su propia fuente: una misma no puede estar dos
        // veces en la lista.
        fuentes.add(ClippingAudioSource(
          child: await Grabaciones.fuente(_silencio),
          end: Duration(milliseconds: clip.pausaMs.clamp(1, 1000)),
        ));
        continue;
      }
      final fuente = await Grabaciones.fuente(clip.ruta);
      final recorte = recortes[clip.claveRecorte];
      fuentes.add(recorte == null
          ? fuente
          : ClippingAudioSource(
              child: fuente,
              start: Duration(milliseconds: recorte.$1),
              end: Duration(milliseconds: recorte.$2),
            ));
    }
    return fuentes;
  }

  static Future<void> _detenerSonido() async {
    await _reproductor?.stop();
    if (_ttsChino != null) await _tts.stop();
  }

  /// Calla lo que esté sonando (al salir de una pantalla, por ejemplo).
  static Future<void> detener() async {
    _turno++;
    await _detenerSonido();
  }
}

class BotonVoz extends StatefulWidget {
  const BotonVoz({super.key, required this.texto, this.pinyin, this.pinyinPorPalabras, this.tamano = 20, this.rapidez});

  /// Texto en chino que se va a leer.
  final String texto;

  /// Una sílaba de pinyin por carácter de [texto] (opcional): con ella cada
  /// carácter suelto se lee con su lectura en ESE texto.
  final List<String>? pinyin;

  /// Alternativa a [pinyin] cuando viene escrito por palabras ('wǒ xǐhuan…').
  final String? pinyinPorPalabras;
  final double tamano;

  /// Velocidad (null = la de Ajustes). Leer usa la suya.
  final double? rapidez;

  @override
  State<BotonVoz> createState() => _BotonVozState();
}

class _BotonVozState extends State<BotonVoz> {
  bool _activo = false;

  /// [lento]: mantener presionado el botón lo repite más despacio.
  Future<void> _hablar({bool lento = false}) async {
    setState(() => _activo = true);
    final inicio = DateTime.now();
    final resultado = await Voz.decir(widget.texto,
        pinyin: widget.pinyin,
        pinyinPorPalabras: widget.pinyinPorPalabras,
        rapidez: lento ? Voz.velocidadLenta : widget.rapidez);
    if (resultado == ResultadoVoz.sinSonido && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(tr('No hay grabación de esto y tu teléfono no tiene voz en chino. Puedes instalar una en Ajustes del teléfono › Texto a voz.')),
      ));
    }
    // El resaltado dura al menos un momento (la voz del teléfono no avisa
    // de forma confiable cuándo termina).
    final transcurrido = DateTime.now().difference(inicio);
    const minimo = Duration(milliseconds: 900);
    if (transcurrido < minimo) await Future<void>.delayed(minimo - transcurrido);
    if (mounted) setState(() => _activo = false);
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF007AFF);
    final c = context.colores;
    return Semantics(
      button: true,
      label: tr('Escuchar pronunciación (mantén presionado para oírla lento)'),
      child: GestureDetector(
        onTap: _hablar,
        onLongPress: () => _hablar(lento: true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 38,
          decoration: BoxDecoration(
            color: _activo ? const Color(0x22007AFF) : c.separador,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _activo ? const Color(0x55007AFF) : c.bordeTarjeta,
              width: 1.2,
            ),
          ),
          child: Icon(
            _activo ? Icons.volume_up_rounded : Icons.volume_up_outlined,
            color: _activo ? azul : c.icono,
            size: widget.tamano,
          ),
        ),
      ),
    );
  }
}
