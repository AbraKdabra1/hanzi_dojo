// ─────────────────────────────────────────────────────────────────────────────
// pantalla_libro.dart — Un libro: de qué trata, qué tan difícil es y sus
// capítulos (con ✓ en los que ya leíste). Sirve igual para los libros de la
// app y para los que agregaste tú (nivel estimado a partir de sus caracteres).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';
import 'pantalla_biblioteca.dart' show PortadaLibro;
import 'pantalla_lectura.dart';
import '../idioma.dart';

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
    final color = EtiquetaNivel.colorPara(context, libro.nivelHsk);
    final siguiente = capitulos?.indexWhere((c) => !c.leido) ?? -1;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: libro.propio ? libro.titulo : libro.tituloEs,
          subtitulo: libro.propio ? tr('Mis libros') : nombreDeNivel(libro.nivelHsk),
        ),
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
                            if (libro.tituloPinyin.isNotEmpty)
                              Text(libro.tituloPinyin, style: TextStyle(fontSize: 12, color: context.colores.tenue)),
                            Text(libro.titulo,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: libro.propio ? 20 : 26, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              EtiquetaNivel(nivel: libro.nivelHsk),
                              Text(tipoDeLibro(libro), style: TextStyle(fontSize: 12, color: context.colores.suave)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (libro.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(libro.descripcion, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    explicacionDificultad(libro),
                    style: TextStyle(fontSize: 12.5, color: context.colores.suave, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(libro.fuente,
                      style: TextStyle(fontSize: 12, color: context.colores.tenue, fontStyle: FontStyle.italic, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (capitulos == null)
              Center(child: CircularProgressIndicator(color: context.colores.icono))
            else ...[
              if (capitulos.isNotEmpty)
                Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colores.boton,
                    foregroundColor: context.colores.textoBoton,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(siguiente <= 0
                        ? (siguiente == 0 ? tr('Empezar a leer') : tr('Leer otra vez'))
                        : tr('Seguir: capítulo {0}', [siguiente + 1])),
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
                            ? Icon(Icons.check, size: 16, color: context.colores.lienzo)
                            : Text('${cap.orden}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cap.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                            Text(cap.tituloEs, style: TextStyle(fontSize: 13, color: context.colores.suave)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: context.colores.tenue),
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

/// "Adaptado", "Texto original", "EPUB", "TXT", "Texto pegado".
String tipoDeLibro(Libro libro) {
  if (!libro.propio) return libro.adaptado ? tr('Adaptado') : tr('Texto original');
  return switch (libro.formato) {
    'epub' => 'EPUB',
    'txt' => 'TXT',
    _ => tr('Texto pegado'),
  };
}

/// Qué tan difícil es el libro, en palabras.
String explicacionDificultad(Libro libro) {
  final porciento = (libro.cobertura * 100).round();
  if (!libro.propio) {
    return tr('Si dominas {0}, ya conoces el {1} % de sus {2} caracteres (contando las palabras que se explican en cada capítulo).', [nombreDeNivel(libro.nivelHsk), porciento, libro.caracteres]);
  }
  if (libro.nivelHsk == 0) {
    return tr('Nivel estimado: más difícil que HSK 7-9. Aun dominando todo el HSK conocerías el {0} % de sus {1} caracteres. El pinyin es automático y puede fallar en caracteres con varias lecturas.', [porciento, libro.caracteres]);
  }
  return tr('Nivel estimado: {0}. Si lo dominas, conoces el {1} % de sus {2} caracteres. El pinyin es automático y puede fallar en caracteres con varias lecturas.', [nombreDeNivel(libro.nivelHsk), porciento, libro.caracteres]);
}
