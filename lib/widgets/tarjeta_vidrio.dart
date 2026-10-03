// ─────────────────────────────────────────────────────────────────────────────
// tarjeta_vidrio.dart — Efecto "vidrio" sin desenfoque
//
// Antes cada tarjeta usaba BackdropFilter (desenfoque del fondo). Es el efecto
// más caro de Flutter: se recalcula en CADA cuadro mientras algo se mueve en
// pantalla, y la cuadrícula de radicales tenía uno por celda. Eso era lo que
// hacía sentir la app "a 30 Hz".
//
// Aquí el aspecto de vidrio se logra con un relleno blanco translúcido, un
// borde claro y una sombra suave. Sobre el fondo claro de la app se ve casi
// igual y cuesta prácticamente nada.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class TarjetaVidrio extends StatelessWidget {
  const TarjetaVidrio({
    super.key,
    required this.child,
    this.onTap,
    this.radio = 18,
    this.relleno = const EdgeInsets.all(16),
    this.color = const Color(0xB3FFFFFF),
    this.colorBorde = const Color(0xCCFFFFFF),
    this.sombra = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radio;
  final EdgeInsetsGeometry relleno;

  /// Color de relleno (translúcido).
  final Color color;
  final Color colorBorde;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        boxShadow: sombra
            ? const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: forma,
          side: BorderSide(color: colorBorde, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: relleno, child: child),
        ),
      ),
    );
  }
}
