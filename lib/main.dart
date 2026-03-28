import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:perfect_freehand/perfect_freehand.dart'; 
import 'database/db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Revisando la bóveda de Hanzi...");
  await DatabaseHelper.instance.poblarBaseDeDatos();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hanzi Dojo',
      theme: ThemeData(
        fontFamily: 'SFPro', 
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const PantallaInicio(),
    );
  }
}

// =========================================================================
// PANTALLA 1: EL HOME MINIMALISTA
// =========================================================================
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 0,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PantallaEstudio()),
            );
          },
          child: const Text(
            'Chino tradicional',
            style: TextStyle(fontSize: 18, letterSpacing: 0.5, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// PANTALLA 2: EL DOJO DE ESTUDIO
// =========================================================================
class PantallaEstudio extends StatefulWidget {
  const PantallaEstudio({super.key});

  @override
  State<PantallaEstudio> createState() => _PantallaEstudioState();
}

class _PantallaEstudioState extends State<PantallaEstudio> {
  Map<String, dynamic>? _hanziActual;
  
  // ¡CORRECCIÓN: Usamos PointVector en lugar de Point!
  final List<List<PointVector>> _trazosUsuario = []; 

  @override
  void initState() {
    super.initState();
    _siguienteHanzi(); 
  }

  void _siguienteHanzi() async {
    final hanzi = await DatabaseHelper.instance.obtenerSiguienteHanziParaEstudiar();
    setState(() {
      _hanziActual = hanzi;
      _trazosUsuario.clear(); 
    });
  }

  void _evaluar(int minutosDeEspera) async {
    if (_hanziActual != null) {
      await DatabaseHelper.instance.actualizarProgresoSRS(
        _hanziActual!['id'], 
        minutosDeEspera
      );
    }
    _siguienteHanzi();
  }

  void _limpiarLienzo() {
    setState(() {
      _trazosUsuario.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context), 
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _limpiarLienzo,
            tooltip: "Limpiar trazos",
          )
        ],
      ),
      body: _hanziActual == null 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _hanziActual!['pinyin'],
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _hanziActual!['significados'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black87, height: 1.4),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

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
                          boxShadow: [
                            // ignore: deprecated_member_use
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
                          ],
                          border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack( 
                            key: ValueKey(_hanziActual!['id']), 
                            children: [
                              Positioned.fill(child: CustomPaint(painter: GridPainter())),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0), 
                                  child: _hanziActual!['trazos'] != null 
                                    ? CustomPaint(painter: SvgHanziPainter(List<String>.from(jsonDecode(_hanziActual!['trazos']))))
                                    : const SizedBox.shrink(),
                                ),
                              ),
                              Positioned.fill(
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    setState(() {
                                      // ¡CORRECCIÓN: Instanciamos PointVector!
                                      _trazosUsuario.add([PointVector(details.localPosition.dx, details.localPosition.dy)]);
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    setState(() {
                                      // ¡CORRECCIÓN: Instanciamos PointVector!
                                      _trazosUsuario.last.add(PointVector(details.localPosition.dx, details.localPosition.dy));
                                    });
                                  },
                                  onPanEnd: (details) {
                                    // Validación matemática pendiente
                                  },
                                  child: CustomPaint(
                                    painter: PincelPainter(_trazosUsuario),
                                    size: Size.infinite,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _botonSRS('Difícil', Colors.red, 5),
                          _botonSRS('Medio', Colors.orange, 3 * 24 * 60),
                          _botonSRS('Fácil', Colors.green, 14 * 24 * 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _botonSRS(String texto, MaterialColor color, int tiempo) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.shade50, 
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
      ),
      onPressed: () => _evaluar(tiempo),
      child: Text(texto, style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600)),
    );
  }
}

// =========================================================================
// EL MOTOR DE RENDERIZADO DEL PINCEL (CALIBRADO PARA CALIGRAFÍA)
// =========================================================================
class PincelPainter extends CustomPainter {
  final List<List<PointVector>> trazos;
  PincelPainter(this.trazos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    for (var trazo in trazos) {
      final outlinePoints = getStroke(
        trazo,
        options: StrokeOptions(
          size: 8,          // Grosor base reducido a la mitad (aprox 0.6 cm)
          thinning: 0.8,     // ¡Extremo! Si mueves el dedo rápido, terminará en punta muy fina
          smoothing: 0.8,    // Máximo suavizado para curvas perfectas
          streamline: 0.8,   // Mucha resistencia para eliminar el temblor de la mano
        ),
      );

      if (outlinePoints.isEmpty) continue;

      final path = Path();
      path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
      for (int i = 1; i < outlinePoints.length; ++i) {
        path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =========================================================================
// EL PINTOR DE LA CUADRÍCULA "MI ZI GE"
// =========================================================================
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashWidth = 8.0;
    final dashSpace = 6.0;

    _drawDashedLine(canvas, Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint, dashWidth, dashSpace);
    _drawDashedLine(canvas, Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint, dashWidth, dashSpace);
    _drawDashedLine(canvas, const Offset(0, 0), Offset(size.width, size.height), paint, dashWidth, dashSpace);
    _drawDashedLine(canvas, Offset(size.width, 0), Offset(0, size.height), paint, dashWidth, dashSpace);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth, double dashSpace) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = math.sqrt(dx * dx + dy * dy); 
    
    if (distance == 0) return;
    
    final double unitX = dx / distance;
    final double unitY = dy / distance;

    double currentX = p1.dx;
    double currentY = p1.dy;
    double drawn = 0.0;

    while (drawn < distance) {
      canvas.drawLine(
        Offset(currentX, currentY), 
        Offset(currentX + unitX * dashWidth, currentY + unitY * dashWidth), 
        paint
      );
      currentX += unitX * (dashWidth + dashSpace);
      currentY += unitY * (dashWidth + dashSpace);
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SvgHanziPainter extends CustomPainter {
  final List<String> trazosSvg;
  SvgHanziPainter(this.trazosSvg);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.grey.withOpacity(0.15) 
      ..style = PaintingStyle.fill;

    final double scaleX = (size.width * 0.9) / 1024; 
    final double scaleY = (size.height * 0.9) / 1024;
    
    canvas.translate(size.width * 0.05, size.height * 0.05);
    canvas.scale(scaleX, -scaleY);
    canvas.translate(0, -1024);

    for (String trazo in trazosSvg) {
      final path = parseSvgPathData(trazo);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}