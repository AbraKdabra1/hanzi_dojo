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

  void _siguienteHanzi() async {
    Map<String, dynamic>? hanzi;

    if (widget.hanziIdBuscado != null && _esBusquedaInicial) {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('caracteres',
          where: 'id = ?', whereArgs: [widget.hanziIdBuscado]);
      if (res.isNotEmpty) hanzi = res.first;
      _esBusquedaInicial = false;
    } else if (widget.modoRadical) {
      hanzi =
          await DatabaseHelper.instance.obtenerSiguienteRadicalParaEstudiar();
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
        if (_hanziActual != null && _hanziActual!['medianas'] == null) {
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

  void _mostrarModalEjemplos(String hanziSimp) async {
    final db = await DatabaseHelper.instance.database;
    final lista = await db.query('oraciones',
        where: 'hanzi_simp = ?', whereArgs: [hanziSimp]);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30.0),
            child: Text("Aún no hay ejemplos para este carácter.",
                style: TextStyle(fontSize: 16)),
          );
        }
        return ListView.builder(
          itemCount: lista.length,
          itemBuilder: (_, i) {
            final o = lista[i];
            return ListTile(
              title: Text("${o['oracion_simp']}  (${o['pinyin']})",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text("${o['traduccion']}",
                  style: const TextStyle(fontSize: 15)),
            );
          },
        );
      },
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
    if (_hanziActual == null || _hanziActual!['medianas'] == null) return;

    final List<dynamic> medians = jsonDecode(_hanziActual!['medianas']);
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RichText(
                            text: TextSpan(
                              children:
                                  PinyinHelper.formatearConColores(
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
                          GlassSpeakerButton(
                              textoALeer:
                                  _hanziActual!['simplificado']),
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 8, sigmaY: 8),
                                child: InkWell(
                                  onTap: () => _mostrarModalEjemplos(
                                      _hanziActual!['simplificado']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0x99E3F2FD),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              const Color(0x6690CAF9),
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
                                                color:
                                                    Colors.blue.shade700,
                                                fontWeight:
                                                    FontWeight.w600,
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20.0),
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
                                if (widget.modoNovato &&
                                    _hanziActual!['medianas'] != null) {
                                  final meds = jsonDecode(
                                          _hanziActual!['medianas'])
                                      as List;
                                  if (_trazoCorrectoActual <
                                      meds.length) {
                                    final double sx2 =
                                        (canvasSize.width * 0.9) / 1024;
                                    final double sy2 =
                                        (canvasSize.height * 0.9) / 1024;
                                    final double ox =
                                        canvasSize.width * 0.05;
                                    final double oy =
                                        canvasSize.height * 0.05;
                                    medianaActual =
                                        (meds[_trazoCorrectoActual]
                                                as List)
                                            .map<Offset>((p) => Offset(
                                                  ox +
                                                      p[0].toDouble() *
                                                          sx2,
                                                  oy +
                                                      (1024 -
                                                              p[1]
                                                                  .toDouble()) *
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
                                            painter: SvgFondoPainter(
                                                vectores)),
                                      ),
                                    if (vectores.isNotEmpty &&
                                        _trazoCorrectoActual <
                                            vectores.length)
                                      Positioned.fill(
                                        child: AnimatedOpacity(
                                          opacity: _mostrarPistaError
                                              ? 1.0
                                              : 0.0,
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
                                            builder: (_, __) =>
                                                CustomPaint(
                                              painter: TrazoGuiaPainter(
                                                puntos: medianaActual,
                                                progreso:
                                                    _guiaAnimation.value,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Flash verde
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedOpacity(
                                          opacity:
                                              _mostrarExito ? 1.0 : 0.0,
                                          duration: const Duration(
                                              milliseconds: 200),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      13),
                                              color:
                                                  const Color(0x2200C853),
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
                                                      d.localPosition
                                                          .dy)));
                                        },
                                        onPanEnd: (_) {
                                          if (_hanziCompletado) return;
                                          _auditarTrazo(canvasSize);
                                        },
                                        child: CustomPaint(
                                          painter: PincelPainter(
                                              _trazosUsuario),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () => _evaluar(calificacion),
      child: Text(texto,
          style: TextStyle(
              color: color.shade700, fontWeight: FontWeight.w600)),
    );
  }
}