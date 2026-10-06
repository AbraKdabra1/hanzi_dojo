// ─────────────────────────────────────────────────────────────────────────────
// pantalla_inicio.dart — Pantalla principal
//
// - Resumen del día: anillo con lo que llevas de tu meta diaria, repasos
//   pendientes (caracteres y palabras), nuevos de hoy y tu racha (🔥; 🛡️ si
//   el protector la salvó).
// - Al volver de estudiar: aplica el protector de racha si hace falta, avisa
//   si cumpliste la meta y muestra los logros nuevos (fase 6).
// - Botón "Estudiar" → elegir modo (novato/experto) y qué estudiar.
// - Botón "Leer" → libros graduados por nivel HSK (pantalla_biblioteca.dart).
// - Botón "Practicar" → ejercicios con audio (pantalla_practica.dart).
// - Estadísticas y Ajustes.
// - Abajo, una frase que cambia cada 4 segundos con un giro suave (solo
//   mientras la pantalla se ve: con otra pantalla encima o la app en segundo
//   plano el reloj se detiene, para no gastar batería).
// - Fondo: rama de ciruelo en flor que se mece con el viento y suelta pétalos
//   (ver fondo_tinta.dart y painters/rama_ciruelo.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/repositorio_habito.dart';
import '../datos/repositorio_practica.dart';
import '../helpers/habito.dart';
import '../tema.dart';
import '../widgets/apoyo.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/logro_dialogo.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_biblioteca.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_logros.dart';
import 'pantalla_modo.dart';
import 'pantalla_practica.dart';
import '../idioma.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> with WidgetsBindingObserver {
  static List<String> get _frases => [
    tr('El viaje de mil millas comienza con un solo paso.'),
    tr('Aprender es un tesoro que seguirá a su dueño a todas partes.'),
    tr('No temas ir despacio, teme solo a detenerte.'),
    tr('La paciencia es una planta amarga, pero su fruto es dulce.'),
  ];
  int _indiceFrase = 0;
  Timer? _temporizador;

  int? _pendientes;
  int? _nuevosHoy;
  int? _meta;
  int _racha = 0;
  int _hoy = 0;
  int _metaDiaria = HabitoRepositorio.metaPorDefecto;

  /// La racha sigue gracias al protector (se ve un 🛡️).
  bool _protegida = false;

  bool _visible = true;
  bool _enPrimerPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarResumen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // false mientras otra pantalla está encima.
    _visible = ModalRoute.of(context)?.isCurrent ?? true;
    _actualizarFrases();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    _actualizarFrases();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporizador?.cancel();
    super.dispose();
  }

  /// El reloj de las frases corre solo mientras la pantalla se ve.
  void _actualizarFrases() {
    final correr = _visible && _enPrimerPlano;
    if (correr && _temporizador == null) {
      _temporizador = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) setState(() => _indiceFrase = (_indiceFrase + 1) % _frases.length);
      });
    } else if (!correr && _temporizador != null) {
      _temporizador!.cancel();
      _temporizador = null;
    }
  }

  Future<void> _cargarResumen() async {
    final repo = DatosApp.de(context);
    final cubiertos = await repo.aplicarProtector();
    final pendientes = await repo.repasosPendientes() + await repo.palabrasPendientes();
    final nuevos = await repo.nuevosHoy();
    final meta = await repo.limiteNuevosPorDia();
    final hoy = await repo.actividadHoy();
    final metaDiaria = await repo.metaDiaria();
    final racha = await repo.rachaConProtector();
    final protegidos = await repo.diasProtegidos();
    final logros = await repo.revisarLogros();
    final celebrarMeta = hoy >= metaDiaria && !await repo.metaCelebradaHoy();
    if (celebrarMeta) await repo.marcarMetaCelebrada();
    Habito.actualizarWidget();
    if (!mounted) return;
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    setState(() {
      _pendientes = pendientes;
      _nuevosHoy = nuevos;
      _meta = meta;
      _hoy = hoy;
      _metaDiaria = metaDiaria;
      _racha = racha.actual;
      _protegida = racha.actual > 0 &&
          protegidos.any((d) => d.year == ayer.year && d.month == ayer.month && d.day == ayer.day);
    });
    final aviso = ScaffoldMessenger.of(context);
    if (cubiertos.isNotEmpty) {
      aviso.showSnackBar(SnackBar(
        content: Text(cubiertos.length == 1
            ? tr('🛡️ Tu protector de racha cubrió el día que no practicaste. Hay uno por semana.')
            : tr('🛡️ Tus protectores de racha cubrieron {0} días.', [cubiertos.length])),
        duration: const Duration(seconds: 5),
      ));
    }
    if (celebrarMeta) {
      aviso.showSnackBar(SnackBar(content: Text(tr('🎯 ¡Meta del día cumplida! {0} de {1}', [hoy, metaDiaria]))));
    }
    if (logros.isNotEmpty) {
      await mostrarLogrosNuevos(context, logros);
      // Una sola vez en la vida de la app (ver widgets/apoyo.dart).
      if (mounted) await Apoyo.sugerirTrasLogro(context, repo);
    }
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargarResumen(); // al volver, actualizar el resumen del día
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return FondoTintaChina(
      ramaAnimada: true,
      child: Scaffold(
        // En horizontal (o con letra muy grande) el contenido no cabe: se
        // vuelve desplazable; en vertical ocupa la pantalla y los Spacer lo
        // reparten como siempre.
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricciones) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: restricciones.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.emoji_events_outlined, color: c.icono),
                    tooltip: tr('Logros'),
                    onPressed: () => _ir(const PantallaLogros()),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: c.icono),
                    tooltip: tr('Ajustes y créditos'),
                    onPressed: () => _ir(const PantallaAjustes()),
                  ),
                ],
              ),
              const Spacer(),
              const Text('汉字道场', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w400, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('Hanzi Dojo', style: TextStyle(fontSize: 14, color: c.tenue, letterSpacing: 2)),
              const SizedBox(height: 28),
              _ResumenDelDia(
                pendientes: _pendientes,
                nuevosHoy: _nuevosHoy,
                meta: _meta,
                racha: _racha,
                protegida: _protegida,
                hoy: _hoy,
                metaDiaria: _metaDiaria,
              ),
              const SizedBox(height: 28),

              // Botón principal → PantallaModo
              Material(
                color: c.boton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: c.bordeTarjeta, width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _ir(const PantallaModo()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                    child: Text(tr('Estudiar'),
                        style: TextStyle(fontSize: 18, color: c.textoBoton, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botones secundarios → «Leer» (libros graduados) y «Practicar»
              // (tonos, escucha, vocabulario y pinyin con audio).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BotonSecundario(
                    icono: Icons.menu_book_rounded,
                    texto: tr('Leer'),
                    onTap: () => _ir(const PantallaBiblioteca()),
                  ),
                  const SizedBox(width: 12),
                  _BotonSecundario(
                    icono: Icons.headphones_rounded,
                    texto: tr('Practicar'),
                    onTap: () => _ir(const PantallaPractica()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Botón estadísticas (con fondo de papel translúcido: si un pétalo
              // pasa por detrás, el texto se sigue leyendo bien).
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: c.translucido,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(Icons.pie_chart_outline, color: c.suave, size: 20),
                label: Text(tr('Ver mis estadísticas'),
                    style: TextStyle(color: c.suave, fontSize: 15, fontWeight: FontWeight.w500)),
                onPressed: () => _ir(const PantallaEstadisticas()),
              ),
              const Spacer(),

              // Frase que gira cada 4 s
              SizedBox(
                height: 60,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animacion) {
                      final giro = Tween(begin: math.pi / 2, end: 0.0)
                          .animate(CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic));
                      return AnimatedBuilder(
                        animation: animacion,
                        child: child,
                        builder: (context, child) => Transform(
                          transform: Matrix4.rotationX(giro.value),
                          alignment: Alignment.center,
                          child: Opacity(opacity: animacion.value, child: child),
                        ),
                      );
                    },
                    child: Text(
                      _frases[_indiceFrase],
                      key: ValueKey<int>(_indiceFrase),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.suave, fontStyle: FontStyle.italic, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón con borde de tinta ("Leer", "Practicar").
class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({required this.icono, required this.texto, required this.onTap});

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.tarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: c.tinta, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20, color: c.tinta),
              const SizedBox(width: 8),
              Text(texto, style: TextStyle(fontSize: 17, color: c.tinta, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anillo con lo que llevas hoy de tu meta y, al lado, repasos pendientes,
/// nuevos de hoy y racha.
class _ResumenDelDia extends StatelessWidget {
  const _ResumenDelDia({
    required this.pendientes,
    required this.nuevosHoy,
    required this.meta,
    this.racha = 0,
    this.protegida = false,
    this.hoy = 0,
    this.metaDiaria = 20,
  });

  final int? pendientes;
  final int? nuevosHoy;
  final int? meta;

  /// Días seguidos estudiando (0 = no se muestra).
  final int racha;
  final bool protegida;

  /// Repasos y ejercicios de hoy, y la meta diaria.
  final int hoy;
  final int metaDiaria;

  @override
  Widget build(BuildContext context) {
    if (pendientes == null) return const SizedBox(height: 56);
    final c = context.colores;
    final estilo = TextStyle(fontSize: 13, color: c.suave);
    final cumplida = hoy >= metaDiaria;
    final verde = c.oscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    return Semantics(
      label: tr('Hoy llevas {0} de {1}. {2} repasos pendientes. Racha de {3} días.', [hoy, metaDiaria, pendientes, racha]),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        decoration: BoxDecoration(
          color: c.translucido,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.bordeTarjeta),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: metaDiaria == 0 ? 1 : (hoy / metaDiaria).clamp(0.0, 1.0).toDouble(),
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.separador,
                    color: cumplida ? verde : c.tinta,
                  ),
                  Center(
                    child: cumplida
                        ? Icon(Icons.check_rounded, size: 22, color: verde)
                        : Text('$hoy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.tinta)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cumplida ? tr('Meta de hoy cumplida') : tr('Hoy: {0} de {1}', [hoy, metaDiaria]),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.tinta)),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_rounded, size: 14, color: c.icono),
                    const SizedBox(width: 3),
                    Text('$pendientes', style: estilo),
                    const SizedBox(width: 10),
                    Icon(Icons.fiber_new_outlined, size: 16, color: c.icono),
                    const SizedBox(width: 3),
                    Text('$nuevosHoy/$meta', style: estilo),
                    if (racha > 0) ...[
                      const SizedBox(width: 10),
                      Text('🔥 $racha${protegida ? ' 🛡️' : ''}',
                          style: estilo.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
