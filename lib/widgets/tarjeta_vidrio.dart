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
//
// Tampoco se recorta la tarjeta (clipBehavior): un recorte con antialias es
// una capa extra por tarjeta en cada cuadro del scroll. El brillo al tocar
// (InkWell) ya se limita solo a las esquinas redondeadas con borderRadius.
//
// PanelCristal (abajo) es la excepción: cristal de verdad, con el fondo
// desenfocado, solo para las dos piezas del inicio (el resumen del día y la
// lista Estudiar · Practicar · Leer). Son dos, no se desplazan y detrás solo
// se mueve la rama; con el ahorro de batería activado la rama se queda quieta
// y el panel deja el desenfoque (se ve como TarjetaVidrio, un poco más opaco).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../helpers/energia.dart';
import '../tema.dart';

class TarjetaVidrio extends StatelessWidget {
  const TarjetaVidrio({
    super.key,
    required this.child,
    this.onTap,
    this.radio = 18,
    this.relleno = const EdgeInsets.all(16),
    this.color,
    this.colorBorde,
    this.sombra = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radio;
  final EdgeInsetsGeometry relleno;

  /// Color de relleno (translúcido). null = el del tema (claro u oscuro).
  final Color? color;
  final Color? colorBorde;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    final c = context.colores;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        boxShadow: sombra
            ? [BoxShadow(color: c.sombra, blurRadius: 10, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: color ?? c.tarjeta,
        shape: RoundedRectangleBorder(
          borderRadius: forma,
          side: BorderSide(color: colorBorde ?? c.bordeTarjeta, width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: forma,
          child: Padding(padding: relleno, child: child),
        ),
      ),
    );
  }
}

/// Cristal como el de los botones de Apple: deja ver (desenfocado) lo que
/// pasa detrás, con un brillo en la orilla. Ver la nota de arriba sobre su
/// costo; solo se usa en el inicio.
class PanelCristal extends StatelessWidget {
  const PanelCristal({super.key, required this.child, this.radio = 24});

  final Widget child;
  final double radio;

  /// Cuánto se desenfoca el fondo.
  static const sigma = 16.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final forma = BorderRadius.circular(radio);
    return ValueListenableBuilder<bool>(
      valueListenable: Energia.ahorro,
      builder: (context, ahorro, _) {
        // Sin desenfoque el relleno va más opaco, para que el texto se lea
        // igual de bien sobre la rama.
        final colores = c.oscuro
            ? (ahorro
                ? const [Color(0xD92A2622), Color(0xCC1F1C19)]
                : const [Color(0x33FFFFFF), Color(0x14FFFFFF)])
            : (ahorro
                ? const [Color(0xD9FFFFFF), Color(0xBFFFFFFF)]
                : const [Color(0xA6FFFFFF), Color(0x59FFFFFF)]);
        final contenido = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: forma,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colores),
            // El brillo de la orilla (más fuerte arriba, como la luz).
            border: Border.all(color: c.oscuro ? const Color(0x2EFFFFFF) : const Color(0xE6FFFFFF), width: 1.2),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: forma,
            boxShadow: [
              BoxShadow(
                color: c.oscuro ? const Color(0x59000000) : const Color(0x12000000),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: forma,
            child: ahorro
                ? contenido
                : BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: contenido),
          ),
        );
      },
    );
  }
}
