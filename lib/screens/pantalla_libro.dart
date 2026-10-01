// ─────────────────────────────────────────────────────────────────────────────
// pantalla_libro.dart — Un libro: de qué trata, qué tan difícil es y sus
// capítulos (con ✓ en los que ya leíste).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_biblioteca.dart' show PortadaLibro;
import 'pantalla_lectura.dart';

class PantallaLibro extends StatefulWidget {
  const PantallaLibro({super.key, required this.libro});

  final Libro libro;

  @override
  State<PantallaLibro> createState() => _PantallaLibroState();
}

class _PantallaLibroState extends State<PantallaLibro> {
  List<CapituloLibro>? _capitulos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final capitulos = await DatosApp.de(context).capitulos(widget.libro);
    if (mounted) setState(() => _capitulos = capitulos);
  }

  Future<void> _leer(int indice) async {
    final capitulos = _capitulos;
    if (capitulos == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PantallaLectura(libro: widget.libro, capitulos: capitulos, indice: indice),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final libro = widget.libro;
    final capitulos = _capitulos;
    final color = EtiquetaNivel.colorDe(libro.nivelHsk);
    final siguiente = capitulos?.indexWhere((c) => !c.leido) ?? -1;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: libro.tituloEs, subtitulo: nombreDeNivel(libro.nivelHsk)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PortadaLibro(libro: libro, color: color, tamano: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(libro.tituloPinyin, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text(libro.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              EtiquetaNivel(nivel: libro.nivelHsk),
                              Text(libro.adaptado ? 'Adaptado' : 'Texto original',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(libro.descripcion, style: const TextStyle(fontSize: 14, height: 1.4)),
                  const SizedBox(height: 10),
                  Text(
                    'Si dominas ${nombreDeNivel(libro.nivelHsk)}, ya conoces el '
                    '${(libro.cobertura * 100).round()} % de sus ${libro.caracteres} caracteres '
                    '(contando las palabras que se explican en cada capítulo).',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(libro.fuente,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (capitulos == null)
              const Center(child: CircularProgressIndicator(color: Colors.black54))
            else ...[
              if (capitulos.isNotEmpty)
                Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xDE000000),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(siguiente <= 0
                        ? (siguiente == 0 ? 'Empezar a leer' : 'Leer otra vez')
                        : 'Seguir: capítulo ${siguiente + 1}'),
                    onPressed: () => _leer(siguiente < 0 ? 0 : siguiente),
                  ),
                ),
              const SizedBox(height: 14),
              for (final (i, cap) in capitulos.indexed) ...[
                TarjetaVidrio(
                  onTap: () => _leer(i),
                  relleno: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: cap.leido ? color : color.withValues(alpha: 0.10),
                        child: cap.leido
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text('${cap.orden}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cap.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                            Text(cap.tituloEs, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
