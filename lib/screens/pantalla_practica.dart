// ─────────────────────────────────────────────────────────────────────────────
// pantalla_practica.dart — Practicar con audio (fase 5)
//
// Cuatro ejercicios que usan las grabaciones de hablantes nativos:
//   · Tonos        → oír una sílaba (o una palabra) y elegir su tono.
//   · Escucha      → oír una palabra y elegir su carácter o su significado.
//   · Vocabulario  → repaso espaciado de las palabras HSK (no solo caracteres).
//   · Pinyin       → ver una palabra y escribir cómo se lee.
// Arriba se elige el nivel HSK (se recuerda).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/repositorio_practica.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_escucha.dart';
import 'pantalla_pinyin.dart';
import 'pantalla_tonos.dart';
import 'pantalla_vocabulario.dart';

class PantallaPractica extends StatefulWidget {
  const PantallaPractica({super.key});

  @override
  State<PantallaPractica> createState() => _PantallaPracticaState();
}

class _PantallaPracticaState extends State<PantallaPractica> {
  int _nivel = 1;
  int? _pendientes;
  AvancePalabras? _avance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final nivel = await repo.nivelPractica();
    final pendientes = await repo.palabrasPendientes();
    final avance = await repo.avancePalabras();
    if (!mounted) return;
    setState(() {
      _nivel = nivel;
      _pendientes = pendientes;
      _avance = avance.where((a) => a.nivel == nivel).firstOrNull;
    });
  }

  Future<void> _cambiarNivel(int nivel) async {
    setState(() => _nivel = nivel);
    await DatosApp.de(context).guardarNivelPractica(nivel);
    await _cargar();
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final avance = _avance;
    final pendientes = _pendientes ?? 0;
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Practicar con audio', subtitulo: 'Grabaciones de hablantes nativos'),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Nivel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.tenue)),
            ),
            SelectorNivel(nivel: _nivel, onCambio: _cambiarNivel),
            const SizedBox(height: 16),
            _Ejercicio(
              emoji: '🎵',
              titulo: 'Tonos',
              texto: 'Oye una sílaba y elige su tono. Con palabras de dos sílabas, los dos.',
              onTap: () => _ir(PantallaTonos(nivel: _nivel)),
            ),
            _Ejercicio(
              emoji: '👂',
              titulo: 'Escucha',
              texto: 'Oye una palabra y elige cuál es: por su carácter o por su significado.',
              onTap: () => _ir(PantallaEscucha(nivel: _nivel)),
            ),
            _Ejercicio(
              emoji: '📖',
              titulo: 'Vocabulario',
              texto: pendientes > 0
                  ? 'Repaso espaciado de palabras HSK. Hoy tienes $pendientes por repasar.'
                  : 'Repaso espaciado de las palabras HSK, como con los caracteres.',
              insignia: pendientes > 0 ? '$pendientes' : null,
              pie: avance == null
                  ? null
                  : BarraAvance(valor: avance.estudiadas, total: avance.total),
              onTap: () => _ir(PantallaVocabulario(nivel: _nivel)),
            ),
            _Ejercicio(
              emoji: '⌨️',
              titulo: 'Pinyin',
              texto: 'Ve una palabra y escribe cómo se lee, con sus tonos.',
              onTap: () => _ir(PantallaPinyin(nivel: _nivel)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Consejo: mantén presionado cualquier botón de sonido para oírlo más lento. '
                'En Ajustes puedes hacer que todas las grabaciones suenen lentas.',
                style: TextStyle(fontSize: 12, color: c.tenue, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ejercicio extends StatelessWidget {
  const _Ejercicio({
    required this.emoji,
    required this.titulo,
    required this.texto,
    required this.onTap,
    this.insignia,
    this.pie,
  });

  final String emoji;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  /// Numerito a la derecha (repasos pendientes).
  final String? insignia;

  /// Algo debajo del texto (barra de avance).
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TarjetaVidrio(
        onTap: onTap,
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(texto, style: TextStyle(fontSize: 13, color: c.suave, height: 1.35)),
                  if (pie != null) ...[const SizedBox(height: 8), pie!],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (insignia != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.boton, borderRadius: BorderRadius.circular(10)),
                child: Text(insignia!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textoBoton)),
              )
            else
              Icon(Icons.arrow_forward_ios, size: 14, color: c.tenue),
          ],
        ),
      ),
    );
  }
}
