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
// - La primera vez, tras el tutorial: «¿Nunca has estudiado chino?». Si
//   eliges empezar desde cero, «🌱 Chino desde cero» va arriba y Estudiar,
//   Leer y Practicar tienen candado hasta terminar las seis lecciones (o
//   desbloquearlas ya); ver pantalla_desde_cero.dart y datos/desde_cero.dart.
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
import '../datos/desde_cero.dart';
import '../datos/repositorio_habito.dart';
import '../datos/repositorio_practica.dart';
import '../helpers/actualizaciones.dart';
import '../helpers/habito.dart';
import '../tema.dart';
import '../widgets/apoyo.dart';
import '../widgets/aviso_version.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/logro_dialogo.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_biblioteca.dart';
import 'pantalla_desde_cero.dart';
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
    tr('Con suficiente constancia, una barra de hierro se vuelve aguja.'),
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

  /// El tutorial se revisa una sola vez por apertura de la app.
  bool _tutorialRevisado = false;

  /// La versión nueva también (helpers/actualizaciones.dart); si hay una,
  /// se avisa arriba.
  bool _versionRevisada = false;
  VersionNueva? _versionNueva;

  /// «Chino desde cero»: qué elegiste (null = cargando) y qué terminaste.
  RutaDesdeCero? _ruta;
  Set<int> _lecciones = const {};

  bool get _bloqueado => _ruta?.bloquea ?? false;

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
    // La primera vez: el tutorial (se puede omitir) y luego la pregunta de
    // «Chino desde cero» (también se puede omitir). A quien venía de una
    // versión sin ella y aún no estudia mucho se le pregunta una vez.
    var primeraVez = false;
    if (!_tutorialRevisado) {
      _tutorialRevisado = true;
      if (!await repo.tutorialVisto() && mounted) {
        primeraVez = true;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const PantallaBienvenida()),
        );
        if (!mounted) return;
      }
      if (await repo.rutaDesdeCero() == RutaDesdeCero.sinElegir && mounted) {
        primeraVez = true;
        final empezar = await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => const PantallaComenzarDesdeCero()),
        );
        if (!mounted) return;
        if (empezar != null) await repo.elegirDesdeCero(empezar);
        if (empezar == true && mounted) {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PantallaDesdeCero()));
          if (!mounted) return;
        }
      }
    }
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
    // Por si terminaste la última lección por otro camino (un respaldo).
    final desbloqueado = await repo.desbloquearSiTerminaste();
    final ruta = await repo.rutaDesdeCero();
    final lecciones = await repo.leccionesTerminadas();
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
      _ruta = ruta;
      _lecciones = lecciones;
      _protegida = racha.actual > 0 &&
          protegidos.any((d) => d.year == ayer.year && d.month == ayer.month && d.day == ayer.day);
    });
    if (desbloqueado) {
      final estudiar = await festejarDesbloqueo(context);
      if (!mounted) return;
      if (estudiar) {
        _ir(const PantallaModo()); // al volver se carga (y avisa) lo demás
        return;
      }
    }
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
    // Al final, para no encimarse con lo demás. Recién visto el tutorial (o
    // la pregunta de «Chino desde cero») no se pregunta nada más: eso queda
    // para la siguiente vez.
    if (!_versionRevisada && mounted) {
      _versionRevisada = true;
      await _revisarVersion(preguntar: !primeraVez);
    }
  }

  Future<void> _revisarVersion({required bool preguntar}) async {
    if (!Actualizaciones.disponible) return;
    final repo = DatosApp.de(context);
    var avisar = await repo.avisarVersiones();
    if (avisar == null) {
      if (!preguntar || !mounted) return;
      avisar = await preguntarAvisoVersiones(context);
      if (avisar == null) return; // se cerró sin elegir: se pregunta otro día
      await repo.guardarAvisarVersiones(avisar);
    }
    if (!avisar) return;
    final resultado = await Actualizaciones.revisar(repo);
    final nueva = resultado.nueva;
    if (nueva == null || nueva.version == await repo.versionDescartada() || !mounted) return;
    setState(() => _versionNueva = nueva);
  }

  Future<void> _descartarVersion(VersionNueva nueva) async {
    setState(() => _versionNueva = null);
    await DatosApp.de(context).descartarVersion(nueva.version);
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargarResumen(); // al volver, actualizar el resumen del día
  }

  /// Estudiar, Leer o Practicar: con candado mientras cursas «Chino desde
  /// cero» se explica por qué y se ofrece seguir (o desbloquear ya).
  void _abrir(Widget pantalla) {
    if (_bloqueado) {
      _mostrarCandado();
    } else {
      _ir(pantalla);
    }
  }

  Future<void> _mostrarCandado() async {
    final c = context.colores;
    final total = DesdeCeroRepositorio.totalLecciones;
    final faltan = total - _lecciones.length;
    final eleccion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_outline_rounded, size: 34, color: c.tinta),
              const SizedBox(height: 10),
              Text(
                tr('Primero, «Chino desde cero»'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                faltan == 1
                    ? tr('Te falta 1 lección (unos {0} minutos). Al terminarla se abren Estudiar, Leer y Practicar.',
                        [minutosDesdeCero(_lecciones)])
                    : tr('Te faltan {0} de {1} lecciones (unos {2} minutos). Al terminarlas se abren Estudiar, Leer y Practicar.',
                        [faltan, total, minutosDesdeCero(_lecciones)]),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: c.suave, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.boton,
                  foregroundColor: c.textoBoton,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.pop(contexto, 'seguir'),
                child: Text(tr('Seguir con las lecciones')),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(contexto, 'desbloquear'),
                child: Text(tr('Ya sé lo básico: desbloquear todo'), style: TextStyle(color: c.suave)),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (eleccion) {
      case 'seguir':
        await _ir(const PantallaDesdeCero());
      case 'desbloquear':
        await DatosApp.de(context).elegirDesdeCero(false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Listo: todo desbloqueado. Las lecciones quedan al final de Ajustes.')),
        ));
        await _cargarResumen();
    }
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
              if (_versionNueva case final nueva?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TarjetaVersionNueva(nueva: nueva, onDescartar: () => _descartarVersion(nueva)),
                ),
              const Spacer(),
              const Text('梅字', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w400, letterSpacing: 10)),
              const SizedBox(height: 4),
              Text('Meizi Hanzi', style: TextStyle(fontSize: 14, color: c.tenue, letterSpacing: 2)),
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

              // Mientras cursas «Chino desde cero», es lo principal.
              if (_ruta?.enInicio ?? false) ...[
                _BotonPrincipal(
                  texto: tr('Chino desde cero · {0}/{1}', [_lecciones.length, DesdeCeroRepositorio.totalLecciones]),
                  emoji: '🌱',
                  onTap: () => _ir(const PantallaDesdeCero()),
                ),
                const SizedBox(height: 12),
              ],

              // Estudiar → PantallaModo (con candado mientras tanto).
              _bloqueado
                  ? _BotonSecundario(
                      icono: Icons.lock_outline_rounded,
                      texto: tr('Estudiar'),
                      bloqueado: true,
                      grande: true,
                      onTap: _mostrarCandado,
                    )
                  : _BotonPrincipal(texto: tr('Estudiar'), onTap: () => _ir(const PantallaModo())),
              const SizedBox(height: 12),

              // Botones secundarios → «Leer» (libros graduados) y «Practicar»
              // (tonos, escucha, vocabulario y pinyin con audio). En pantallas
              // angostas o con letra grande pasan a dos renglones.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  _BotonSecundario(
                    icono: _bloqueado ? Icons.lock_outline_rounded : Icons.menu_book_rounded,
                    texto: tr('Leer'),
                    bloqueado: _bloqueado,
                    onTap: () => _abrir(const PantallaBiblioteca()),
                  ),
                  _BotonSecundario(
                    icono: _bloqueado ? Icons.lock_outline_rounded : Icons.headphones_rounded,
                    texto: tr('Practicar'),
                    bloqueado: _bloqueado,
                    onTap: () => _abrir(const PantallaPractica()),
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

/// Botón relleno de tinta ("Estudiar", o «Chino desde cero» mientras lo
/// cursas).
class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({required this.texto, required this.onTap, this.emoji});

  final String texto;
  final String? emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.boton,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: c.bordeTarjeta, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: emoji == null ? 44 : 28, vertical: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji case final e?) ...[
                Text(e, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(texto, style: TextStyle(fontSize: 18, color: c.textoBoton, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón con borde de tinta ("Leer", "Practicar"). Con candado se ve
/// apagado y al tocarlo explica por qué ([bloqueado]); [grande] es para
/// "Estudiar" con candado (mismo tamaño que el botón principal).
class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.bloqueado = false,
    this.grande = false,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final bool bloqueado;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = bloqueado ? c.suave : c.tinta;
    return Semantics(
      hint: bloqueado ? tr('Se abre al terminar «Chino desde cero»') : null,
      child: Opacity(
        opacity: bloqueado ? 0.6 : 1,
        child: Material(
          color: c.tarjeta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: color, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: grande ? 36 : 22, vertical: grande ? 14 : 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(texto, style: TextStyle(fontSize: grande ? 18 : 17, color: color, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
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
