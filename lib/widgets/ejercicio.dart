// ─────────────────────────────────────────────────────────────────────────────
// ejercicio.dart — Piezas comunes de los ejercicios con audio
//
//   EncabezadoRonda → "3 / 10" con barra de avance y aciertos.
//   BotonEscuchar   → botón grande para oír (y 🐢 para oír lento).
//   BotonOpcion     → una opción de respuesta (normal, correcta, incorrecta).
//   ContornoTono    → dibujo de la curva de un tono (escala de 5 alturas).
//   ResumenRonda    → resultado al terminar una ronda.
//   SelectorNivel   → fila de niveles HSK 1 … 7-9.
//   PinyinPorTonos  → pinyin de una palabra, cada sílaba de su color de tono.
//
// Nada aquí usa relojes ni animaciones continuas (batería): solo
// transiciones cortas al cambiar de estado.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../helpers/pinyin_entrada.dart';
import '../helpers/pinyin_helper.dart';
import '../tema.dart';
import 'comunes.dart';

/// Verde y rojo de acierto/error, legibles en claro y oscuro.
class ColoresRespuesta {
  ColoresRespuesta._();

  static Color bien(BuildContext context) =>
      context.colores.oscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

  static Color mal(BuildContext context) =>
      context.colores.oscuro ? const Color(0xFFE57373) : const Color(0xFFC62828);
}

/// "Pregunta 3 de 10" con barra y aciertos.
class EncabezadoRonda extends StatelessWidget {
  const EncabezadoRonda({super.key, required this.indice, required this.total, required this.aciertos});

  /// Pregunta actual (0 = la primera).
  final int indice;
  final int total;
  final int aciertos;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Text('${indice + 1} / $total', style: TextStyle(fontSize: 13, color: c.suave, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : indice / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: c.separador,
              color: c.tinta,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.check_rounded, size: 16, color: ColoresRespuesta.bien(context)),
          Text(' $aciertos', style: TextStyle(fontSize: 13, color: c.suave, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Botón redondo grande para escuchar, con un botón pequeño 🐢 al lado.
class BotonEscuchar extends StatelessWidget {
  const BotonEscuchar({super.key, required this.onEscuchar, this.onLento, this.sonando = false, this.tamano = 96});

  final VoidCallback onEscuchar;
  final VoidCallback? onLento;
  final bool sonando;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onLento != null) SizedBox(width: tamano * 0.5 + 12),
        Semantics(
          button: true,
          label: 'Escuchar otra vez',
          child: Material(
            color: c.boton,
            shape: const CircleBorder(),
            elevation: sonando ? 0 : 2,
            shadowColor: c.sombra,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEscuchar,
              child: SizedBox(
                width: tamano,
                height: tamano,
                child: Icon(
                  sonando ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                  size: tamano * 0.42,
                  color: c.textoBoton,
                ),
              ),
            ),
          ),
        ),
        if (onLento != null) ...[
          const SizedBox(width: 12),
          Tooltip(
            message: 'Escuchar más lento',
            child: Material(
              color: c.tarjeta,
              shape: CircleBorder(side: BorderSide(color: c.bordeLienzo, width: 1.2)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onLento,
                child: SizedBox(
                  width: tamano * 0.5,
                  height: tamano * 0.5,
                  child: const Center(child: Text('🐢', style: TextStyle(fontSize: 22))),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum EstadoOpcion {
  /// Se puede tocar.
  normal,

  /// La elegiste pero todavía puedes cambiarla (tonos de una palabra).
  elegida,
  correcta,
  incorrecta,
  apagada,
}

/// Una opción de respuesta. Después de contestar se pinta de verde (la
/// correcta) o rojo (la que elegiste mal); las demás se apagan.
class BotonOpcion extends StatelessWidget {
  const BotonOpcion({super.key, required this.child, required this.estado, this.onTap, this.alto = 64});

  final Widget child;
  final EstadoOpcion estado;
  final VoidCallback? onTap;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final (fondo, borde) = switch (estado) {
      EstadoOpcion.correcta => (
          ColoresRespuesta.bien(context).withValues(alpha: 0.14),
          ColoresRespuesta.bien(context),
        ),
      EstadoOpcion.incorrecta => (
          ColoresRespuesta.mal(context).withValues(alpha: 0.14),
          ColoresRespuesta.mal(context),
        ),
      EstadoOpcion.elegida => (c.separador, c.tinta),
      _ => (c.tarjeta, c.bordeLienzo),
    };
    final tocable = estado == EstadoOpcion.normal || estado == EstadoOpcion.elegida;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: estado == EstadoOpcion.apagada ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: BoxConstraints(minHeight: alto),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borde, width: estado == EstadoOpcion.normal ? 1.2 : 2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: tocable ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// La curva de un tono en la escala de 5 alturas de Chao:
///   1.º 5-5 · 2.º 3-5 · 3.º 2-1-4 · 4.º 5-1 · neutro: un punto.
class ContornoTono extends StatelessWidget {
  const ContornoTono({super.key, required this.tono, this.color, this.ancho = 44, this.alto = 26});

  final int tono;
  final Color? color;
  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final colorTono = color ?? PinyinHelper.colorDeTono(tono, oscuro: context.colores.oscuro);
    return CustomPaint(size: Size(ancho, alto), painter: _PintorContorno(tono, colorTono));
  }
}

class _PintorContorno extends CustomPainter {
  _PintorContorno(this.tono, this.color);

  final int tono;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Altura 1 (abajo) … 5 (arriba).
    double y(double altura) => size.height * (1 - (altura - 1) / 4);
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final ruta = Path();
    switch (tono) {
      case 1:
        ruta
          ..moveTo(2, y(5))
          ..lineTo(w - 2, y(5));
      case 2:
        ruta
          ..moveTo(2, y(3))
          ..quadraticBezierTo(w * 0.6, y(3.2), w - 2, y(5));
      case 3:
        ruta
          ..moveTo(2, y(2.2))
          ..quadraticBezierTo(w * 0.35, y(0.6), w * 0.55, y(1.2))
          ..quadraticBezierTo(w * 0.8, y(2), w - 2, y(4));
      case 4:
        ruta
          ..moveTo(2, y(5))
          ..quadraticBezierTo(w * 0.4, y(4.8), w - 2, y(1));
      default:
        canvas.drawCircle(Offset(w / 2, y(2.5)), 3.5, pincel..style = PaintingStyle.fill);
        return;
    }
    canvas.drawPath(ruta, pincel);
  }

  @override
  bool shouldRepaint(_PintorContorno old) => old.tono != tono || old.color != color;
}

/// Resultado de una ronda: aciertos, un mensaje y botones.
class ResumenRonda extends StatelessWidget {
  const ResumenRonda({
    super.key,
    required this.aciertos,
    required this.total,
    required this.onOtraRonda,
    this.detalle,
  });

  final int aciertos;
  final int total;
  final VoidCallback onOtraRonda;

  /// Texto extra (p. ej. qué tono confundiste más en esta ronda).
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final fraccion = total == 0 ? 0.0 : aciertos / total;
    final (emoji, titulo) = switch (fraccion) {
      >= 0.9 => ('🏆', '¡Excelente oído!'),
      >= 0.7 => ('🎯', '¡Muy bien!'),
      >= 0.5 => ('👍', 'Vas por buen camino'),
      _ => ('🌱', 'Cada ronda entrena el oído'),
    };
    return MensajeCentrado(
      emoji: emoji,
      titulo: '$titulo\n$aciertos de $total',
      texto: detalle,
      acciones: [
        FilledButton.icon(
          onPressed: onOtraRonda,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Otra ronda'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Terminar'),
        ),
      ],
    );
  }
}

/// Fila de niveles HSK para elegir con qué practicar.
class SelectorNivel extends StatelessWidget {
  const SelectorNivel({super.key, required this.nivel, required this.onCambio});

  final int nivel;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var n = 1; n <= 7; n++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(nombreDeNivel(n)),
                selected: n == nivel,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: n == nivel ? c.textoBoton : EtiquetaNivel.colorPara(context, n),
                ),
                selectedColor: c.boton,
                backgroundColor: c.tarjeta,
                side: BorderSide(color: n == nivel ? c.boton : c.bordeLienzo),
                onSelected: (_) => onCambio(n),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pinyin de una palabra con cada sílaba de su color de tono:
/// "ba4 ba5" → bà (azul) ba (gris). [silabas] con número; "_" se omite.
class PinyinPorTonos extends StatelessWidget {
  const PinyinPorTonos({super.key, required this.silabas, this.tamano = 22, this.marcadas});

  final List<String> silabas;
  final double tamano;

  /// Si se da, una por sílaba pronunciada: false = se subraya en rojo (la
  /// sílaba que escribiste mal en el ejercicio de pinyin).
  final List<bool>? marcadas;

  @override
  Widget build(BuildContext context) {
    final oscuro = context.colores.oscuro;
    final pronunciadas = [for (final s in silabas) if (s != '_') s];
    return Text.rich(
      TextSpan(children: [
        for (var k = 0; k < pronunciadas.length; k++) ...[
          if (k > 0) TextSpan(text: ' ', style: TextStyle(fontSize: tamano)),
          TextSpan(
            text: PinyinEntrada.numAAcentos(pronunciadas[k]),
            style: TextStyle(
              fontSize: tamano,
              fontWeight: FontWeight.w500,
              color: PinyinHelper.colorDeTono(PinyinHelper.tonoDeNumero(pronunciadas[k]), oscuro: oscuro),
              decoration: marcadas != null && k < marcadas!.length && !marcadas![k] ? TextDecoration.underline : null,
              decorationColor: ColoresRespuesta.mal(context),
              decorationThickness: 2.5,
            ),
          ),
        ],
      ]),
      textAlign: TextAlign.center,
    );
  }
}
