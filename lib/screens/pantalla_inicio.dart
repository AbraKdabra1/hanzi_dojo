import 'dart:ui';
import 'package:flutter/material.dart';
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
    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('¿Cómo quieres estudiar?',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
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
                        subtitulo: "Con guía de trazos",
                        onTap: () => setState(() => _modoNovato = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BotonSelector(
                        seleccionado: _modoNovato == false,
                        icono: Icons.psychology_rounded,
                        titulo: "Tengo experiencia",
                        subtitulo: "Sin pistas de trazos",
                        onTap: () => setState(() => _modoNovato = false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Selector de contenido ────────────────────────────
                const _Seccion(titulo: "¿Qué quieres estudiar?"),
                const SizedBox(height: 12),

                _TarjetaEstudio(
                  icono: "📚",
                  titulo: "Niveles HSK",
                  subtitulo:
                      "Vocabulario oficial del examen de chino estándar",
                  detalle: "HSK 1 → HSK 7-9",
                  colorBorde: const Color(0xFF1565C0),
                  colorFondo: const Color(0x0F1565C0),
                  activo: _modoNovato != null,
                  onTap: () => _navegar(false),
                ),

                const SizedBox(height: 12),

                _TarjetaEstudio(
                  icono: "🔑",
                  titulo: "Radicales Kangxi",
                  subtitulo:
                      "Los 214 componentes base de todos los caracteres chinos",
                  detalle: "Orden por radical",
                  colorBorde: const Color(0xFF6A1B9A),
                  colorFondo: const Color(0x0F6A1B9A),
                  activo: _modoNovato != null,
                  onTap: () => _navegar(true),
                ),

                const Spacer(),

                // ── Nota informativa ─────────────────────────────────
                if (_modoNovato == true)
                  const _NotaInfo(
                    icono: Icons.lightbulb_outline,
                    texto:
                        "Modo novato: verás una animación del trazo esperado cuando cometas un error.",
                  ),
                if (_modoNovato == false)
                  const _NotaInfo(
                    icono: Icons.fitness_center,
                    texto:
                        "Modo experto: sin pistas. Confías en tu memoria muscular.",
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

class _Seccion extends StatelessWidget {
  final String titulo;
  const _Seccion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(titulo,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.8));
  }
}

class _BotonSelector extends StatelessWidget {
  final bool seleccionado;
  final IconData icono;
  final String titulo;
  final String subtitulo;
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Color con alpha en hex, sin withOpacity
          color: seleccionado
              ? const Color(0xDE000000)  // black87
              : const Color(0xB3FFFFFF), // white ~70%
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado
                ? const Color(0xDE000000)
                : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
          boxShadow: seleccionado
              ? const [
                  BoxShadow(
                      color: Color(0x33000000), blurRadius: 12)
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono,
                color: seleccionado
                    ? Colors.white
                    : Colors.grey.shade600,
                size: 24),
            const SizedBox(height: 8),
            Text(titulo,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: seleccionado
                        ? Colors.white
                        : Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitulo,
                style: TextStyle(
                    fontSize: 11,
                    color: seleccionado
                        ? const Color(0x99FFFFFF)  // white60
                        : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaEstudio extends StatelessWidget {
  final String icono;
  final String titulo;
  final String subtitulo;
  final String detalle;
  final Color  colorBorde;
  final Color  colorFondo;
  final bool   activo;
  final VoidCallback onTap;

  const _TarjetaEstudio({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.detalle,
    required this.colorBorde,
    required this.colorFondo,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: AnimatedOpacity(
        opacity: activo ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  // Usamos Color.fromARGB para el 30% de opacidad del borde
                  color: Color.fromARGB(
                    76, // ~30% de 255
                    colorBorde.red,
                    colorBorde.green,
                    colorBorde.blue,
                  ),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(icono,
                      style: const TextStyle(fontSize: 32)),
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
                        Text(subtitulo,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                              26, // ~10%
                              colorBorde.red,
                              colorBorde.green,
                              colorBorde.blue,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(detalle,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorBorde,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotaInfo extends StatelessWidget {
  final IconData icono;
  final String   texto;
  const _NotaInfo({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // amber.shade50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)), // amber.shade200
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFFF9A825), size: 18), // amber.shade700
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE65100), // amber.shade900
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}