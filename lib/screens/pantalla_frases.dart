// ─────────────────────────────────────────────────────────────────────────────
// pantalla_frases.dart — Frases esenciales (Practicar)
//
// Lo que hay que saber decir en chino sí o sí, por situación:
//   · Arriba se elige la situación (saludos, compras…) o todas.
//   · Dos ejercicios con esas frases (pantalla_ejercicio_frases.dart):
//     «Escuchar y elegir» y «Armar la frase».
//   · Cada frase con su pinyin, su traducción, cuándo se usa y el botón para
//     oírla (mantenerlo presionado la dice lento). ✓ si ya la practicaste.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/frases.dart';
import '../datos/repositorio_frases.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../idioma.dart';
import 'pantalla_ejercicio_frases.dart';

class PantallaFrases extends StatefulWidget {
  const PantallaFrases({super.key});

  @override
  State<PantallaFrases> createState() => _PantallaFrasesState();
}

class _PantallaFrasesState extends State<PantallaFrases> {
  List<Frase>? _frases;

  /// null = todas.
  Situacion? _situacion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final frases = await DatosApp.de(context).frases();
    if (mounted) setState(() => _frases = frases);
  }

  Future<void> _practicar(ModoFrases modo) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PantallaEjercicioFrases(modo: modo, situacion: _situacion)),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final frases = _frases;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Frases esenciales'), subtitulo: tr('Lo que hay que saber decir')),
        body: frases == null ? const Center(child: CircularProgressIndicator()) : _lista(frases),
      ),
    );
  }

  Widget _lista(List<Frase> todas) {
    final visibles = [
      for (final f in todas)
        if (_situacion == null || f.situacion == _situacion) f,
    ];
    final practicadas = <Situacion, int>{};
    final totales = <Situacion, int>{};
    for (final f in todas) {
      totales[f.situacion] = (totales[f.situacion] ?? 0) + 1;
      if (f.progreso != null) practicadas[f.situacion] = (practicadas[f.situacion] ?? 0) + 1;
    }
    // Renglones de la lista: el nombre de cada situación y sus frases. La
    // lista solo arma los que se ven.
    final renglones = <Object>[];
    Situacion? anterior;
    for (final f in visibles) {
      if (f.situacion != anterior) renglones.add(f.situacion);
      renglones.add(f);
      anterior = f.situacion;
    }
    const fijos = 2; // selector de situación y ejercicios
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: fijos + renglones.length,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _SelectorSituacion(elegida: _situacion, onCambio: (s) => setState(() => _situacion = s));
        }
        if (i == 1) return _Ejercicios(onPracticar: _practicar);
        return switch (renglones[i - fijos]) {
          final Situacion s => _Encabezado(situacion: s, practicadas: practicadas[s] ?? 0, total: totales[s] ?? 0),
          final Frase f => _TarjetaFrase(frase: f),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

/// Fila de situaciones: «Todas» y una por situación.
class _SelectorSituacion extends StatelessWidget {
  const _SelectorSituacion({required this.elegida, required this.onCambio});

  final Situacion? elegida;
  final ValueChanged<Situacion?> onCambio;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget chip(String texto, Situacion? s) {
      final activa = s == elegida;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: activa,
          showCheckmark: false,
          labelStyle: TextStyle(fontWeight: FontWeight.w600, color: activa ? c.textoBoton : c.tinta),
          selectedColor: c.boton,
          backgroundColor: c.tarjeta,
          side: BorderSide(color: activa ? c.boton : c.bordeLienzo),
          onSelected: (_) => onCambio(s),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          chip(tr('Todas'), null),
          for (final s in Situacion.values) chip(s.nombre, s),
        ],
      ),
    );
  }
}

/// Los dos ejercicios, lado a lado.
class _Ejercicios extends StatelessWidget {
  const _Ejercicios({required this.onPracticar});

  final ValueChanged<ModoFrases> onPracticar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget tarjeta(String emoji, String titulo, String texto, ModoFrases modo) => Expanded(
          child: TarjetaVidrio(
            onTap: () => onPracticar(modo),
            relleno: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: TextStyle(fontSize: 12, color: c.suave, height: 1.3)),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tarjeta('👂', tr('Escuchar y elegir'), tr('Oye la frase y elige qué significa.'), ModoFrases.escuchar),
            const SizedBox(width: 12),
            tarjeta('🧩', tr('Armar la frase'), tr('Ordena las palabras para decirla en chino.'), ModoFrases.armar),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.situacion, required this.practicadas, required this.total});

  final Situacion situacion;
  final int practicadas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(situacion.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Text(tr('{0} de {1} practicadas', [practicadas, total]), style: TextStyle(fontSize: 12, color: c.tenue)),
        ],
      ),
    );
  }
}

class _TarjetaFrase extends StatelessWidget {
  const _TarjetaFrase({required this.frase});

  final Frase frase;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final progreso = frase.progreso;
    // La nota está escrita en español.
    final nota = Idioma.ingles ? null : frase.nota;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TarjetaVidrio(
        relleno: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(frase.chino, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text(frase.pinyin, style: TextStyle(fontSize: 14, color: c.suave)),
                  const SizedBox(height: 4),
                  Text(frase.traduccion, style: const TextStyle(fontSize: 15)),
                  if (nota != null) ...[
                    const SizedBox(height: 4),
                    Text(nota, style: TextStyle(fontSize: 12, color: c.tenue, height: 1.35)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                BotonVoz(texto: frase.chino, pinyin: frase.silabas),
                if (progreso != null) ...[
                  const SizedBox(height: 10),
                  Icon(
                    progreso.dominado ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: ColoresRespuesta.bien(context),
                    semanticLabel: tr('Practicada'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
