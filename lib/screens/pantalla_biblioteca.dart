// ─────────────────────────────────────────────────────────────────────────────
// pantalla_biblioteca.dart — «Leer»: los libros, agrupados por nivel HSK
//
// Hay dos tipos de libro:
//   · Adaptados: historias clásicas chinas (de dominio público) contadas de
//     nuevo para la app con los caracteres de su nivel.
//   · Originales: textos clásicos tal cual, con traducción (niveles altos).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_libro.dart';

class PantallaBiblioteca extends StatefulWidget {
  const PantallaBiblioteca({super.key});

  @override
  State<PantallaBiblioteca> createState() => _PantallaBibliotecaState();
}

class _PantallaBibliotecaState extends State<PantallaBiblioteca> {
  List<Libro>? _libros;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final libros = await DatosApp.de(context).libros();
    if (mounted) setState(() => _libros = libros);
  }

  Future<void> _abrir(Libro libro) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PantallaLibro(libro: libro)));
    _cargar(); // al volver, actualizar lo leído
  }

  @override
  Widget build(BuildContext context) {
    final libros = _libros;
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Leer', subtitulo: 'Libros graduados por nivel HSK'),
        body: libros == null
            ? const Center(child: CircularProgressIndicator(color: Colors.black54))
            : libros.isEmpty
                ? const MensajeCentrado(emoji: '📚', titulo: 'Aún no hay libros')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(
                          'Toca cualquier carácter para ver su significado y practicarlo. '
                          'Los nombres propios van subrayados.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                        ),
                      ),
                      for (final (i, libro) in libros.indexed) ...[
                        if (i == 0 || libros[i - 1].nivelHsk != libro.nivelHsk)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                            child: Text(nombreDeNivel(libro.nivelHsk),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: EtiquetaNivel.colorDe(libro.nivelHsk))),
                          ),
                        _TarjetaLibro(libro: libro, onTap: () => _abrir(libro)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _TarjetaLibro extends StatelessWidget {
  const _TarjetaLibro({required this.libro, required this.onTap});

  final Libro libro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = EtiquetaNivel.colorDe(libro.nivelHsk);
    return TarjetaVidrio(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortadaLibro(libro: libro, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libro.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text(libro.tituloPinyin, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(libro.tituloEs, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  '${libro.adaptado ? 'Adaptado' : 'Texto original'} · ${libro.capitulos} '
                  '${libro.capitulos == 1 ? 'capítulo' : 'capítulos'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                BarraAvance(valor: libro.capitulosLeidos, total: libro.capitulos, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Portada" sencilla: el primer carácter del título en un recuadro del
/// color del nivel, como el sello de un libro.
class PortadaLibro extends StatelessWidget {
  const PortadaLibro({super.key, required this.libro, required this.color, this.tamano = 56});

  final Libro libro;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano * 1.3,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Text(
        libro.titulo.characters.first,
        style: TextStyle(fontSize: tamano * 0.55, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
