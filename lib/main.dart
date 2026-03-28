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
              MaterialPageRoute(builder: (context) => const PantallaSeleccion()),
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

class PantallaSeleccion extends StatelessWidget {
  const PantallaSeleccion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Biblioteca HSK', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar hanzi, pinyin o significado...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.grey.shade50, 
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: 9, 
              separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
              itemBuilder: (context, index) {
                final nivel = index + 1; 
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                  title: Text('Nivel HSK $nivel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  subtitle: Text('Estudiar y repasar tarjetas', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PantallaEstudio(nivelHSK: nivel)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PantallaEstudio extends StatefulWidget {
  final int nivelHSK;
  const PantallaEstudio({super.key, required this.nivelHSK});

  @override
  State<PantallaEstudio> createState() => _PantallaEstudioState();
}

class _PantallaEstudioState extends State<PantallaEstudio> {
  Map<String, dynamic>? _hanziActual;
  final List<List<PointVector>> _trazosUsuario = []; 
  
  int _trazoCorrectoActual = 0;
  bool _mostrarPistaError = false;
  bool _hanziCompletado = false;

  @override
  void initState() {
    super.initState();
    _siguienteHanzi(); 
  }

  void _siguienteHanzi() async {
    final hanzi = await DatabaseHelper.instance.obtenerSiguienteHanziParaEstudiar(widget.nivelHSK);
    setState(() {
      _hanziActual = hanzi;
      _trazosUsuario.clear(); 
      _trazoCorrectoActual = 0;
      _mostrarPistaError = false;
      _hanziCompletado = false;
      
      if (_hanziActual != null && _hanziActual!['medianas'] == null) {
        _hanziCompletado = true; 
      }
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
      _trazoCorrectoActual = 0;
      _hanziCompletado = false;
    });
  }

  void _auditarTrazo(Size canvasSize) {
    if (_hanziActual == null || _hanziActual!['medianas'] == null) return;

    List<dynamic> medians = jsonDecode(_hanziActual!['medianas']);
    
    if (_trazoCorrectoActual >= medians.length) return;

    List<dynamic> trazoEsperado = medians[_trazoCorrectoActual];
    double startXOficial = trazoEsperado.first[0].toDouble();
    double startYOficial = trazoEsperado.first[1].toDouble();
    double endXOficial = trazoEsperado.last[0].toDouble();
    double endYOficial = trazoEsperado.last[1].toDouble();

    final double scaleX = (canvasSize.width * 0.9) / 1024; 
    final double scaleY = (canvasSize.height * 0.9) / 1024;
    final double offsetX = canvasSize.width * 0.05;
    final double offsetY = canvasSize.height * 0.05;

    Offset puntoInicioEsperado = Offset(offsetX + (startXOficial * scaleX), offsetY + ((1024 - startYOficial) * scaleY));
    Offset puntoFinEsperado = Offset(offsetX + (endXOficial * scaleX), offsetY + ((1024 - endYOficial) * scaleY));

    var ultimoTrazo = _trazosUsuario.last;
    if (ultimoTrazo.length < 2) return; 

    Offset puntoInicioDedo = Offset(ultimoTrazo.first.dx, ultimoTrazo.first.dy);
    Offset puntoFinDedo = Offset(ultimoTrazo.last.dx, ultimoTrazo.last.dy);

    double distanciaInicio = (puntoInicioDedo - puntoInicioEsperado).distance;
    double distanciaFin = (puntoFinDedo - puntoFinEsperado).distance;

    double tolerancia = canvasSize.width * 0.25; 

    if (distanciaInicio <= tolerancia && distanciaFin <= tolerancia) {
      setState(() {
        _trazoCorrectoActual++;
        if (_trazoCorrectoActual >= medians.length) {
          _hanziCompletado = true; 
        }
      });
    } else {
      setState(() {
        _trazosUsuario.removeLast(); 
        _mostrarPistaError = true;   
      });
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _mostrarPistaError = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Estudiando HSK ${widget.nivelHSK}', style: const TextStyle(color: Colors.black87, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context), 
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _limpiarLienzo,
            tooltip: "Reiniciar trazos",
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
                          // ¡AQUÍ ESTÁ LA MAGIA! Filtramos el Pinyin crudo por nuestro traductor
                          PinyinHelper.formatear(_hanziActual!['pinyin']),
                          style: TextStyle(fontSize: 22, color: Colors.grey.shade600, letterSpacing: 1.2, fontWeight: FontWeight.w500),
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                              
                              List<String> todosLosVectores = _hanziActual!['trazos'] != null 
                                  ? List<String>.from(jsonDecode(_hanziActual!['trazos'])) 
                                  : [];

                              return Stack( 
                                children: [
                                  Positioned.fill(child: CustomPaint(painter: GridPainter())),
                                  
                                  if (todosLosVectores.isNotEmpty)
                                    Positioned.fill(
                                      child: CustomPaint(painter: SvgFondoPainter(todosLosVectores)),
                                    ),

                                  if (todosLosVectores.isNotEmpty && _trazoCorrectoActual < todosLosVectores.length)
                                    Positioned.fill(
                                      child: AnimatedOpacity(
                                        opacity: _mostrarPistaError ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: CustomPaint(painter: PistaRojaPainter(todosLosVectores[_trazoCorrectoActual])),
                                      ),
                                    ),
                                  
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onPanStart: (details) {
                                        if (_hanziCompletado) return; 
                                        setState(() {
                                          _trazosUsuario.add([PointVector(details.localPosition.dx, details.localPosition.dy)]);
                                        });
                                      },
                                      onPanUpdate: (details) {
                                        if (_hanziCompletado) return;
                                        setState(() {
                                          _trazosUsuario.last.add(PointVector(details.localPosition.dx, details.localPosition.dy));
                                        });
                                      },
                                      onPanEnd: (details) {
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
                            }
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _hanziCompletado ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: _hanziCompletado 
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _botonSRS('Difícil', Colors.red, 5),
                                _botonSRS('Medio', Colors.orange, 3 * 24 * 60),
                                _botonSRS('Fácil', Colors.green, 14 * 24 * 60),
                              ],
                            ),
                          )
                        : Text(
                            "Dibuja el carácter...", 
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontStyle: FontStyle.italic)
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
// EL TRADUCTOR DE PINYIN NUMÉRICO A PINYIN NATIVO (NUEVO)
// =========================================================================
class PinyinHelper {
  static String formatear(String texto) {
    if (texto.isEmpty) return texto;

    // Nuestro catálogo de acentos (Tono 1, 2, 3, 4)
    final map = {
      'a': ['ā', 'á', 'ǎ', 'à'],
      'e': ['ē', 'é', 'ě', 'è'],
      'i': ['ī', 'í', 'ǐ', 'ì'],
      'o': ['ō', 'ó', 'ǒ', 'ò'],
      'u': ['ū', 'ú', 'ǔ', 'ù'],
      'v': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
      'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
    };

    // Dividimos por espacios (ej. "zhong1 wen2" -> ["zhong1", "wen2"])
    List<String> palabras = texto.toLowerCase().split(RegExp(r'\s+'));
    List<String> resultado = [];

    for (String palabra in palabras) {
      // Buscamos letras seguidas de un número (1 al 5)
      RegExp regex = RegExp(r'([a-züv]+)(\d)');
      Match? match = regex.firstMatch(palabra);

      if (match == null) {
        resultado.add(palabra.replaceAll('v', 'ü')); // Sin número, se queda igual
        continue;
      }

      String silaba = match.group(1)!.replaceAll('v', 'ü');
      int tono = int.parse(match.group(2)!);

      // Si es tono 5 (neutro) o un número raro, solo quitamos el número
      if (tono < 1 || tono > 4) {
        String resto = palabra.substring(match.end);
        resultado.add(silaba + resto);
        continue;
      }

      int t = tono - 1; // Ajuste para buscar en nuestra lista (índices 0 a 3)

      // Reglas jerárquicas del Pinyin:
      if (silaba.contains('a')) {
        silaba = silaba.replaceFirst('a', map['a']![t]);
      } else if (silaba.contains('e')) {
        silaba = silaba.replaceFirst('e', map['e']![t]);
      } else if (silaba.contains('o')) {
        silaba = silaba.replaceFirst('o', map['o']![t]);
      } else {
        // Si no hay a, e, o -> El acento va en la *última* vocal (para iu, ui)
        for (int i = silaba.length - 1; i >= 0; i--) {
          String letra = silaba[i];
          if (map.containsKey(letra)) {
            silaba = silaba.replaceRange(i, i + 1, map[letra]![t]);
            break;
          }
        }
      }
      
      String resto = palabra.substring(match.end);
      resultado.add(silaba + resto);
    }
    return resultado.join(' ');
  }
}

// =========================================================================
// PINTORES DEL LIENZO GEOMÉTRICO
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
          size: 8, 
          thinning: 0.8, 
          smoothing: 0.8, 
          streamline: 0.8,
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

class SvgFondoPainter extends CustomPainter {
  final List<String> trazosSvg;
  SvgFondoPainter(this.trazosSvg);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.grey.withOpacity(0.12) 
      ..style = PaintingStyle.fill;

    final double scaleX = (size.width * 0.9) / 1024; 
    final double scaleY = (size.height * 0.9) / 1024;
    canvas.translate(size.width * 0.05, size.height * 0.05);
    canvas.scale(scaleX, -scaleY);
    canvas.translate(0, -1024);

    for (String trazo in trazosSvg) {
      canvas.drawPath(parseSvgPathData(trazo), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PistaRojaPainter extends CustomPainter {
  final String trazoSvg;
  PistaRojaPainter(this.trazoSvg);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.red.withOpacity(0.4) 
      ..style = PaintingStyle.fill;

    final double scaleX = (size.width * 0.9) / 1024; 
    final double scaleY = (size.height * 0.9) / 1024;
    canvas.translate(size.width * 0.05, size.height * 0.05);
    canvas.scale(scaleX, -scaleY);
    canvas.translate(0, -1024);

    canvas.drawPath(parseSvgPathData(trazoSvg), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}