import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'pantalla_seleccion.dart';
import 'pantalla_estadisticas.dart';
import '/widgets/fondo_tinta.dart';

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
    "La paciencia es una planta amarga, pero su fruto es dulce.",
  ];
  int _indiceFrase = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) setState(() => _indiceFrase = (_indiceFrase + 1) % _frases.length);
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

              // Botón principal
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: InkWell(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PantallaSeleccion())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xBF000000),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0x4DFFFFFF), width: 1.5),
                      ),
                      child: const Text(
                        'Chino tradicional',
                        style: TextStyle(fontSize: 18, color: Colors.white,
                            letterSpacing: 0.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón estadísticas
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: InkWell(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PantallaEstadisticas())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x80F5F5F5),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0x80E0E0E0), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pie_chart_outline, color: Colors.grey.shade800, size: 20),
                          const SizedBox(width: 8),
                          Text("Ver mis estadísticas",
                              style: TextStyle(color: Colors.grey.shade800,
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Frase animada
              Container(
                height: 60,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, animation) {
                    final rotate = Tween(begin: math.pi / 2, end: 0.0).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                    final fade = Tween(begin: 0.0, end: 1.0).animate(animation);
                    return AnimatedBuilder(
                      animation: animation,
                      child: child,
                      builder: (context, child) => Transform(
                        transform: Matrix4.rotationX(rotate.value),
                        alignment: Alignment.center,
                        child: Opacity(opacity: fade.value, child: child),
                      ),
                    );
                  },
                  child: Text(
                    _frases[_indiceFrase],
                    key: ValueKey<int>(_indiceFrase),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}