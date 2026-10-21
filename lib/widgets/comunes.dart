// ─────────────────────────────────────────────────────────────────────────────
// comunes.dart — Piezas de interfaz que se repiten en varias pantallas
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../helpers/pinyin_helper.dart';
import '../tema.dart';
import '../idioma.dart';

/// Barra superior transparente con flecha para regresar.
class BarraSuperior extends StatelessWidget implements PreferredSizeWidget {
  const BarraSuperior({super.key, required this.titulo, this.subtitulo, this.acciones});

  final String titulo;
  final String? subtitulo;
  final List<Widget>? acciones;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        tooltip: tr('Regresar'),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.tinta)),
          if (subtitulo != null) Text(subtitulo!, style: TextStyle(fontSize: 11, color: c.tenue)),
        ],
      ),
      actions: acciones,
    );
  }
}

/// Etiqueta pequeña de nivel: "HSK 3", "HSK 7-9", "Fuera de HSK".
class EtiquetaNivel extends StatelessWidget {
  const EtiquetaNivel({super.key, required this.nivel});
  final int nivel;

  static Color colorDe(int nivel) => switch (nivel) {
        1 => const Color(0xFF2E7D32),
        2 => const Color(0xFF00838F),
        3 => const Color(0xFF1565C0),
        4 => const Color(0xFF4527A0),
        5 => const Color(0xFF6A1B9A),
        6 => const Color(0xFFAD1457),
        7 => const Color(0xFFC62828),
        _ => const Color(0xFF757575),
      };

  /// Color del nivel para texto sobre el fondo actual: en modo oscuro, más
  /// claro (los tonos profundos no se leerían sobre negro).
  static Color colorPara(BuildContext context, int nivel) {
    final base = colorDe(nivel);
    return context.colores.oscuro ? Color.lerp(base, Colors.white, 0.45)! : base;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorPara(context, nivel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(nombreDeNivel(nivel),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Barra de avance delgada con texto "12 / 300".
class BarraAvance extends StatelessWidget {
  const BarraAvance({super.key, required this.valor, required this.total, this.color});

  final int valor;
  final int total;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final fraccion = total == 0 ? 0.0 : valor / total;
    return Row(
      children: [
        Expanded(
          // borderRadius propio en vez de ClipRRect: sin capa de recorte en listas.
          child: LinearProgressIndicator(
            value: fraccion,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: c.separador,
            color: color ?? c.tinta,
          ),
        ),
        const SizedBox(width: 8),
        Text('$valor / $total', style: TextStyle(fontSize: 11, color: c.tenue)),
      ],
    );
  }
}

/// Pinyin del carácter coloreado por tono, más sus otras lecturas en gris.
class PinyinColoreado extends StatelessWidget {
  const PinyinColoreado({super.key, required this.caracter, this.tamano = 22});

  final Caracter caracter;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final color = PinyinHelper.colorDeTono(PinyinHelper.tonoDeNumero(caracter.pinyinNum), oscuro: context.colores.oscuro);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: caracter.pinyin,
          style: TextStyle(fontSize: tamano, fontWeight: FontWeight.w500, color: color, letterSpacing: 1),
        ),
        if (caracter.otrasLecturas.isNotEmpty)
          TextSpan(
            text: tr('   también {0}', [caracter.otrasLecturas.replaceAll(' ', ', ')]),
            style: TextStyle(fontSize: tamano * 0.55, color: context.colores.tenue),
          ),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// Significado del carácter; si solo existe en inglés, se marca con "EN".
class TextoSignificado extends StatelessWidget {
  const TextoSignificado({super.key, required this.caracter, this.maxLineas = 3, this.tamano = 15});

  final Caracter caracter;
  final int maxLineas;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estilo = TextStyle(
      fontSize: tamano,
      color: c.tinta,
      fontStyle: caracter.significadoEnIdioma ? FontStyle.normal : FontStyle.italic,
      height: 1.3,
    );
    return Text.rich(
      TextSpan(children: [
        if (!caracter.significadoEnIdioma)
          TextSpan(
            text: 'EN  ',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.tenue),
          ),
        TextSpan(text: caracter.significado, style: estilo),
      ]),
      maxLines: maxLineas,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

/// Mensaje centrado con un emoji, un título y un texto (listas vacías, fin
/// de sesión…).
class MensajeCentrado extends StatelessWidget {
  const MensajeCentrado({
    super.key,
    required this.emoji,
    required this.titulo,
    this.texto,
    this.acciones = const [],
  });

  final String emoji;
  final String titulo;
  final String? texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (texto != null) ...[
              const SizedBox(height: 8),
              Text(texto!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: context.colores.suave, height: 1.4)),
            ],
            if (acciones.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: acciones),
            ],
          ],
        ),
      ),
    );
  }
}
