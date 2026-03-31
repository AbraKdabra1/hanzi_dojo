import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:ui';

class GlassSpeakerButton extends StatefulWidget {
  final String textoALeer;

  const GlassSpeakerButton({super.key, required this.textoALeer});

  @override
  State<GlassSpeakerButton> createState() => _GlassSpeakerButtonState();
}

class _GlassSpeakerButtonState extends State<GlassSpeakerButton> {
  final FlutterTts _tts = FlutterTts();
  bool _hablando = false;

  @override
  void initState() {
    super.initState();
    _configurarTts();
  }

  Future<void> _configurarTts() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _hablando = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _hablando = false);
    });
  }

  Future<void> _toggleVoz() async {
    if (_hablando) {
      await _tts.stop();
      setState(() => _hablando = false);
    } else {
      setState(() => _hablando = true);
      await _tts.speak(widget.textoALeer);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color fondoInactivo = Color(0x18000000);
    const Color fondoActivo   = Color(0x22007AFF);
    const Color bordeInactivo = Color(0x30FFFFFF);
    const Color bordeActivo   = Color(0x55007AFF);
    const Color iconoInactivo = Color(0xFF555555);
    const Color iconoActivo   = Color(0xFF007AFF);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: GestureDetector(
          onTap: _toggleVoz,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: 72,
            height: 40,
            decoration: BoxDecoration(
              color: _hablando ? fondoActivo : fondoInactivo,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hablando ? bordeActivo : bordeInactivo,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hablando
                      ? const Color(0x44007AFF)
                      : const Color(0x22FFFFFF),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                  blurStyle: BlurStyle.inner,
                ),
                const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _hablando
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  key: ValueKey<bool>(_hablando),
                  color: _hablando ? iconoActivo : iconoInactivo,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}