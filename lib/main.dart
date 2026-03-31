import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:perfect_freehand/perfect_freehand.dart'; 
import 'database/db_helper.dart';
import 'dart:ui'; // Efecto de Liquid Glass
import 'widgets/glass_speaker_button.dart'; // Ajusta la ruta si lo guardaste en otro lado
import 'widgets/fondo_tinta.dart'; // Fondo de tinta china
import 'package:flutter/services.dart'; // HapticFeedback

// ====================================================================================================
// 1. CONFIGURACIÓN Y RAÍZ DE LA APP
// Inicializa Flutter, la base de datos y lanza la aplicación.
// ====================================================================================================

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
// 2. PANTALLA DE INICIO (PantallaInicio)
// Menú principal con el botón de entrada, estadísticas y frases rotativas.
// =========================================================================

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final List<String> _frases = [
    "El viaje de mil millas comienza con un solo paso.",
    "Aprender es un tesoro que seguirá a su dueño a todas partes.",
    "No temas ir despacio, teme solo a detenerte.",
    "La paciencia es una planta amarga, pero su fruto es dulce."
  ];
  int _indiceFrase = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _indiceFrase = (_indiceFrase + 1) % _frases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            // --- BOTÓN LIQUID GLASS PRINCIPAL ---
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaSeleccion()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xBF000000), // Cristal oscuro
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0x4DFFFFFF), width: 1.5), // Borde blanco translúcido
                    ),
                    child: const Text(
                      'Chino tradicional',
                      style: TextStyle(fontSize: 18, color: Colors.white, letterSpacing: 0.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- BOTÓN LIQUID GLASS SECUNDARIO (Estadísticas) ---
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaEstadisticas()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x80F5F5F5), // Mismo cristal oscuro
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0x80E0E0E0), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_outline, color: Colors.grey.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Ver mis estadísticas",
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // --- EL MENSAJE CON EL BUG ARREGLADO ---
            Container(
              height: 60,
              width: double.infinity, // ¡AQUÍ ESTÁ LA MAGIA! Esto evita que la pantalla tiemble
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final rotate = Tween(begin: math.pi / 2, end: 0.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)
                  );
                  final fade = Tween(begin: 0.0, end: 1.0).animate(animation);
                  return AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) {
                      return Transform(
                        transform: Matrix4.rotationX(rotate.value),
                        alignment: Alignment.center,
                        child: Opacity(opacity: fade.value, child: child),
                      );
                    }
                  );
                },
                child: Text(
                  _frases[_indiceFrase],
                  key: ValueKey<int>(_indiceFrase),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      )) ;                                                                    
  }
}

// =========================================================================
// 3. PANTALLA DE SELECCIÓN (PantallaSeleccion)
// Biblioteca HSK con barra de búsqueda animada y lista de niveles.
// =========================================================================

class PantallaSeleccion extends StatefulWidget {
  const PantallaSeleccion({super.key});

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  bool _estaBuscando = false;
  List<Map<String, dynamic>> _resultadosBusqueda = [];

  void _alEscribir(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _estaBuscando = false;
        _resultadosBusqueda = [];
      });
      return;
    }

    setState(() => _estaBuscando = true);

    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'caracteres',
      where: 'simplificado LIKE ? OR pinyin LIKE ? OR significados LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 15
    );

    if (mounted) {
      setState(() {
        _resultadosBusqueda = res;
      });
    }
  }

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
              onChanged: _alEscribir,
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
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _estaBuscando ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              
              firstChild: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: 7, 
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, index) {
                  final nivel = index + 1;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                    title: Text(nivel == 7 ? "HSK 7-9" : "HSK $nivel", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
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
              
              secondChild: _resultadosBusqueda.isEmpty 
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("Sin resultados", style: TextStyle(color: Colors.grey)),
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: _resultadosBusqueda.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                    itemBuilder: (context, index) {
                      final hanzi = _resultadosBusqueda[index];
                      return ListTile(
                        title: Text("${hanzi['simplificado']}  (${hanzi['pinyin']})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text("${hanzi['significados']}", maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.draw, size: 18, color: Colors.blue),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaEstudio(
                                nivelHSK: hanzi['nivel'],
                                hanziIdBuscado: hanzi['id'], // Conectamos la búsqueda
                              )
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 4. PANTALLA DE ESTADÍSTICAS (PantallaEstadisticas)
// Consultas agrupadas y donas de progreso divididas por nivel HSK.
// =========================================================================

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  List<Map<String, dynamic>> _datosPorNivel = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> stats = await db.rawQuery('''
      SELECT nivel, 
             COUNT(id) as total, 
             SUM(CASE WHEN veces_visto > 0 THEN 1 ELSE 0 END) as estudiados 
      FROM caracteres 
      GROUP BY nivel 
      ORDER BY nivel ASC
    ''');

    if (mounted) {
      setState(() {
        _datosPorNivel = stats;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mi Progreso', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _datosPorNivel.length,
            itemBuilder: (context, index) {
              final nivelData = _datosPorNivel[index];
              final int nivel = nivelData['nivel'];
              final int total = nivelData['total'];
              final int estudiados = nivelData['estudiados'] ?? 0;
              final double porcentaje = total > 0 ? estudiados / total : 0.0;
              
              if (nivel > 7 || nivel == 10) return const SizedBox.shrink(); // Ocultamos errores o no oficiales

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100)
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60, height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: porcentaje,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.black87,
                          ),
                          Text(
                            "${(porcentaje * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          )
                        ]
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nivel == 7 ? "HSK 7-9 (Avanzado)" : "Nivel HSK $nivel", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("$estudiados de $total hanzi aprendidos", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          ),
    );
  }
}

// =========================================================================
// 5. PANTALLA DE ESTUDIO (PantallaEstudio)
// El núcleo de la práctica. Conecta el lienzo, el evaluador y los ejemplos.
// =========================================================================

class PantallaEstudio extends StatefulWidget {
  final int nivelHSK;
  final int? hanziIdBuscado; // Parámetro crucial para que la búsqueda funcione

  const PantallaEstudio({super.key, required this.nivelHSK, this.hanziIdBuscado});

  @override
  State<PantallaEstudio> createState() => _PantallaEstudioState();
}

class _PantallaEstudioState extends State<PantallaEstudio> {
  Map<String, dynamic>? _hanziActual;
  final List<List<PointVector>> _trazosUsuario = []; 
  
  int _trazoCorrectoActual = 0;
  bool _mostrarPistaError = false;
  bool _hanziCompletado = false;
  bool _esBusquedaInicial = true; // Control para cargar la búsqueda 
  bool _mostrarExito = false; // Para mostrar el mensaje de éxito al completar un hanzi

  @override
  void initState() {
    super.initState();
    _siguienteHanzi(); 
  }

  void _siguienteHanzi() async {
    Map<String, dynamic>? hanzi;
    
    // Si viene de la barra de búsqueda, carga ese Hanzi exacto la primera vez
    if (widget.hanziIdBuscado != null && _esBusquedaInicial) {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('caracteres', where: 'id = ?', whereArgs: [widget.hanziIdBuscado]);
      if (res.isNotEmpty) hanzi = res.first;
      _esBusquedaInicial = false;
    } else {
      hanzi = await DatabaseHelper.instance.obtenerSiguienteHanziParaEstudiar(widget.nivelHSK);
    }

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

  // EL MODAL DE EJEMPLOS REPARADO
  void _mostrarModalEjemplos(int hanziId) async {
    final db = await DatabaseHelper.instance.database;
    final listaEjemplos = await db.query(
      'ejemplos',
      where: 'caracter_id = ?',
      whereArgs: [hanziId],
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) {
        if (listaEjemplos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30.0),
            child: Text(
              "Aún no hay ejemplos para este carácter.", 
              style: TextStyle(fontSize: 16)
            ),
          );
        }
        return ListView.builder(
          itemCount: listaEjemplos.length,
          itemBuilder: (context, index) {
            final ej = listaEjemplos[index];
            return ListTile(
              title: Text(
                "${ej['palabra']} (${ej['pinyin']})", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
              ),
              subtitle: Text(
                "${ej['significado']}", 
                style: const TextStyle(fontSize: 16)
              ),
            );
          },
        );
      }
    );
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
      HapticFeedback.lightImpact(); // ← trazo correcto: toque suave
      setState(() {
        _mostrarExito = true; // Mostrar mensaje de éxito
        _trazoCorrectoActual++;
        if (_trazoCorrectoActual >= medians.length) {
          _hanziCompletado = true;
        }
      });
    } else {
      HapticFeedback.heavyImpact(); // ← trazo incorrecto: vibración más fuerte
      setState(() {
        _mostrarPistaError = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _mostrarExito = false);{
          setState(() {
            if (_trazosUsuario.isNotEmpty) {
              _trazosUsuario.removeLast();
            }
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
                        // ── BOTÓN DE VOZ (nuevo) ──────────────────────────────────
                        const SizedBox(height: 14),
                        GlassSpeakerButton(
                          textoALeer: _hanziActual!['simplificado'],
                        ),
                        // ─────────────────────────────────────────────────────────
                        // Botón ver ejemplos
                        // --- BOTÓN LIQUID GLASS (Ver Ejemplos) ---
                        if (_hanziActual != null) 
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: InkWell(
                                  onTap: () => _mostrarModalEjemplos(_hanziActual!['id']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0x99E3F2FD), // Azul claro translúcido
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0x6690CAF9), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.menu_book_rounded, color: Colors.blue.shade700, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Ver ejemplos",
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // --- FIN DEL BOTÓN ---                             
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
                            BoxShadow(color: const Color(0x80000000), blurRadius: 20, offset: const Offset(0, 10))
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
                                    if (_mostrarExito)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: AnimatedOpacity(
                                            opacity: _mostrarExito ? 1.0 : 0.0,
                                            duration: const Duration(milliseconds: 200),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(13),
                                                color: const Color(0x2200C853), // verde suave
                                              ),
                                            ),
                                          ),
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
// 6. FORMATEADOR DE TEXTO (PinyinHelper)
// Lógica para traducir Pinyin numérico (ej. ni3) a caracteres con acentos (nǐ).
// =========================================================================
class PinyinHelper {
  static String formatear(String texto) {
    if (texto.isEmpty) return texto;
    final map = {
      'a': ['ā', 'á', 'ǎ', 'à'],
      'e': ['ē', 'é', 'ě', 'è'],
      'i': ['ī', 'í', 'ǐ', 'ì'],
      'o': ['ō', 'ó', 'ǒ', 'ò'],
      'u': ['ū', 'ú', 'ǔ', 'ù'],
      'v': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
      'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
    };
    List<String> palabras = texto.toLowerCase().split(RegExp(r'\s+'));
    List<String> resultado = [];

    for (String palabra in palabras) {
      RegExp regex = RegExp(r'([a-züv]+)(\d)');
      Match? match = regex.firstMatch(palabra);

      if (match == null) {
        resultado.add(palabra.replaceAll('v', 'ü'));
        continue;
      }

      String silaba = match.group(1)!.replaceAll('v', 'ü');
      int tono = int.parse(match.group(2)!);
      if (tono < 1 || tono > 4) {
        String resto = palabra.substring(match.end);
        resultado.add(silaba + resto);
        continue;
      }

      int t = tono - 1;

      if (silaba.contains('a')) {
        silaba = silaba.replaceFirst('a', map['a']![t]);
      } else if (silaba.contains('e')) {
        silaba = silaba.replaceFirst('e', map['e']![t]);
      } else if (silaba.contains('o')) {
        silaba = silaba.replaceFirst('o', map['o']![t]);
      } else {
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
// 7. PINTOR DE EVALUACIÓN Y TRAZOS (PincelPainter & PistaRojaPainter)
// Renderiza el dedo del usuario con efecto de tinta y las alertas rojas de error.
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

// =========================================================================
// 8. PINTORES DE FONDO GEOMÉTRICO (GridPainter & SvgFondoPainter)
// Dibujan las líneas guías (cruz) y la sombra gris del Hanzi a calcar.
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

class SvgFondoPainter extends CustomPainter {
  final List<String> trazosSvg;
  SvgFondoPainter(this.trazosSvg);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0X1F9E9E9E) 
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
      ..color = const Color(0x66F44336) 
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