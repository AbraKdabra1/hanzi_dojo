import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:signature/signature.dart';
import 'package:path_drawing/path_drawing.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey), // Un tono más sobrio
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Hanzi Dojo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? _hanziActual;
  bool _hanziEscritoCorrectamente = false; 
  bool _mostrandoRespuesta = false;

  final SignatureController _controladorLienzo = SignatureController(
    penStrokeWidth: 5, // Trazo un poco más fino y elegante
    penColor: Colors.black87,
    exportBackgroundColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    _controladorLienzo.addListener(_detectarFinalizacionEscritura);
  }

  @override
  void dispose() {
    _controladorLienzo.removeListener(_detectarFinalizacionEscritura);
    _controladorLienzo.dispose();
    super.dispose();
  }

  void _detectarFinalizacionEscritura() {
    if (_controladorLienzo.points.isNotEmpty && !_hanziEscritoCorrectamente) {
      setState(() {
        _hanziEscritoCorrectamente = true;
      });
    }
  }

  void _siguienteHanzi() async {
    final hanzi = await DatabaseHelper.instance.obtenerSiguienteHanziParaEstudiar();
    setState(() {
      _hanziActual = hanzi;
      _mostrandoRespuesta = false;
      _hanziEscritoCorrectamente = false;
    });
    _controladorLienzo.clear();
  }

  void _revelarRespuesta() {
    setState(() {
      _mostrandoRespuesta = true;
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

  // NUEVO: Función para mostrar el panel inferior elegante
  void _mostrarPanelEjemplos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que la animación fluya natural
      backgroundColor: Colors.transparent, // Para tener bordes redondeados limpios
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4, // Ocupa el 40% de la pantalla
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              // La pequeña "pestaña" gris para indicar que se puede arrastrar hacia abajo
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "Ejemplos de Uso",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const Divider(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      "Aquí aparecerán oraciones de ejemplo usando el carácter '${_hanziActual?['simplificado'] ?? ''}'.\n\n(Requiere actualización de la base de datos).",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Fondo ligeramente gris para que el lienzo blanco resalte
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.title, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
      ),
      // ELIMINAMOS EL SCROLL. Ahora la pantalla es rígida.
      body: _hanziActual == null 
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: const Text('Presiona "Empezar" para tu primera tarjeta', style: TextStyle(fontSize: 18)),
              ),
            )
          : Column(
              children: [
                // SECCIÓN 1: DEFINICIÓN Y BOTÓN DE EJEMPLOS (Ocupa un espacio flexible)
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _mostrandoRespuesta 
                            ? '(${_hanziActual!['pinyin']})' 
                            : 'Significado:',
                          style: TextStyle(fontSize: _mostrandoRespuesta ? 22 : 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hanziActual!['significados'],
                          // Fuente más pequeña y sobria
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.black87, height: 1.3),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 15),
                        // Botón sutil para ver ejemplos
                        TextButton.icon(
                          onPressed: () => _mostrarPanelEjemplos(context),
                          icon: const Icon(Icons.menu_book, size: 18),
                          label: const Text("Ver ejemplos"),
                          style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ),

                // SECCIÓN 2: EL LIENZO CUADRADO (Proporción perfecta 1:1)
                Expanded(
                  flex: 4,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0, // Fuerza a que sea un cuadrado perfecto
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 25.0), // Alejado de los bordes laterales
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25), // Bordes bien redondeados
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                          ],
                          border: Border.all(color: Colors.grey.shade200, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(23),
                          child: AnimatedSwitcher( 
                            duration: const Duration(milliseconds: 400),
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
                                Signature(
                                  controller: _controladorLienzo,
                                  backgroundColor: Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // SECCIÓN 3: ESPACIADO PARA LOS BOTONES FLOTANTES
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ),
            
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _hanziActual == null
          ? FloatingActionButton.extended(
              onPressed: _siguienteHanzi,
              label: const Text('Empezar Dojo'),
              icon: const Icon(Icons.play_arrow),
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            )
          : !_mostrandoRespuesta
              ? FloatingActionButton.extended(
                  onPressed: _revelarRespuesta,
                  label: const Text('Ver Respuesta'),
                  icon: const Icon(Icons.visibility),
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, elevation: 0),
                        onPressed: () => _evaluar(5),
                        child: const Text('Difícil\n(5 min)', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50, elevation: 0),
                        onPressed: () => _evaluar(3 * 24 * 60), 
                        child: Text('Medio\n(3 días)', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange.shade900)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50, elevation: 0),
                        onPressed: () => _evaluar(14 * 24 * 60),
                        child: const Text('Fácil\n(14 días)', textAlign: TextAlign.center, style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// EL PINTOR DE LA CUADRÍCULA PUNTEADA
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashWidth = 10.0;
    final dashSpace = 5.0;

    var x = dashWidth + dashSpace;
    final halfHeight = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x - dashWidth, halfHeight), Offset(x, halfHeight), paint);
      x += dashWidth + dashSpace;
    }

    var y = dashWidth + dashSpace;
    final halfWidth = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(halfWidth, y - dashWidth), Offset(halfWidth, y), paint);
      y += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// EL PINTOR DEL ADN VECTORIAL
class SvgHanziPainter extends CustomPainter {
  final List<String> trazosSvg;
  SvgHanziPainter(this.trazosSvg);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.12) // Un tono gris/azulado más elegante en lugar de rojo brillante
      ..style = PaintingStyle.fill;

    final double scaleX = size.width / 1024;
    final double scaleY = size.height / 1024;
    
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