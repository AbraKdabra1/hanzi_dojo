import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../database/db_helper.dart';
import '../helpers/pinyin_helper.dart';
import '../helpers/dtw_helper.dart';
import '../painters/grid_painter.dart';
import '../painters/svg_fondo_painter.dart';
import '../painters/pista_roja_painter.dart';
import '../painters/pincel_painter.dart';
import '../painters/trazo_guia_painter.dart';
import '../widgets/glass_speaker_button.dart';
import '../widgets/fondo_tinta.dart';

class PantallaEstudio extends StatefulWidget {
  final int nivelHSK;
  final int? hanziIdBuscado;
  final bool modoNovato;
  final bool modoRadical;

  const PantallaEstudio({
    super.key,
    required this.nivelHSK,
    this.hanziIdBuscado,
    this.modoNovato  = false,
    this.modoRadical = false,
  });

  @override
  State<PantallaEstudio> createState() => _PantallaEstudioState();
}

class _PantallaEstudioState extends State<PantallaEstudio>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _hanziActual;
  final List<List<PointVector>> _trazosUsuario = [];

  int  _trazoCorrectoActual = 0;
  bool _mostrarPistaError   = false;
  bool _hanziCompletado     = false;
  bool _esBusquedaInicial   = true;
  bool _mostrarExito        = false;
  bool _mostrarGuia         = false;

  late AnimationController _guiaController;
  late Animation<double>   _guiaAnimation;

  @override
  void initState() {
    super.initState();
    _guiaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _guiaAnimation = CurvedAnimation(
      parent: _guiaController,
      curve: Curves.easeInOut,
    );
    _siguienteHanzi();
  }

  @override
  void dispose() {
    _guiaController.dispose();
    super.dispose();
  }

  // ── Helpers para el nuevo esquema ────────────────────────────────────────

  /// Carácter actual (campo 'caracter' en el nuevo esquema)
  String get _caracter => _hanziActual?['caracter'] ?? '';

  /// Verifica si hay medianas válidas (ahora es string JSON en la DB)
  bool get _tieneMedianas {
    final m = _hanziActual?['medianas'];
    if (m == null) return false;
    try {
      final decoded = m is String ? jsonDecode(m) : m;
      return decoded is List && decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Decodifica medianas de forma segura
  List<dynamic> get _medianasDecodificadas {
    final m = _hanziActual?['medianas'];
    if (m == null) return [];
    try {
      return m is String ? jsonDecode(m) : (m as List);
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _siguienteHanzi() async {
    Map<String, dynamic>? hanzi;

    if (widget.hanziIdBuscado != null && _esBusquedaInicial) {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('caracteres',
          where: 'id = ?', whereArgs: [widget.hanziIdBuscado]);
      if (res.isNotEmpty) hanzi = res.first;
      _esBusquedaInicial = false;
    } else if (widget.modoRadical) {
      hanzi = await DatabaseHelper.instance.obtenerSiguienteRadicalParaEstudiar();
    } else {
      hanzi = await DatabaseHelper.instance
          .obtenerSiguienteHanziParaEstudiar(widget.nivelHSK);
    }

    if (mounted) {
      setState(() {
        _hanziActual         = hanzi;
        _trazosUsuario.clear();
        _trazoCorrectoActual = 0;
        _mostrarPistaError   = false;
        _hanziCompletado     = false;
        _mostrarExito        = false;
        _mostrarGuia         = false;
        if (_hanziActual != null && !_tieneMedianas) {
          _hanziCompletado = true;
        }
      });
      _guiaController.reset();
    }
  }

  void _evaluar(int calificacion) async {
    if (_hanziActual != null) {
      await DatabaseHelper.instance
          .actualizarProgresoSRS(_hanziActual!['id'], calificacion);
    }
    _siguienteHanzi();
  }

  void _limpiarLienzo() {
    setState(() {
      _trazosUsuario.clear();
      _trazoCorrectoActual = 0;
      _hanziCompletado     = false;
      _mostrarExito        = false;
      _mostrarGuia         = false;
    });
    _guiaController.reset();
  }

  // ✅ Ahora consulta tabla 'ejemplos' con caracter_id
  void _mostrarModalEjemplos(int hanziId) async {
    final db = await DatabaseHelper.instance.database;
    final lista = await db.query(
      'ejemplos',
      where: 'caracter_id = ?',
      whereArgs: [hanziId],
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModalEjemplos(
        ejemplos: lista,
        caracter: _caracter,
      ),
    );
  }

  void _mostrarAnimacionGuia() {
    if (!widget.modoNovato) return;
    setState(() => _mostrarGuia = true);
    _guiaController.forward(from: 0).then((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _mostrarGuia = false);
        });
      }
    });
  }

  void _auditarTrazo(Size canvasSize) {
    if (_hanziActual == null || !_tieneMedianas) return;

    final List<dynamic> medians = _medianasDecodificadas;
    if (_trazoCorrectoActual >= medians.length) return;

    final double sx   = (canvasSize.width  * 0.9) / 1024;
    final double sy   = (canvasSize.height * 0.9) / 1024;
    final double offX = canvasSize.width  * 0.05;
    final double offY = canvasSize.height * 0.05;

    final List<Offset> trazoEsperado =
        (medians[_trazoCorrectoActual] as List).map<Offset>((p) {
      return Offset(
        offX + p[0].toDouble() * sx,
        offY + (1024 - p[1].toDouble()) * sy,
      );
    }).toList();

    final ultimoTrazo = _trazosUsuario.last;
    if (ultimoTrazo.length < 5) return;

    final List<Offset> trazoUsuario =
        ultimoTrazo.map((pv) => Offset(pv.dx, pv.dy)).toList();

    final double costo  = DTWHelper.calcular(trazoUsuario, trazoEsperado);
    final double umbral = canvasSize.width * 0.28;

    if (costo <= umbral) {
      HapticFeedback.lightImpact();
      setState(() {
        _mostrarExito = true;
        _trazoCorrectoActual++;
        if (_trazoCorrectoActual >= medians.length) _hanziCompletado = true;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _mostrarExito = false);
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _mostrarPistaError = true);
      _mostrarAnimacionGuia();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            if (_trazosUsuario.isNotEmpty) _trazosUsuario.removeLast();
            _mostrarPistaError = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titulo = widget.modoRadical
        ? 'Radicales Kangxi'
        : 'Estudiando HSK ${widget.nivelHSK}';

    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            children: [
              Text(titulo,
                  style: const TextStyle(color: Colors.black87, fontSize: 16)),
              Text(widget.modoNovato ? '🐣 Novato' : '🥋 Experto',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black54),
              onPressed: _limpiarLienzo,
              tooltip: "Reiniciar trazos",
            ),
          ],
        ),
        body: _hanziActual == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black))
            : Column(
                children: [
                  // ── Panel superior ────────────────────────────────────
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: PinyinHelper.formatearConColores(
                                      _hanziActual!['pinyin'])
                                  .map((par) => TextSpan(
                                        text: par.$1,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'SFPro',
                                        ).copyWith(color: par.$2),
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // ✅ CAMBIO: _caracter en lugar de ['simplificado']
                          GlassSpeakerButton(textoALeer: _caracter),
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: InkWell(
                                  onTap: () => _mostrarModalEjemplos(
                                      _hanziActual!['id'] as int),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0x99E3F2FD),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0x6690CAF9),
                                          width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.menu_book_rounded,
                                            color: Colors.blue.shade700,
                                            size: 16),
                                        const SizedBox(width: 6),
                                        Text("Ver ejemplos",
                                            style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Lienzo ────────────────────────────────────────────
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 10))
                            ],
                            border: Border.all(
                                color: Color(0xFFE0E0E0), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final canvasSize = Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight);

                                final List<String> vectores =
                                    _hanziActual!['trazos'] != null
                                        ? List<String>.from(jsonDecode(
                                            _hanziActual!['trazos']))
                                        : [];

                                // Mediana actual para guía
                                List<Offset> medianaActual = [];
                                if (widget.modoNovato && _tieneMedianas) {
                                  final meds = _medianasDecodificadas;
                                  if (_trazoCorrectoActual < meds.length) {
                                    final double sx2 =
                                        (canvasSize.width * 0.9) / 1024;
                                    final double sy2 =
                                        (canvasSize.height * 0.9) / 1024;
                                    final double ox = canvasSize.width * 0.05;
                                    final double oy = canvasSize.height * 0.05;
                                    medianaActual =
                                        (meds[_trazoCorrectoActual] as List)
                                            .map<Offset>((p) => Offset(
                                                  ox + p[0].toDouble() * sx2,
                                                  oy +
                                                      (1024 -
                                                              p[1].toDouble()) *
                                                          sy2,
                                                ))
                                            .toList();
                                  }
                                }

                                return Stack(
                                  children: [
                                    Positioned.fill(
                                        child: CustomPaint(
                                            painter: GridPainter())),
                                    if (vectores.isNotEmpty)
                                      Positioned.fill(
                                        child: CustomPaint(
                                            painter: SvgFondoPainter(vectores)),
                                      ),
                                    if (vectores.isNotEmpty &&
                                        _trazoCorrectoActual < vectores.length)
                                      Positioned.fill(
                                        child: AnimatedOpacity(
                                          opacity:
                                              _mostrarPistaError ? 1.0 : 0.0,
                                          duration: const Duration(
                                              milliseconds: 300),
                                          child: CustomPaint(
                                              painter: PistaRojaPainter(
                                                  vectores[
                                                      _trazoCorrectoActual])),
                                        ),
                                      ),
                                    // Guía animada (solo novato)
                                    if (widget.modoNovato &&
                                        _mostrarGuia &&
                                        medianaActual.isNotEmpty)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: AnimatedBuilder(
                                            animation: _guiaAnimation,
                                            // ✅ CAMBIO: (_, __) corregido
                                            builder: (_, _) => CustomPaint(
                                              painter: TrazoGuiaPainter(
                                                puntos: medianaActual,
                                                progreso: _guiaAnimation.value,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Flash verde
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedOpacity(
                                          opacity: _mostrarExito ? 1.0 : 0.0,
                                          duration: const Duration(
                                              milliseconds: 200),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              color: const Color(0x2200C853),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onPanStart: (d) {
                                          if (_hanziCompletado) return;
                                          setState(() =>
                                              _trazosUsuario.add([
                                                PointVector(
                                                    d.localPosition.dx,
                                                    d.localPosition.dy)
                                              ]));
                                        },
                                        onPanUpdate: (d) {
                                          if (_hanziCompletado) return;
                                          setState(() =>
                                              _trazosUsuario.last.add(
                                                  PointVector(
                                                      d.localPosition.dx,
                                                      d.localPosition.dy)));
                                        },
                                        onPanEnd: (_) {
                                          if (_hanziCompletado) return;
                                          _auditarTrazo(canvasSize);
                                        },
                                        child: CustomPaint(
                                          painter: PincelPainter(_trazosUsuario),
                                          size: Size.infinite,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Botones SRS ───────────────────────────────────────
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _hanziCompletado ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: _hanziCompletado
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _botonSRS('Difícil', Colors.red,    0),
                                    _botonSRS('Medio',   Colors.orange, 3),
                                    _botonSRS('Fácil',   Colors.green,  5),
                                  ],
                                ),
                              )
                            : Text("Dibuja el carácter...",
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _botonSRS(String texto, MaterialColor color, int calificacion) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.shade50,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () => _evaluar(calificacion),
      child: Text(texto,
          style: TextStyle(
              color: color.shade700, fontWeight: FontWeight.w600)),
    );
  }
}

// =========================================================================
// MODAL DE EJEMPLOS — minimalista con columnas
// =========================================================================
class _ModalEjemplos extends StatelessWidget {
  final List<Map<String, dynamic>> ejemplos;
  final String caracter;

  const _ModalEjemplos({
    required this.ejemplos,
    required this.caracter,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF5FFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Título con carácter
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(caracter,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w300)),
                    const SizedBox(width: 12),
                    const Text('Ejemplos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Cabecera de columnas
              if (ejemplos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Row(
                    children: [
                      _Etiqueta('Chino',   flex: 3),
                      _Etiqueta('Pinyin',  flex: 3),
                      _Etiqueta('Español', flex: 4),
                    ],
                  ),
                ),

              // Contenido
              if (ejemplos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'Aún no hay ejemplos para este carácter.',
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    itemCount: ejemplos.length,
                    separatorBuilder: (_, _) => const Divider(
                        height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (_, i) {
                      final e = ejemplos[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                e['oracion_zh'] ?? '',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                e['pinyin'] ?? '',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                e['oracion_es'] ?? '',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final int flex;
  const _Etiqueta(this.texto, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}