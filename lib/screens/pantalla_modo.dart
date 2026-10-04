// ─────────────────────────────────────────────────────────────────────────────
// pantalla_modo.dart — ¿Cómo quieres estudiar?
//
// 1. Nivel de experiencia:
//    Novato  → ves la silueta del carácter y, si te equivocas, una animación
//              del trazo correcto.
//    Experto → sin silueta ni animación: escribes de memoria (la pista roja
//              del trazo correcto sí aparece al equivocarte).
// 2. Qué estudiar: niveles HSK oficiales o radicales Kangxi y sus familias.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../tema.dart';
import '../widgets/fondo_tinta.dart';
import 'pantalla_seleccion.dart';
import 'pantalla_radicales.dart';

class PantallaModo extends StatefulWidget {
  const PantallaModo({super.key});

  @override
  State<PantallaModo> createState() => _PantallaModoState();
}

class _PantallaModoState extends State<PantallaModo> {
  bool? _modoNovato;

  void _navegar(bool esRadical) {
    if (_modoNovato == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero elige tu nivel de experiencia'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => esRadical
            ? PantallaRadicales(modoNovato: _modoNovato!)
            : PantallaSeleccion(modoNovato: _modoNovato!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final azul = c.oscuro ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);
    final morado = c.oscuro ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: c.tinta, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('¿Cómo quieres estudiar?',
              style: TextStyle(color: c.tinta, fontSize: 16, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Selector de experiencia ──────────────────────────
                const _Seccion(titulo: "Tu nivel de experiencia"),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BotonSelector(
                        seleccionado: _modoNovato == true,
                        icono: Icons.school_rounded,
                        titulo: "Soy novato",
                        subtitulo: "Silueta y guía de trazos",
                        onTap: () => setState(() => _modoNovato = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BotonSelector(
                        seleccionado: _modoNovato == false,
                        icono: Icons.psychology_rounded,
                        titulo: "Tengo experiencia",
                        subtitulo: "De memoria, sin silueta",
                        onTap: () => setState(() => _modoNovato = false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Selector de contenido ────────────────────────────
                const _Seccion(titulo: "¿Qué quieres estudiar?"),
                const SizedBox(height: 12),

                // Tarjeta HSK — colores azules fijos en hex
                _TarjetaEstudio(
                  icono: "📚",
                  titulo: "Niveles HSK",
                  subtitulo:
                      "Los 3,000 caracteres de la lista oficial HSK 3.0",
                  detalle: "HSK 1 → HSK 7-9",
                  colorFondo: azul.withValues(alpha: 0.06),
                  colorBorde: azul.withValues(alpha: 0.30),
                  colorDetalleFondo: azul.withValues(alpha: 0.10),
                  colorDetalleTexto: azul,
                  activo: _modoNovato != null,
                  onTap: () => _navegar(false),
                ),

                const SizedBox(height: 12),

                // Tarjeta Radicales — colores morados fijos en hex
                _TarjetaEstudio(
                  icono: "🔑",
                  titulo: "Radicales Kangxi",
                  subtitulo:
                      "Los 214 radicales y la familia de caracteres de cada uno",
                  detalle: "Radical → familia",
                  colorFondo: morado.withValues(alpha: 0.06),
                  colorBorde: morado.withValues(alpha: 0.30),
                  colorDetalleFondo: morado.withValues(alpha: 0.10),
                  colorDetalleTexto: morado,
                  activo: _modoNovato != null,
                  onTap: () => _navegar(true),
                ),

                const Spacer(),

                // ── Nota informativa ─────────────────────────────────
                if (_modoNovato == true)
                  const _NotaInfo(
                    icono: Icons.lightbulb_outline,
                    texto:
                        "Modo novato: verás la silueta del carácter y una animación del trazo correcto cuando te equivoques.",
                  ),
                if (_modoNovato == false)
                  const _NotaInfo(
                    icono: Icons.fitness_center,
                    texto:
                        "Modo experto: sin silueta. Escribes de memoria; solo al equivocarte ves en rojo el trazo que tocaba.",
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

/// Título pequeño de sección.
class _Seccion extends StatelessWidget {
  final String titulo;
  const _Seccion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(titulo,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colores.tenue,
            letterSpacing: 0.8));
  }
}

/// Botón de "Soy novato" / "Tengo experiencia".
class _BotonSelector extends StatelessWidget {
  final bool     seleccionado;
  final IconData icono;
  final String   titulo;
  final String   subtitulo;
  final VoidCallback onTap;

  const _BotonSelector({
    required this.seleccionado,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado ? c.boton : c.tarjeta,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado ? c.boton : c.bordeLienzo,
            width: 1.5,
          ),
          boxShadow: seleccionado ? [BoxShadow(color: c.sombra, blurRadius: 12)] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: seleccionado ? c.textoBoton : c.tenue, size: 24),
            const SizedBox(height: 8),
            Text(titulo,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: seleccionado ? c.textoBoton : c.tinta)),
            const SizedBox(height: 4),
            Text(subtitulo,
                style: TextStyle(
                    fontSize: 11, color: seleccionado ? c.textoBoton.withValues(alpha: 0.6) : c.tenue)),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande para elegir qué estudiar (HSK o radicales).
class _TarjetaEstudio extends StatelessWidget {
  final String icono;
  final String titulo;
  final String subtitulo;
  final String detalle;
  final Color  colorFondo;
  final Color  colorBorde;
  final Color  colorDetalleFondo;
  final Color  colorDetalleTexto;
  final bool   activo;
  final VoidCallback onTap;

  const _TarjetaEstudio({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.detalle,
    required this.colorFondo,
    required this.colorBorde,
    required this.colorDetalleFondo,
    required this.colorDetalleTexto,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: AnimatedOpacity(
        opacity: activo ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 300),
        // Sin BackdropFilter (desenfoque): ver widgets/tarjeta_vidrio.dart.
        child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color.alphaBlend(colorFondo, c.tarjeta),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorBorde, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(icono, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(subtitulo, style: TextStyle(fontSize: 13, color: c.tenue)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorDetalleFondo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(detalle,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorDetalleTexto,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: c.tenue),
                ],
              ),
            ),
      ),
    );
  }
}

/// Nota amarilla que explica el modo elegido.
class _NotaInfo extends StatelessWidget {
  final IconData icono;
  final String   texto;
  const _NotaInfo({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final oscuro = context.colores.oscuro;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: oscuro ? const Color(0x26FFB300) : const Color(0xFFFFF8E1), // ámbar suave
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oscuro ? const Color(0x4DFFB300) : const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFFF9A825), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 13, color: oscuro ? const Color(0xFFFFCC80) : const Color(0xFFE65100), height: 1.4)),
          ),
        ],
      ),
    );
  }
}