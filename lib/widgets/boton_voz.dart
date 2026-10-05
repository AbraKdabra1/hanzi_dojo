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
// ejercicios tienen además un botón 🐢 para repetir algo más despacio.
//
// Batería: el reproductor se detiene (y suelta el decodificador) al terminar.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../datos/audio.dart';
import '../datos/registro_errores.dart';
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
      final audio = _audio;
      await audio.setSpeed(rapidez ?? velocidad);
      for (final clip in plan.clips) {
        if (turno != _turno) return false;
        if (clip.esPausa) {
          await Future<void>.delayed(Duration(milliseconds: clip.pausaMs));
          continue;
        }
        alSonar(clip.inicio, clip.fin);
        await audio.setAsset(clip.ruta);
        if (turno != _turno) return false;
        await audio.play();
      }
      return turno == _turno;
    } catch (e, pila) {
      RegistroErrores.registrar('Voz (leer en voz alta)', e, pila);
      return false;
    } finally {
      if (turno == _turno) await _reproductor?.stop();
      alSonar(-1, -1);
    }
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
    final audio = _audio;
    try {
      await audio.setSpeed(rapidez);
      for (final clip in clips) {
        if (turno != _turno) return;
        if (clip.esPausa) {
          await Future<void>.delayed(Duration(milliseconds: clip.pausaMs));
          continue;
        }
        await audio.setAsset(clip.ruta);
        if (turno != _turno) return;
        await audio.play(); // termina cuando acaba la grabación (o si se detiene)
      }
    } finally {
      // Al terminar se suelta el decodificador (ahorra batería y memoria).
      if (turno == _turno) await audio.stop();
    }
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
  const BotonVoz({super.key, required this.texto, this.pinyin, this.pinyinPorPalabras, this.tamano = 20});

  /// Texto en chino que se va a leer.
  final String texto;

  /// Una sílaba de pinyin por carácter de [texto] (opcional): con ella cada
  /// carácter suelto se lee con su lectura en ESE texto.
  final List<String>? pinyin;

  /// Alternativa a [pinyin] cuando viene escrito por palabras ('wǒ xǐhuan…').
  final String? pinyinPorPalabras;
  final double tamano;

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
        rapidez: lento ? Voz.velocidadLenta : null);
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
