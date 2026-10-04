// ─────────────────────────────────────────────────────────────────────────────
// pantalla_oido.dart — Práctica de oído (Inicio → Oído)
//
// Tres ejercicios cortos (rondas de 10) con grabaciones de hablantes nativos:
//   · Tonos: suena una sílaba y eliges su tono. Se puede empezar solo con
//     1 y 4 (los más distintos) o 2 y 3 (los que más se confunden).
//   · Escucha: suena un carácter y eliges cuál es.
//   · Pinyin: ves un carácter y escribes cómo se lee.
// Debajo de Tonos se ve qué tanto aciertas cada tono.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/oido.dart';
import '../helpers/pinyin_helper.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_ejercicio_oido.dart';

class PantallaOido extends StatefulWidget {
  const PantallaOido({super.key});

  @override
  State<PantallaOido> createState() => _PantallaOidoState();
}

class _PantallaOidoState extends State<PantallaOido> {
  // Se recuerdan mientras la app está abierta.
  static List<int> _tonos = const [1, 2, 3, 4];
  static int _nivelEscucha = 2;
  static int _nivelPinyin = 1;

  Map<String, (int, int)> _porTono = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final e = await DatosApp.de(context).estadisticasOido('tono');
    if (mounted) setState(() => _porTono = e);
  }

  Future<void> _empezar(EjercicioOido ejercicio) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PantallaEjercicioOido(
          ejercicio: ejercicio,
          tonos: _tonos,
          nivelMax: ejercicio == EjercicioOido.pinyin ? _nivelPinyin : _nivelEscucha,
        ),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final suave = TextStyle(fontSize: 13, color: c.suave, height: 1.3);
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Práctica de oído', subtitulo: 'Voces de hablantes nativos'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TarjetaVidrio(
              relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Text('🐢', style: TextStyle(fontSize: 22)),
                title: const Text('Audio más lento', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Las grabaciones suenan al 75 % de velocidad, sin cambiar la voz.', style: suave),
                value: Voz.lento,
                onChanged: (v) async {
                  await Voz.cambiarLento(v);
                  setState(() {});
                  if (context.mounted) await DatosApp.de(context).guardarAudioLento(v);
                },
              ),
            ),
            const SizedBox(height: 12),
            _TarjetaEjercicio(
              icono: '🎵',
              titulo: 'Tonos',
              texto: 'Suena una sílaba y eliges su tono. El oído es lo primero en el chino: '
                  'mā, má, mǎ y mà son cuatro palabras distintas.',
              opciones: [
                for (final (etiqueta, tonos) in const [
                  ('1 y 4', [1, 4]),
                  ('2 y 3', [2, 3]),
                  ('Los cuatro', [1, 2, 3, 4]),
                ])
                  ChoiceChip(
                    label: Text(etiqueta),
                    selected: _mismos(_tonos, tonos),
                    onSelected: (_) => setState(() => _tonos = tonos),
                  ),
              ],
              pie: _porTono.isEmpty ? null : _AciertosPorTono(porTono: _porTono),
              onEmpezar: () => _empezar(EjercicioOido.tonos),
            ),
            const SizedBox(height: 12),
            _TarjetaEjercicio(
              icono: '🎧',
              titulo: 'Escucha',
              texto: 'Suena un carácter y eliges cuál es entre cuatro.',
              opciones: _chipsNivel(_nivelEscucha, (n) => setState(() => _nivelEscucha = n)),
              onEmpezar: () => _empezar(EjercicioOido.escucha),
            ),
            const SizedBox(height: 12),
            _TarjetaEjercicio(
              icono: '✍️',
              titulo: 'Pinyin',
              texto: 'Ves un carácter y escribes cómo se lee, con su tono: hao3 o hǎo.',
              opciones: _chipsNivel(_nivelPinyin, (n) => setState(() => _nivelPinyin = n)),
              onEmpezar: () => _empezar(EjercicioOido.pinyin),
            ),
          ],
        ),
      ),
    );
  }

  static bool _mismos(List<int> a, List<int> b) => a.length == b.length && a.every(b.contains);

  List<Widget> _chipsNivel(int actual, ValueChanged<int> elegir) => [
        for (final (etiqueta, nivel) in const [('HSK 1', 1), ('1–2', 2), ('1–3', 3), ('1–6', 6)])
          ChoiceChip(label: Text(etiqueta), selected: actual == nivel, onSelected: (_) => elegir(nivel)),
      ];
}

class _TarjetaEjercicio extends StatelessWidget {
  const _TarjetaEjercicio({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.opciones,
    required this.onEmpezar,
    this.pie,
  });

  final String icono;
  final String titulo;
  final String texto;
  final List<Widget> opciones;
  final VoidCallback onEmpezar;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return TarjetaVidrio(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icono, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.boton, foregroundColor: c.textoBoton),
                onPressed: onEmpezar,
                child: const Text('Empezar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(texto, style: TextStyle(fontSize: 13, color: c.suave, height: 1.3)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: opciones),
          if (pie != null) ...[const SizedBox(height: 8), pie!],
        ],
      ),
    );
  }
}

/// "Tono 1 · 92 %   Tono 2 · 70 %…" con el color de cada tono.
class _AciertosPorTono extends StatelessWidget {
  const _AciertosPorTono({required this.porTono});

  final Map<String, (int, int)> porTono;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final t in [1, 2, 3, 4])
          if (porTono['$t'] case (final aciertos, final intentos) when intentos > 0)
            Text.rich(TextSpan(children: [
              TextSpan(
                text: 'Tono $t ',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: PinyinHelper.colorDeTono(t, oscuro: c.oscuro)),
              ),
              TextSpan(
                text: '${(aciertos * 100 / intentos).round()} %',
                style: TextStyle(fontSize: 12, color: c.suave),
              ),
            ])),
      ],
    );
  }
}
