// ─────────────────────────────────────────────────────────────────────────────
// capa_fija.dart — Dibujar una vez, copiar en cada cuadro
//
// Con el motor gráfico de Flutter (Impeller) no hay caché de capas: mientras
// algo se mueve en pantalla (por ejemplo, tu trazo en el lienzo, a 120 Hz),
// TODO lo visible se vuelve a dibujar en cada cuadro, incluidas las partes
// que nunca cambian: la cuadrícula 米字格 (unas 100 líneas punteadas) y la
// silueta del carácter (contornos con muchas curvas).
//
// CapaFija dibuja esas partes UNA vez en una imagen del tamaño exacto de la
// pantalla (en píxeles reales) y en cada cuadro solo la copia: menos trabajo
// para el procesador y la tarjeta gráfica = menos batería mientras practicas.
// Se vuelve a dibujar solo si cambia [clave] o el tamaño.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class CapaFija extends StatefulWidget {
  const CapaFija({super.key, required this.clave, required this.pintor});

  /// Cuando cambia, la imagen se vuelve a dibujar (p. ej. otro carácter).
  final Object clave;
  final CustomPainter pintor;

  @override
  State<CapaFija> createState() => _CapaFijaState();
}

class _CapaFijaState extends State<CapaFija> {
  final _cache = _Cache();

  @override
  void didUpdateWidget(CapaFija old) {
    super.didUpdateWidget(old);
    if (old.clave != widget.clave) _cache.limpiar();
  }

  @override
  void dispose() {
    _cache.limpiar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _PintorCacheado(widget.pintor, _cache, MediaQuery.devicePixelRatioOf(context), widget.clave),
      );
}

class _Cache {
  ui.Image? imagen;
  Size? tamano;
  double dpr = 0;

  void limpiar() {
    imagen?.dispose();
    imagen = null;
    tamano = null;
  }
}

class _PintorCacheado extends CustomPainter {
  _PintorCacheado(this.pintor, this.cache, this.dpr, this.clave);

  final CustomPainter pintor;
  final _Cache cache;
  final double dpr;
  final Object clave;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (cache.imagen == null || cache.tamano != size || cache.dpr != dpr) {
      final grabadora = ui.PictureRecorder();
      final c = Canvas(grabadora)..scale(dpr);
      pintor.paint(c, size);
      cache.imagen?.dispose();
      try {
        cache.imagen =
            grabadora.endRecording().toImageSync((size.width * dpr).ceil(), (size.height * dpr).ceil());
      } catch (_) {
        // Si el motor no puede crear la imagen, se dibuja directo (sin caché).
        cache.imagen = null;
        pintor.paint(canvas, size);
        return;
      }
      cache.tamano = size;
      cache.dpr = dpr;
    }
    final imagen = cache.imagen!;
    canvas.drawImageRect(
      imagen,
      Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble()),
      Rect.fromLTWH(0, 0, imagen.width / dpr, imagen.height / dpr),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_PintorCacheado old) => old.clave != clave || old.dpr != dpr || !identical(old.cache, cache);
}

/// Varios pintores, uno encima de otro (para juntarlos en una sola capa fija).
class PintoresJuntos extends CustomPainter {
  const PintoresJuntos(this.pintores);

  final List<CustomPainter> pintores;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pintores) {
      p.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(PintoresJuntos old) => true;
}
