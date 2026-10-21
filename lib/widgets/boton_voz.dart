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
// Leer en voz alta (Leer, párrafo por párrafo): con la voz del teléfono si
// tiene chino y [Voz.leerConVozDelTelefono] está activo (Ajustes; suena
// natural, de corrido), resaltando lo que dice si el motor lo informa; si no,
// con las grabaciones. Pausa, velocidad y detener funcionan con las dos.
//
// Velocidad: Voz.velocidad (1.0 normal; 0.75 con «Voz lenta» en Ajustes). Los
// ejercicios tienen además un botón 🐢 para repetir algo más despacio, y Leer
// tiene su propia velocidad (0.6× a 1.5×) que se puede cambiar mientras suena.
//
// Varias grabaciones seguidas (una oración, un párrafo) se tocan como UNA lista
// de reproducción: el reproductor encadena una con otra. Las grabaciones ya
// vienen recortadas con un margen corto y fundidos suaves (preparar_audio.py),
// así que entre palabra y palabra queda una pausa mínima natural y sin
// chasquidos. Los caracteres sueltos suenan con su propia grabación cuando se
// puede (assets/audio/lecturas.txt): así no se salta de una voz a otra.
//
// Márgenes (en la app): cada reproducción empieza con un silencio corto y
// termina con otro. Muchos teléfonos tardan un instante en «despertar» la
// bocina y se comían el inicio de la grabación, y algunos (varios Huawei) dan
// por terminado el audio un poco antes de tiempo y cortaban el final.
//
// En la web, las grabaciones suenan en el reproductor que index.html
// desbloquea en el primer toque (plataforma/reproductor.dart): Safari de
// iPhone no deja empezar un audio fuera de un toque.
//
// Batería: el reproductor se detiene (y suelta el decodificador) al terminar.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../datos/audio.dart';
import '../datos/registro_errores.dart';
import '../helpers/grabaciones.dart';
import '../plataforma/reproductor.dart';
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

  /// Leer en voz alta con la voz del teléfono cuando tenga chino (Ajustes ›
  /// Práctica con audio). Si es false, o si no tiene, con las grabaciones.
  static bool leerConVozDelTelefono = true;

  // Estado de la lectura con la voz del teléfono (ver _leerConTelefono).
  static bool _leyendoConTelefono = false;
  static bool _telefonoPausado = false;
  static bool _telefonoReiniciar = false;
  static double _rapidezLectura = 1.0;
  static Completer<void>? _finFrase;
  static DateTime _inicioFrase = DateTime(2000);

  /// El motor avisó que empezó a hablar la frase actual.
  static bool _arrancoFrase = false;

  /// La voz del teléfono no avisa cuándo empieza ni cuándo termina (pasa en
  /// algunos motores y en el simulador de iPhone): sin esos avisos no se
  /// puede leer de corrido, así que Leer usa las grabaciones en esta sesión.
  static bool _lecturaSinAvisos = false;

  /// Velocidad normal de la voz del teléfono con este motor (Android y iOS
  /// cuentan distinto; 0.42 se oye un poco más lento que lo normal).
  static const _tasaTts = 0.42;

  static AudioPlayer get _audio => _reproductor ??= AudioPlayer();

  /// Caracteres con grabación propia y su sílaba (ver Audio.leerLecturas).
  static Future<Map<String, String>>? _lecturas;

  static Future<Map<String, String>> _cargarLecturas() => _lecturas ??= rootBundle
      .loadString('assets/audio/lecturas.txt')
      .then(Audio.leerLecturas)
      .catchError((Object _) => <String, String>{});

  /// Para las pausas de la puntuación dentro de una lista de reproducción.
  static const _silencio = 'assets/sonidos/silencio.opus';

  /// Silencio antes y después de cada reproducción en la app (ver arriba).
  static const margenAntesMs = 150;
  static const margenDespuesMs = 250;

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

  /// ¿El teléfono tiene voz en chino que funcione? (Ajustes lo muestra.)
  static Future<bool> hayVozChina() => desactivada ? Future.value(false) : _hayVozChina();

  static void _terminoFrase() {
    final fin = _finFrase;
    // El aviso de que se detuvo la frase ANTERIOR puede llegar tarde, cuando
    // la nueva ya empezó: lo que llega en los primeros instantes se ignora
    // (ninguna frase de verdad dura tan poco).
    if (DateTime.now().difference(_inicioFrase) < const Duration(milliseconds: 180)) return;
    if (fin != null && !fin.isCompleted) fin.complete();
  }

  static Future<bool> _hayVozChina() async {
    if (_ttsFallo) return false;
    return _ttsChino ??= () async {
      try {
        _tts.setErrorHandler((mensaje) {
          _ttsFallo = true;
          debugPrint('Voz del teléfono: $mensaje');
          final fin = _finFrase;
          if (fin != null && !fin.isCompleted) fin.complete();
        });
        _tts.setCompletionHandler(_terminoFrase);
        _tts.setCancelHandler(_terminoFrase);
        _tts.setStartHandler(() => _arrancoFrase = true);
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
        await _tts.setSpeechRate(_tasaTts);
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
      final plan = Audio.planDeLectura(texto,
          pinyin: alineado, palabras: palabras, silabas: silabas, lecturas: await _cargarLecturas());
      final esOracion = plan.grabaciones > 2;
      final grabacionCompleta = plan.completo && !esOracion;

      if (!grabacionCompleta && await _hayVozChina()) {
        if (turno != _turno) return ResultadoVoz.vozDelTelefono;
        await _velocidadTelefono(v);
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

  static Future<void> _velocidadTelefono(double rapidez) async {
    if (_velocidadTts == rapidez) return;
    await _tts.setSpeechRate(_tasaTts * rapidez);
    _velocidadTts = rapidez;
  }

  /// Lee en voz alta [texto] (un párrafo) y avisa con [alSonar] qué runas
  /// [inicio, fin) suenan en cada momento; al terminar avisa (-1, -1).
  /// Con la voz del teléfono si la hay y está activa (ver
  /// [leerConVozDelTelefono]); si no, con las grabaciones. Devuelve false si
  /// se interrumpió (otro sonido, detener()).
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
      if (leerConVozDelTelefono && !_lecturaSinAvisos && await _hayVozChina() && turno == _turno) {
        final leido = await _leerConTelefono(texto, turno, rapidez ?? velocidad, alSonar);
        if (leido != null) return leido;
        // No arrancó: con las grabaciones.
      }
      final (palabras, silabas) = await _cargarListas();
      final plan = Audio.planDeLectura(texto,
          pinyin: pinyin, palabras: palabras, silabas: silabas, lecturas: await _cargarLecturas());
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

  /// Lee [texto] con la voz del teléfono. true al terminar, false si lo
  /// interrumpieron, null si no pudo empezar (se lee con grabaciones).
  ///
  /// La voz del teléfono no tiene "pausa" en todos los motores: pausar la
  /// detiene y reanudar vuelve a empezar desde la palabra que iba. Igual al
  /// cambiar la velocidad.
  static Future<bool?> _leerConTelefono(
      String texto, int turno, double rapidez, void Function(int, int) alSonar) async {
    // Posición en UTF-16 (como la informa el motor) → posición en runas.
    final runaDe = <int>[];
    var runa = 0;
    for (final r in texto.runes) {
      runaDe.add(runa);
      if (r > 0xFFFF) runaDe.add(runa);
      runa++;
    }
    runaDe.add(runa);
    int aRuna(int i) => runaDe[i.clamp(0, runaDe.length - 1)];

    var desde = 0; // dónde empieza lo que se le pide decir
    var ultimo = 0; // dónde empieza la palabra que va diciendo
    _leyendoConTelefono = true;
    _telefonoPausado = false;
    _telefonoReiniciar = false;
    _rapidezLectura = rapidez;
    var sono = false;
    _tts.setProgressHandler((frase, inicio, fin, palabra) {
      if (turno != _turno || !_leyendoConTelefono) return;
      sono = true;
      ultimo = desde + inicio;
      alSonar(aRuna(desde + inicio), aRuna(desde + fin));
    });
    try {
      var primera = true;
      while (turno == _turno) {
        await _velocidadTelefono(_rapidezLectura);
        final resto = texto.substring(desde);
        if (resto.trim().isEmpty) return true;
        final fin = _finFrase = Completer<void>();
        _inicioFrase = DateTime.now();
        _arrancoFrase = false;
        final r = await _tts.speak(resto);
        if (r != 1 && r != true) {
          _ttsFallo = true;
          return primera ? null : false;
        }
        // Si en unos segundos no avisa ni que empezó, este motor no sirve para
        // leer de corrido (no se sabría cuándo seguir): con las grabaciones.
        final avisoATiempo = await Future.any([
          fin.future.then((_) => true),
          Future<bool>.delayed(const Duration(seconds: 3), () => false),
        ]);
        if (!avisoATiempo && !_arrancoFrase && !sono && turno == _turno && !_telefonoPausado) {
          _lecturaSinAvisos = true;
          await _tts.stop();
          return primera ? null : false;
        }
        // Termina (o lo detienen); por si el motor no avisa, un tope generoso.
        final tope = Duration(milliseconds: 4000 + (resto.length * 700 / _rapidezLectura).round());
        await fin.future.timeout(tope, onTimeout: () {});
        if (turno != _turno) return false;
        if (_ttsFallo) return primera && !sono ? null : false;
        primera = false;
        if (_telefonoPausado) {
          while (_telefonoPausado && turno == _turno) {
            await Future<void>.delayed(const Duration(milliseconds: 120));
          }
          desde = ultimo;
          continue;
        }
        if (_telefonoReiniciar) {
          _telefonoReiniciar = false;
          desde = ultimo;
          continue;
        }
        return true;
      }
      return false;
    } finally {
      _leyendoConTelefono = false;
      _telefonoPausado = false;
      _finFrase = null;
      _tts.setProgressHandler((frase, inicio, fin, palabra) {});
    }
  }

  /// Pausa lo que suena (la lectura en voz alta sigue donde iba con
  /// [reanudar]).
  static Future<void> pausar() async {
    if (_leyendoConTelefono) {
      _telefonoPausado = true;
      await _tts.stop();
      return;
    }
    if (kIsWeb) {
      ReproductorWeb.pausar();
      return;
    }
    await _reproductor?.pause();
  }

  static void reanudar() {
    if (_leyendoConTelefono) {
      _telefonoPausado = false;
      return;
    }
    if (kIsWeb) {
      ReproductorWeb.reanudar();
      return;
    }
    final audio = _reproductor;
    if (audio != null && !audio.playing) unawaited(audio.play().catchError((Object _) {}));
  }

  /// Cambia la velocidad de lo que está sonando (la voz del teléfono vuelve a
  /// empezar desde la palabra que iba, ya con la nueva velocidad).
  static Future<void> cambiarVelocidad(double rapidez) async {
    if (_leyendoConTelefono) {
      _rapidezLectura = rapidez;
      if (!_telefonoPausado) {
        _telefonoReiniciar = true;
        await _tts.stop();
      }
      return;
    }
    if (kIsWeb) {
      ReproductorWeb.velocidad(rapidez);
      return;
    }
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
  static Future<bool> _reproducir(List<Clip> clips, int turno, double rapidez,
      {void Function(int indice)? alCambiar}) async {
    final grabaciones = clips.where((c) => !c.esPausa).length;
    if (grabaciones == 0) return true;
    if (kIsWeb) return _reproducirWeb(clips, turno, rapidez, alCambiar: alCambiar);
    final audio = _audio;
    StreamSubscription<int?>? avisos;
    try {
      try {
        // Con un silencio antes y otro después (ver «Márgenes» arriba): el
        // índice k de la lista es el clip k - 1.
        final fuentes = [
          await _pausa(margenAntesMs),
          ...await _fuentes(clips),
          await _pausa(margenDespuesMs),
        ];
        if (turno != _turno) return false;
        await audio.stop(); // play() no hace nada si el reproductor sigue "tocando"
        await audio.setSpeed(rapidez);
        await audio.setAudioSources(fuentes);
      } catch (e, pila) {
        if (turno != _turno) return false; // la interrumpió otro sonido
        // Si la lista no se pudo armar, una por una.
        RegistroErrores.registrar('Voz (lista de reproducción)', e, pila);
        return await _reproducirUnaPorUna(clips, turno, rapidez, alCambiar: alCambiar);
      }
      if (turno != _turno) return false;
      if (alCambiar != null) {
        avisos = audio.currentIndexStream.distinct().listen((k) {
          final clip = k == null ? -1 : k - 1;
          if (clip >= 0 && clip < clips.length && turno == _turno) alCambiar(clip);
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

  /// En la web: [clips] en el reproductor desbloqueado (ver
  /// plataforma/reproductor.dart). Si el navegador no deja sonar, lanza el
  /// error (queda en el informe de errores).
  static Future<bool> _reproducirWeb(List<Clip> clips, int turno, double rapidez,
      {void Function(int indice)? alCambiar}) async {
    final pistas = <Pista>[
      for (final clip in clips)
        clip.esPausa ? (url: null, pausaMs: clip.pausaMs) : (url: await Grabaciones.urlWeb(clip.ruta), pausaMs: 0),
    ];
    if (turno != _turno) return false;
    final sono = await ReproductorWeb.tocar(pistas, rapidez: rapidez, alCambiar: (k) {
      if (turno == _turno) alCambiar?.call(k);
    });
    return sono && turno == _turno;
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
    unawaited(audio.play().catchError((Object e, StackTrace pila) {
      // Antes se callaba: así queda en el informe de errores.
      RegistroErrores.registrar('Voz (reproducir)', e, pila);
    }));
    await fin;
  }

  /// [clips] como fuentes para una lista de reproducción. Las pausas son un
  /// trozo de silencio de la duración pedida.
  static Future<List<AudioSource>> _fuentes(List<Clip> clips) async {
    final fuentes = <AudioSource>[];
    for (final clip in clips) {
      fuentes.add(clip.esPausa ? await _pausa(clip.pausaMs) : await Grabaciones.fuente(clip.ruta));
    }
    return fuentes;
  }

  /// Un trozo de silencio de [ms] (cada pausa con su propia fuente: una
  /// misma no puede estar dos veces en la lista).
  static Future<AudioSource> _pausa(int ms) async => ClippingAudioSource(
        child: await Grabaciones.fuente(_silencio),
        end: Duration(milliseconds: ms.clamp(1, 1000)),
      );

  static Future<void> _detenerSonido() async {
    if (kIsWeb) ReproductorWeb.detener();
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
