// ─────────────────────────────────────────────────────────────────────────────
// fondo_tinta.dart — Fondo de papel de arroz con manchas de tinta y una rama
// de ciruelo en flor (梅花), detrás de las pantallas principales.
//
// · Pantalla de inicio (ramaAnimada: true): la rama se mece con el viento y
//   suelta pétalos (painters/rama_ciruelo.dart).
// · Demás pantallas: la misma rama, tenue y quieta, para no distraer.
//
// Fluidez: con el motor gráfico de Flutter (Impeller) el fondo se vuelve a
// dibujar en cada cuadro del scroll, así que aquí nada usa desenfoque (antes
// las manchas tenían MaskFilter.blur: era lo que trababa el scroll en todas
// las pantallas). La rama quieta se dibuja una sola vez en una imagen y luego
// solo se copia.
//
// Batería, en la pantalla de inicio:
//   · ~30 cuadros por segundo (no 120): el movimiento es lento y se ve igual.
//   · La brisa dura 30 s; luego se calma y la animación se APAGA (cero
//     consumo). Al tocar la pantalla o al volver al inicio vuelve a soplar.
//   · Se pausa si otra pantalla la tapa, si la app pasa a segundo plano o si
//     el teléfono tiene activado "quitar animaciones" (accesibilidad).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../painters/rama_ciruelo.dart';

/// Envuelve una pantalla con el fondo de papel y tinta.
class FondoTintaChina extends StatelessWidget {
  const FondoTintaChina({super.key, required this.child, this.ramaAnimada = false});

  final Widget child;

  /// true: rama grande que se mece y suelta pétalos (pantalla de inicio).
  final bool ramaAnimada;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F4EE), Color(0xFFF2EDE5)],
            ),
          ),
        ),
        const RepaintBoundary(child: CustomPaint(painter: _ManchasPainter())),
        if (ramaAnimada)
          _RamaAnimada(child: child)
        else ...[
          RepaintBoundary(
            child: CustomPaint(painter: _PintorRamaQuieta(MediaQuery.devicePixelRatioOf(context))),
          ),
          child,
        ],
      ],
    );
  }
}

/// Manchas difusas de tinta café en las orillas. Degradados radiales que se
/// desvanecen solos: suaves sin necesidad de desenfoque.
class _ManchasPainter extends CustomPainter {
  const _ManchasPainter();

  /// [x relativa, y relativa, radio, opacidad]
  static const _manchas = [
    [0.85, 0.08, 90.0, 0.035],
    [0.92, 0.55, 140.0, 0.05],
    [0.05, 0.75, 110.0, 0.04],
    [0.50, 0.92, 130.0, 0.03],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in _manchas) {
      final centro = Offset(size.width * m[0], size.height * m[1]);
      final radio = m[2];
      final pintura = Paint()
        ..shader = RadialGradient(
          colors: [Color.fromRGBO(60, 40, 20, m[3]), const Color(0x003C2814)],
        ).createShader(Rect.fromCircle(center: centro, radius: radio));
      canvas.drawCircle(centro, radio, pintura);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rama tenue y quieta. Se dibuja una vez en una imagen (solo el rincón donde
/// está la rama) y en cada cuadro solo se copia esa imagen.
class _PintorRamaQuieta extends CustomPainter {
  _PintorRamaQuieta(this.dpr) : super(repaint: SpritesCiruelo.listos);

  final double dpr;

  static ui.Image? _imagen;
  static Size? _tamanoImagen;
  static double _dprImagen = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (SpritesCiruelo.imagen == null) {
      // Aún sin flores: se dibuja directo (y no se guarda).
      dibujarRama(canvas, size, tenue: true);
      return;
    }
    final s = escalaRama(size);
    final region = Size(math.min(size.width, 0.82 * s), math.min(size.height, 0.60 * s));
    if (_imagen == null || _tamanoImagen != region || _dprImagen != dpr) {
      final grabadora = ui.PictureRecorder();
      final c = Canvas(grabadora)..scale(dpr);
      dibujarRama(c, size, tenue: true);
      _imagen?.dispose();
      _imagen = grabadora
          .endRecording()
          .toImageSync((region.width * dpr).ceil(), (region.height * dpr).ceil());
      _tamanoImagen = region;
      _dprImagen = dpr;
    }
    final imagen = _imagen!;
    canvas.drawImageRect(
      imagen,
      Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble()),
      Offset.zero & Size(imagen.width / dpr, imagen.height / dpr),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorRamaQuieta old) => old.dpr != dpr;
}

/// Rama que se mece, con pétalos cayendo (pantalla de inicio).
class _RamaAnimada extends StatefulWidget {
  const _RamaAnimada({required this.child});

  final Widget child;

  @override
  State<_RamaAnimada> createState() => _RamaAnimadaState();
}

class _RamaAnimadaState extends State<_RamaAnimada> with WidgetsBindingObserver {
  /// ~30 cuadros por segundo: suficiente para un movimiento lento y gasta
  /// la cuarta parte que a 120.
  static const _cuadro = Duration(milliseconds: 33);

  /// Cuánto sopla la brisa antes de calmarse (y apagar la animación).
  static const _duracionBrisa = Duration(seconds: 30);

  final _viento = VientoCiruelo();
  final _cronometro = Stopwatch();
  Timer? _reloj;
  Duration _anterior = Duration.zero;
  DateTime _calmaEn = DateTime.now();

  bool _visible = true;
  bool _enPrimerPlano = true;
  bool _sinAnimaciones = false;

  bool get _puedeAnimar => _visible && _enPrimerPlano && !_sinAnimaciones;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _calmaEn = DateTime.now().add(_duracionBrisa);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visibleAntes = _visible;
    // false mientras otra pantalla está encima de la de inicio.
    _visible = ModalRoute.of(context)?.isCurrent ?? true;
    _sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    if (_visible && !visibleAntes) {
      _soplar(); // al volver al inicio, vuelve la brisa
    } else {
      _actualizar();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    _actualizar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    _viento.dispose();
    super.dispose();
  }

  void _soplar() {
    _calmaEn = DateTime.now().add(_duracionBrisa);
    _viento.objetivo = 1;
    _actualizar();
  }

  /// Enciende o apaga el reloj de la animación según haga falta.
  void _actualizar() {
    final animar = _puedeAnimar && !_viento.quieto;
    if (animar && _reloj == null) {
      _cronometro
        ..reset()
        ..start();
      _anterior = Duration.zero;
      _reloj = Timer.periodic(_cuadro, _tic);
    } else if (!animar && _reloj != null) {
      _reloj!.cancel();
      _reloj = null;
      _cronometro.stop();
    }
  }

  void _tic(Timer _) {
    final ahora = _cronometro.elapsed;
    final dt = ((ahora - _anterior).inMicroseconds / 1e6).clamp(0.0, 0.1).toDouble();
    _anterior = ahora;
    if (DateTime.now().isAfter(_calmaEn)) _viento.objetivo = 0;
    _viento.avanzar(dt);
    if (_viento.quieto) _actualizar(); // ya no se mueve nada: se apaga
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _PintorRamaAnimada(_viento))),
        // Tocar en cualquier parte hace soplar el viento otra vez.
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _soplar(),
          child: widget.child,
        ),
      ],
    );
  }
}

class _PintorRamaAnimada extends CustomPainter {
  _PintorRamaAnimada(this.viento) : super(repaint: Listenable.merge([viento, SpritesCiruelo.listos]));

  final VientoCiruelo viento;

  @override
  void paint(Canvas canvas, Size size) =>
      dibujarRama(canvas, size, t: viento.t, fuerza: viento.fuerza, viento: viento);

  @override
  bool shouldRepaint(covariant _PintorRamaAnimada old) => old.viento != viento;
}
