// ─────────────────────────────────────────────────────────────────────────────
// rama_ciruelo.dart — Rama de ciruelo en flor (梅花) al estilo tinta china
//
// Ilustración original, dibujada por código (sin imágenes con derechos):
//   · La rama: tramos de tinta que se adelgazan hacia las puntas, con vetas
//     de pincel seco (飞白) y puntos de musgo (苔点), como en la pintura china.
//   · Las flores: 5 pétalos carmín con estambres; abiertas, ladeadas y botones.
//   · Viento: cada tramo gira un poco respecto a su rama madre; las puntas se
//     mueven más (hasta ~13 px) y con retraso, como una ola suave.
//   · Pétalos que se desprenden y caen girando.
//
// Rendimiento y batería:
//   · Flores y pétalos se dibujan UNA vez en una imagen pequeña (sprites) y
//     luego se estampan todos con una sola llamada (drawAtlas).
//   · La animación la controla widgets/fondo_tinta.dart a ~30 cuadros/s y se
//     detiene sola (ver ahí).
//   · Coordenadas en "anchos de rama" (1 = ancho de pantalla en un teléfono
//     vertical), así se ve igual en cualquier pantalla.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

// ── Datos de la ilustración ──────────────────────────────────────────────────

/// Extremo de cada tramo en reposo: (id, padre, x, y, grosor).
const _nodos = <(String, String?, double, double, double)>[
  ('R', null, -0.10, 0.20, 0.052),
  ('A', 'R', 0.07, 0.150, 0.042),
  ('B', 'A', 0.20, 0.205, 0.032),
  ('C', 'B', 0.36, 0.150, 0.023),
  ('D', 'C', 0.50, 0.215, 0.016),
  ('E', 'D', 0.62, 0.175, 0.011),
  ('F', 'E', 0.73, 0.235, 0.006),
  ('G', 'B', 0.25, 0.100, 0.014),
  ('H', 'G', 0.31, 0.030, 0.006),
  ('I', 'C', 0.43, 0.080, 0.010),
  ('J', 'I', 0.50, 0.040, 0.005),
  ('K', 'A', 0.06, 0.305, 0.026),
  ('L', 'K', 0.135, 0.420, 0.015),
  ('M', 'L', 0.105, 0.530, 0.007),
  ('N', 'D', 0.555, 0.310, 0.008),
  ('O', 'N', 0.60, 0.365, 0.004),
  ('P', 'K', 0.012, 0.400, 0.007),
  ('Q', 'E', 0.68, 0.110, 0.005),
];

/// Ramas que se dibujan como un solo trazo continuo (de la base a la punta).
const _cadenas = [
  ['R', 'A', 'B', 'C', 'D', 'E', 'F'],
  ['B', 'G', 'H'],
  ['C', 'I', 'J'],
  ['A', 'K', 'L', 'M'],
  ['D', 'N', 'O'],
  ['K', 'P'],
  ['E', 'Q'],
];

/// Flores: (tramo, posición en el tramo 0-1, separación perpendicular, radio,
/// giro, tipo). Tipo: 0 = abierta, 1 = ladeada, 2 = botón.
const _flores = <(String, double, double, double, double, int)>[
  ('F', 1.00, 0.000, 0.034, 0.3, 0), ('F', 0.55, -0.020, 0.030, 1.2, 0), ('E', 0.40, 0.022, 0.026, 2.0, 1),
  ('Q', 1.00, 0.000, 0.022, 0.0, 2), ('Q', 0.45, 0.015, 0.030, 0.7, 0), ('D', 0.70, -0.022, 0.034, 2.4, 0),
  ('O', 1.00, 0.000, 0.028, 0.1, 0), ('N', 0.40, 0.018, 0.020, 0.0, 2), ('J', 1.00, 0.000, 0.026, 0.9, 0),
  ('I', 0.50, -0.018, 0.032, 1.7, 0), ('C', 0.60, 0.024, 0.028, 0.4, 1), ('H', 1.00, 0.000, 0.020, 0.0, 2),
  ('H', 0.50, 0.018, 0.032, 2.9, 0), ('G', 0.40, -0.020, 0.024, 0.0, 2), ('B', 0.55, 0.028, 0.036, 1.1, 0),
  ('M', 1.00, 0.000, 0.024, 0.0, 2), ('M', 0.40, 0.020, 0.032, 0.6, 0), ('L', 0.55, -0.024, 0.030, 2.2, 1),
  ('P', 1.00, 0.000, 0.026, 1.4, 0), ('K', 0.50, 0.026, 0.034, 0.2, 0), ('A', 0.75, -0.026, 0.020, 0.0, 2),
  ('D', 0.20, 0.020, 0.022, 0.0, 2), ('E', 0.85, -0.018, 0.024, 0.5, 1),
];

/// Punto fijo de la raíz (fuera de la pantalla, a la izquierda).
const _base = Offset(-0.22, 0.20);

// ── Geometría ────────────────────────────────────────────────────────────────

class _Geometria {
  _Geometria() {
    final porId = {for (var i = 0; i < _nodos.length; i++) _nodos[i].$1: i};
    padre = [for (final n in _nodos) n.$2 == null ? -1 : porId[n.$2]!];
    indice = porId;
    largo = List.filled(_nodos.length, 0);
    for (var i = 0; i < _nodos.length; i++) {
      final p = padre[i];
      if (p < 0) continue;
      largo[i] = largo[p] + math.sqrt(math.pow(_nodos[i].$3 - _nodos[p].$3, 2) + math.pow(_nodos[i].$4 - _nodos[p].$4, 2));
    }
    // Curvatura propia de cada tramo (le quita lo recto); fija, con semilla.
    final azar = math.Random(7);
    curva = [for (var i = 0; i < _nodos.length; i++) (azar.nextDouble() - 0.5) * 0.35];
  }

  late final Map<String, int> indice;
  late final List<int> padre;
  late final List<double> largo;
  late final List<double> curva;

  static double viento(double t) =>
      0.55 * math.sin(0.85 * t) + 0.30 * math.sin(1.9 * t + 1.3) + 0.15 * math.sin(4.3 * t + 0.4);

  /// Posición del extremo de cada tramo y su giro, en el instante [t].
  /// [fuerza] 0 = en reposo, 1 = brisa normal.
  (List<Offset>, List<double>) posiciones(double t, double fuerza) {
    final pos = <Offset>[];
    final ang = <double>[];
    for (var i = 0; i < _nodos.length; i++) {
      final n = _nodos[i];
      final p = padre[i];
      final inicio = p < 0 ? _base : pos[p];
      final reposo = p < 0 ? _base : Offset(_nodos[p].$3, _nodos[p].$4);
      final vx = n.$3 - reposo.dx, vy = n.$4 - reposo.dy;
      final d = largo[i];
      // Poco giro en lo grueso, más en las puntas; con retraso a lo largo.
      final giro = (p < 0 ? 0.0 : ang[p]) + fuerza * (0.004 + 0.022 * d) * viento(t - 0.9 * d);
      final c = math.cos(giro), s = math.sin(giro);
      pos.add(Offset(inicio.dx + c * vx - s * vy, inicio.dy + s * vx + c * vy));
      ang.add(giro);
    }
    return (pos, ang);
  }

  /// Dónde va una flor (unidades de rama).
  Offset puntoFlor((String, double, double, double, double, int) f, List<Offset> pos) {
    final i = indice[f.$1]!;
    final p = padre[i];
    final ini = p < 0 ? _base : pos[p];
    final fin = pos[i];
    final d = fin - ini;
    final l = d.distance == 0 ? 1.0 : d.distance;
    return Offset(ini.dx + d.dx * f.$2 - d.dy / l * f.$3, ini.dy + d.dy * f.$2 + d.dx / l * f.$3);
  }
}

final _geo = _Geometria();

// ── Sprites (flores y pétalos), dibujados una sola vez ──────────────────────

/// Imagen con los dibujos de flores y pétalos, para estamparlos rápido.
/// Celdas: 0 abierta, 1 ladeada, 2 botón, 3-7 pétalo girando (de frente a
/// de canto).
class SpritesCiruelo {
  SpritesCiruelo._();

  static const double celda = 128;
  static ui.Image? _imagen;
  static Future<ui.Image>? _cargando;

  /// La imagen, si ya está lista.
  static ui.Image? get imagen => _imagen;

  /// Avisa cuando la imagen queda lista (para volver a pintar).
  static final listos = ValueNotifier<bool>(false);

  /// Prepara la imagen (una vez). Se llama al arrancar la app.
  static Future<ui.Image> cargar() => _cargando ??= _dibujar().then((imagen) {
        _imagen = imagen;
        listos.value = true;
        return imagen;
      });

  static Rect rect(int sprite) => Rect.fromLTWH(sprite * celda, 0, celda, celda);

  static Future<ui.Image> _dibujar() {
    final grabadora = ui.PictureRecorder();
    final c = Canvas(grabadora);
    const k = celda;

    // 0: flor abierta
    _florAbierta(c, const Offset(k * 0.5, k * 0.5), k * 0.48, 0);

    // 1: flor ladeada (la abierta vista en perspectiva) con su cáliz
    {
      const centro = Offset(k * 1.5, k * 0.46);
      const r = k * 0.44;
      _caliz(c, centro + const Offset(0, r * 0.32), r * 0.9);
      c.save();
      c.translate(centro.dx, centro.dy);
      c.scale(1, 0.6);
      c.translate(-centro.dx, -centro.dy);
      _florAbierta(c, centro, r, 0.3);
      c.restore();
    }

    // 2: botón
    {
      const centro = Offset(k * 2.5, k * 0.55);
      const r = k * 0.36;
      _caliz(c, centro + const Offset(0, r * 0.45), r * 1.1);
      final pintura = Paint()
        ..shader = ui.Gradient.radial(
          centro,
          r,
          const [Color(0xFFF2A2AE), Color(0xFFC92F49), Color(0xFF8E1830)],
          const [0, 0.6, 1],
          TileMode.clamp,
          null,
          centro + const Offset(-r * 0.3, -r * 0.35), // brillo arriba a la izquierda
          r * 0.1,
        );
      c.drawCircle(centro, r * 0.75, pintura);
    }

    // 3-7: pétalo suelto girando (ancho = coseno del volteo)
    const anchos = [1.0, 0.8, 0.55, 0.3, 0.12];
    for (var i = 0; i < anchos.length; i++) {
      c.save();
      c.translate(k * (3.5 + i), k * 0.5);
      c.scale(anchos[i], 1);
      _petalo(c, Offset.zero, 0, k * 0.32, claro: i >= 3);
      c.restore();
    }

    return grabadora.endRecording().toImage((k * 8).round(), k.round());
  }

  static void _florAbierta(Canvas c, Offset centro, double r, double giro) {
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2 - math.pi / 2 + giro;
      _petalo(c, centro + Offset(math.cos(a), math.sin(a)) * (r * 0.48), a + math.pi / 2, r * 0.52);
    }
    _estambres(c, centro, r);
  }

  /// Pétalo redondo de ciruelo, con la base angosta y más oscura.
  static void _petalo(Canvas c, Offset centro, double giro, double r, {bool claro = false}) {
    c.save();
    c.translate(centro.dx, centro.dy);
    c.rotate(giro);
    final pintura = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * 1.15,
        claro
            ? const [Color(0xFFE9A3AD), Color(0xFFF4C6CC), Color(0xFFFBE3E6)]
            : const [Color(0xFF9E2238), Color(0xFFCF4A60), Color(0xFFF2B0BA)],
        const [0, 0.5, 1],
        TileMode.clamp,
        null,
        Offset(0, r * 0.9), // foco en la base del pétalo
        r * 0.05,
      );
    final forma = Path()
      ..moveTo(0, r * 0.95)
      ..cubicTo(-r * 1.05, r * 0.35, -r * 0.95, -r * 0.95, 0, -r * 0.9)
      ..cubicTo(r * 0.95, -r * 0.95, r * 1.05, r * 0.35, 0, r * 0.95)
      ..close();
    c.drawPath(forma, pintura);
    c.restore();
  }

  static void _estambres(Canvas c, Offset centro, double r) {
    final linea = Paint()
      ..color = const Color(0xBF461419)
      ..strokeWidth = r * 0.035;
    final amarillo = Paint()..color = const Color(0xFFE7C45A);
    final oscuro = Paint()..color = const Color(0xFF3A1D14);
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2 + (i % 2) * 0.2;
      final l = r * (0.42 + 0.14 * ((i * 7) % 3) / 2);
      final punta = centro + Offset(math.cos(a), math.sin(a)) * l;
      c.drawLine(centro, punta, linea);
      c.drawCircle(punta, r * 0.055, i % 3 == 0 ? amarillo : oscuro);
    }
    c.drawCircle(centro, r * 0.12, Paint()..color = const Color(0xFFC9A24A));
  }

  static void _caliz(Canvas c, Offset centro, double r) {
    final pintura = Paint()..color = const Color(0xE6602424);
    for (var i = -1; i <= 1; i++) {
      c.save();
      c.translate(centro.dx, centro.dy);
      c.rotate(i * 0.7);
      c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.33), width: r * 0.26, height: r * 0.54), pintura);
      c.restore();
    }
  }
}

// ── Pétalos que caen ─────────────────────────────────────────────────────────

class _Petalo {
  _Petalo(this.x, this.y, math.Random azar, this.nace)
      : vy = 0.022 + azar.nextDouble() * 0.02,
        giro = azar.nextDouble() * 6.28,
        vGiro = (azar.nextDouble() - 0.5) * 2.4,
        volteo = azar.nextDouble() * 6.28,
        vVolteo = 1.5 + azar.nextDouble() * 2.5,
        vida = 9 + azar.nextDouble() * 6,
        fase = azar.nextDouble() * 6.28;

  double x, y;
  final double vy, giro, vGiro, volteo, vVolteo, vida, fase, nace;
}

/// Estado de la animación: tiempo, fuerza del viento y pétalos en el aire.
/// fondo_tinta.dart lo avanza; cada avance vuelve a pintar la rama.
class VientoCiruelo extends ChangeNotifier {
  static const maxPetalos = 9;

  final _azar = math.Random(11);
  final _petalos = <_Petalo>[];
  double _t = 0;
  double _fuerza = 0;

  /// Hacia dónde va la fuerza (1 = brisa, 0 = calma); cambia suave.
  double objetivo = 1;

  double get fuerza => _fuerza;

  /// Segundos de animación transcurridos.
  double get t => _t;

  /// Cuántos pétalos van cayendo ahora.
  int get petalosEnElAire => _petalos.length;

  /// true cuando ya no se mueve nada (se puede dejar de animar).
  bool get quieto => _fuerza < 0.01 && objetivo == 0 && _petalos.isEmpty;

  /// Altura visible en unidades de rama (para saber cuándo un pétalo salió).
  double alturaVisible = 2.2;

  void avanzar(double dt) {
    _t += dt;
    _fuerza += (objetivo - _fuerza) * math.min(1, dt * 0.8);
    if (objetivo == 0 && _fuerza < 0.01) _fuerza = 0;

    _petalos.removeWhere((p) => _t - p.nace > p.vida || p.y > alturaVisible + 0.1);
    if (_fuerza > 0.3 && _petalos.length < maxPetalos && _azar.nextDouble() < dt * 0.9) {
      final (pos, _) = _geo.posiciones(_t, _fuerza);
      final f = _flores[_azar.nextInt(_flores.length)];
      final q = _geo.puntoFlor(f, pos);
      _petalos.add(_Petalo(q.dx, q.dy, _azar, _t));
    }
    final v = _Geometria.viento(_t);
    for (final p in _petalos) {
      final vx = 0.012 * v * math.max(_fuerza, 0.3) + 0.006 * math.sin(1.3 * (_t - p.nace) + p.fase);
      p.x += vx * dt;
      p.y += p.vy * dt;
    }
    notifyListeners();
  }
}

// ── Dibujo ───────────────────────────────────────────────────────────────────

/// Escala de la rama: el ancho de la pantalla, sin pasar de ~55 % del alto
/// (en horizontal o en tabletas anchas la rama no tapa todo).
double escalaRama(Size tamano) => math.min(tamano.width, tamano.height * 0.55);

/// Dibuja la rama (y las flores, si los sprites ya están listos).
/// [tenue]: versión clara y quieta para las demás pantallas.
void dibujarRama(Canvas canvas, Size tamano, {double t = 0, double fuerza = 0, bool tenue = false, VientoCiruelo? viento}) {
  final s = escalaRama(tamano);
  viento?.alturaVisible = tamano.height / s;
  final (pos, ang) = _geo.posiciones(t, fuerza);
  Offset px(Offset q) => q * s;

  _dibujarTinta(canvas, s, pos, px, tenue);

  final sprites = SpritesCiruelo.imagen;
  if (sprites == null) return;
  final transformaciones = <RSTransform>[];
  final rects = <Rect>[];
  final colores = <Color>[];
  const anclaje = SpritesCiruelo.celda / 2;
  final alfaFlor = tenue ? 0.22 : 1.0;

  for (var k = 0; k < _flores.length; k++) {
    final f = _flores[k];
    final q = px(_geo.puntoFlor(f, pos));
    final giro = f.$5 + ang[_geo.indice[f.$1]!] + 0.08 * fuerza * math.sin(1.7 * t + k);
    final escala = f.$4 * s * 2 / SpritesCiruelo.celda;
    transformaciones.add(RSTransform.fromComponents(
        rotation: giro, scale: escala, anchorX: anclaje, anchorY: anclaje, translateX: q.dx, translateY: q.dy));
    rects.add(SpritesCiruelo.rect(f.$6));
    colores.add(Color.fromRGBO(255, 255, 255, alfaFlor));
  }

  if (viento != null) {
    for (final p in viento._petalos) {
      final edad = viento._t - p.nace;
      final alfa = (math.min(1.0, edad / 0.8) * math.min(1.0, (p.vida - edad) / 1.5) * 0.8).clamp(0.0, 1.0).toDouble();
      if (alfa <= 0) continue;
      // Volteo: el pétalo se ve de frente o de canto según el giro.
      final ancho = math.cos(p.volteo + p.vVolteo * edad).abs();
      final cuadro = (5 - ancho * 5).floor().clamp(0, 4).toInt();
      final q = px(Offset(p.x, p.y));
      transformaciones.add(RSTransform.fromComponents(
          rotation: p.giro + p.vGiro * edad,
          scale: 0.026 * s * 2 / SpritesCiruelo.celda,
          anchorX: anclaje,
          anchorY: anclaje,
          translateX: q.dx,
          translateY: q.dy));
      rects.add(SpritesCiruelo.rect(3 + cuadro));
      colores.add(Color.fromRGBO(255, 255, 255, alfa));
    }
  }

  canvas.drawAtlas(sprites, transformaciones, rects, colores, BlendMode.modulate, null,
      Paint()..filterQuality = FilterQuality.medium);
}

void _dibujarTinta(Canvas canvas, double s, List<Offset> pos, Offset Function(Offset) px, bool tenue) {
  final vetas = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFF5EEE4).withValues(alpha: tenue ? 0.05 : 0.13);

  for (final cadena in _cadenas) {
    final puntos = <Offset>[];
    final anchos = <double>[];
    final raiz = cadena.first == 'R';
    for (var k = 1; k < cadena.length; k++) {
      final i0 = _geo.indice[cadena[k - 1]]!, i1 = _geo.indice[cadena[k]]!;
      final ini = px(k == 1 && raiz ? _base : pos[i0]);
      final fin = px(pos[i1]);
      final w0 = (k == 1
              ? (raiz ? _nodos[i0].$5 * 1.2 : math.min(_nodos[i0].$5 * 0.8, _nodos[i1].$5 * 1.6))
              : _nodos[i0].$5) *
          s;
      final w1 = _nodos[i1].$5 * s;
      final d = fin - ini;
      final l = d.distance == 0 ? 1.0 : d.distance;
      final c = _geo.curva[i1];
      final medio = Offset((ini.dx + fin.dx) / 2 - d.dy / l * c * l, (ini.dy + fin.dy) / 2 + d.dx / l * c * l);
      const n = 10;
      for (var j = (k == 1 ? 0 : 1); j <= n; j++) {
        final u = j / n, v = 1 - u;
        puntos.add(ini * (v * v) + medio * (2 * u * v) + fin * (u * u));
        anchos.add(w0 + (w1 - w0) * u);
      }
    }

    // Contorno con normales promediadas (sin huecos en las uniones) y borde
    // un poco irregular, como de pincel.
    final izquierda = <Offset>[], derecha = <Offset>[], normales = <Offset>[];
    for (var j = 0; j < puntos.length; j++) {
      final d = puntos[math.min(puntos.length - 1, j + 1)] - puntos[math.max(0, j - 1)];
      final l = d.distance == 0 ? 1.0 : d.distance;
      final normal = Offset(-d.dy / l, d.dx / l);
      normales.add(normal);
      final w = anchos[j] / 2;
      final r1 = 1 + 0.12 * math.sin(j * 1.7 + cadena.length), r2 = 1 + 0.12 * math.sin(j * 2.3 + 1);
      izquierda.add(puntos[j] + normal * (w * r1));
      derecha.add(puntos[j] - normal * (w * r2));
    }
    final contorno = Path()..moveTo(izquierda.first.dx, izquierda.first.dy);
    for (final q in izquierda.skip(1)) {
      contorno.lineTo(q.dx, q.dy);
    }
    contorno.lineTo(puntos.last.dx, puntos.last.dy);
    for (final q in derecha.reversed) {
      contorno.lineTo(q.dx, q.dy);
    }
    contorno.close();

    // Tinta opaca (sin oscurecerse donde se cruzan ramas), más oscura en lo grueso.
    final tinta = Paint()
      ..shader = ui.Gradient.linear(
        puntos.first,
        puntos.last,
        tenue ? const [Color(0x1F241D19), Color(0x1A463C35)] : const [Color(0xFF241D19), Color(0xFF463C35)],
      );
    canvas.drawPath(contorno, tinta);
    if (!raiz) canvas.drawCircle(puntos.first, anchos.first / 2, tinta); // inicio redondeado

    // Pincel seco (飞白): vetas claras cortadas a lo largo del trazo.
    vetas.strokeWidth = math.max(0.5, anchos.first * 0.05);
    for (final desp in const [-0.2, 0.25]) {
      final veta = Path();
      var dibujando = false;
      for (var j = 0; j < puntos.length; j++) {
        if (anchos[j] < 0.012 * s) continue;
        final q = puntos[j] - normales[j] * (anchos[j] * desp);
        if (math.sin(j * 0.55 + desp * 10) > 0.1) {
          if (dibujando) {
            veta.lineTo(q.dx, q.dy);
          } else {
            veta.moveTo(q.dx, q.dy);
          }
          dibujando = true;
        } else {
          dibujando = false;
        }
      }
      canvas.drawPath(veta, vetas);
    }
  }

  // Puntos de musgo (苔点) sobre los tramos gruesos.
  final musgo = Paint()..color = tenue ? const Color(0x22191410) : const Color(0xD9191410);
  for (var i = 0; i < _nodos.length; i++) {
    final p = _geo.padre[i];
    final g = _nodos[i].$5;
    if (p < 0 || g < 0.012) continue;
    final ini = px(pos[p]), fin = px(pos[i]);
    for (var k = 0; k < 3; k++) {
      final u = 0.25 + 0.25 * k;
      final centro = ini + (fin - ini) * u - Offset(0, g * s * 0.55);
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.rotate(0.4);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: g * s * 0.26, height: g * s * 0.18), musgo);
      canvas.restore();
    }
  }
}
