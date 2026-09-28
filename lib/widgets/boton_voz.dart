// ─────────────────────────────────────────────────────────────────────────────
// boton_voz.dart — Botón para escuchar la pronunciación
//
// Usa el motor de texto a voz del teléfono en chino mandarín (zh-CN).
// Si el teléfono no tiene la voz china instalada, no se oye nada; se instala
// en los ajustes de idioma del teléfono, en la sección de texto a voz.
//
// El motor de voz se crea una sola vez para toda la app (Voz.instancia).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Motor de voz compartido.
class Voz {
  Voz._();
  static final FlutterTts _tts = FlutterTts();
  static Future<void>? _configurando;

  static Future<void> _configurar() => _configurando ??= () async {
        await _tts.setLanguage('zh-CN');
        await _tts.setSpeechRate(0.42); // un poco más lento que lo normal
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
      }();

  /// Lee [texto] en voz alta. Si el motor de voz falla (p. ej. aún no estaba
  /// listo), no rompe la pantalla y en el siguiente toque se vuelve a intentar
  /// configurar desde cero.
  static Future<void> decir(String texto) async {
    try {
      await _configurar();
      await _tts.stop();
      await _tts.speak(texto);
    } catch (e) {
      _configurando = null;
      debugPrint('Voz: no se pudo leer "$texto": $e');
    }
  }

  static Future<void> detener() => _tts.stop();
}

class BotonVoz extends StatefulWidget {
  const BotonVoz({super.key, required this.texto, this.tamano = 20});

  /// Texto en chino que se va a leer.
  final String texto;
  final double tamano;

  @override
  State<BotonVoz> createState() => _BotonVozState();
}

class _BotonVozState extends State<BotonVoz> {
  bool _activo = false;

  Future<void> _hablar() async {
    setState(() => _activo = true);
    await Voz.decir(widget.texto);
    // Se apaga el resaltado después de un momento (el aviso de "terminé de
    // hablar" no es confiable en todos los teléfonos).
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _activo = false);
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF007AFF);
    return Semantics(
      button: true,
      label: 'Escuchar pronunciación',
      child: GestureDetector(
        onTap: _hablar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 38,
          decoration: BoxDecoration(
            color: _activo ? const Color(0x22007AFF) : const Color(0x14000000),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _activo ? const Color(0x55007AFF) : const Color(0x30FFFFFF),
              width: 1.2,
            ),
          ),
          child: Icon(
            _activo ? Icons.volume_up_rounded : Icons.volume_up_outlined,
            color: _activo ? azul : const Color(0xFF555555),
            size: widget.tamano,
          ),
        ),
      ),
    );
  }
}
