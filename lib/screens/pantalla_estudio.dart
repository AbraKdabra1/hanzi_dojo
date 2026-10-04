// ─────────────────────────────────────────────────────────────────────────────
// pantalla_estudio.dart — Sesión de escritura
//
// Arriba: pinyin, significado, audio, ejemplos y el radical del carácter.
// En medio: el lienzo donde lo escribes trazo por trazo.
// Abajo: al terminar, tus errores y los botones Difícil / Medio / Fácil
//        (se resalta el que sugiere la app según tus errores).
//
// Qué carácter sigue lo decide SesionEstudio (repasos vencidos, "Difícil"
// que vuelven en la misma sesión y nuevos hasta tu límite diario).
//
// Al calificar se guarda también en el historial cuánto tardaste, qué trazos
// fallaste (y si fue al revés) y en qué modo estabas.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../datos/sesion_estudio.dart';
import '../datos/reporte.dart' show TipoReporte;
import '../datos/srs.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/lienzo_escritura.dart';
import 'pantalla_familia_radical.dart';
import 'pantalla_reporte.dart';

class PantallaEstudio extends StatefulWidget {
  const PantallaEstudio({super.key, required this.filtro, required this.modoNovato});

  final FiltroEstudio filtro;
  final bool modoNovato;

  @override
  State<PantallaEstudio> createState() => _PantallaEstudioState();
}

class _PantallaEstudioState extends State<PantallaEstudio> {
  late final Repositorio _repo = DatosApp.de(context);
  late final SesionEstudio _sesion = SesionEstudio(FuenteRepositorio(_repo), widget.filtro);
  /// Clave del lienzo. Se crea una nueva por tarjeta para que cada una
  /// empiece limpia (aunque se repita el mismo carácter).
  GlobalKey<LienzoEscrituraState> _claveLienzo = GlobalKey();

  Caracter? _actual;
  List<String> _trazosSvg = const [];
  List<List<Offset>> _medianas = const [];
  Radical? _radical;
  bool _cargando = true;
  bool _completado = false;
  bool _guardando = false;
  int _errores = 0;
  /// Ajuste caligráfico (de Ajustes); se lee una vez al abrir la sesión.
  bool _ajusteCaligrafico = true;

  /// Cuándo apareció la tarjeta actual (para medir cuánto tardaste).
  final Stopwatch _cronometro = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ajuste = await _repo.ajusteCaligrafico();
      if (!mounted) return;
      _ajusteCaligrafico = ajuste;
      await _cargarSiguiente();
    });
  }

  /// true mientras se pide la siguiente tarjeta (evita pedir dos a la vez si
  /// se toca "Estudiar más" dos veces seguidas).
  bool _pidiendo = false;

  Future<void> _cargarSiguiente() async {
    if (_pidiendo) return;
    _pidiendo = true;
    try {
      setState(() => _cargando = true);
      final c = await _sesion.siguiente();
      final r = c == null ? null : await _repo.radical(c.radical);
      if (!mounted) return;
      setState(() {
        _actual = c;
        _radical = r;
        // Los trazos se decodifican una vez por tarjeta, no en cada build.
        _trazosSvg = c?.trazosSvg ?? const [];
        _medianas = c?.medianas ?? const [];
        _cargando = false;
        _completado = false;
        _errores = 0;
        _claveLienzo = GlobalKey();
      });
      _cronometro
        ..reset()
        ..start();
    } finally {
      _pidiendo = false;
    }
  }

  /// Guarda la calificación y pasa a la siguiente tarjeta.
  ///
  /// [_guardando] sigue en true hasta que la siguiente tarjeta ya está en
  /// pantalla, y mientras tanto los botones quedan desactivados: un doble
  /// toque no puede guardar dos veces la misma respuesta.
  Future<void> _calificar(Calificacion c) async {
    final actual = _actual;
    if (actual == null || _guardando) return;
    setState(() => _guardando = true);
    final detalle = DetallePractica(
      duracion: _cronometro.elapsed,
      fallos: _claveLienzo.currentState?.fallos ?? const [],
      modoNovato: widget.modoNovato,
    );
    try {
      await _sesion.responder(actual, c, detalle: detalle);
      if (!mounted) return;
      if (widget.filtro.esUnico) {
        Navigator.pop(context);
        return;
      }
      await _cargarSiguiente();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _verEjemplos(Caracter c) async {
    final ejemplos = await _repo.ejemplos(c.id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaEjemplos(caracter: c, ejemplos: ejemplos),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _actual;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: widget.filtro.titulo,
          subtitulo: widget.modoNovato ? '🐣 Novato' : '🥋 Experto',
          acciones: [
            if (c != null)
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.black54),
                tooltip: 'Reportar un error en este carácter',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PantallaReporte(
                      tipo: TipoReporte.contenido,
                      donde: 'Carácter ${c.caracter} (${c.pinyin}) · ${nombreDeNivel(c.nivelHsk)}',
                    ),
                  ),
                ),
              ),
            if (c != null)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black54),
                tooltip: 'Reiniciar trazos',
                onPressed: () {
                  _claveLienzo.currentState?.reiniciar();
                  setState(() {
                    _completado = false;
                    _errores = 0;
                  });
                },
              ),
          ],
        ),
        body: SafeArea(
          child: c == null
              ? (_cargando
                  ? const Center(child: CircularProgressIndicator(color: Colors.black54))
                  : _vistaFin())
              : Column(
                  children: [
                    Expanded(flex: 3, child: _panelSuperior(c)),
                    Expanded(flex: 6, child: _lienzo(c)),
                    Expanded(flex: 2, child: _panelInferior()),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Panel superior: qué carácter escribir ────────────────────────────────

  Widget _panelSuperior(Caracter c) {
    final r = _radical;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PinyinColoreado(caracter: c),
          const SizedBox(height: 6),
          TextoSignificado(caracter: c, maxLineas: 2),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              BotonVoz(texto: c.caracter, pinyin: [c.pinyin]),
              _Pastilla(
                icono: Icons.menu_book_rounded,
                texto: 'Ejemplos',
                color: const Color(0xFF1565C0),
                onTap: () => _verEjemplos(c),
              ),
              if (r != null)
                _Pastilla(
                  icono: Icons.account_tree_outlined,
                  texto: 'Radical ${r.formaPrincipal} ${r.nombreEs}',
                  color: const Color(0xFF6A1B9A),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PantallaFamiliaRadical(numero: r.numero, modoNovato: widget.modoNovato),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EtiquetaNivel(nivel: c.nivelHsk),
              if (c.nivelEscritura != null) ...[
                const SizedBox(width: 6),
                Text('✍ escritura oficial', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
              const SizedBox(width: 6),
              Text('· ${c.numTrazos} trazos', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Lienzo ───────────────────────────────────────────────────────────────

  Widget _lienzo(Caracter c) {
    // El margen va FUERA del AspectRatio: así el lienzo queda exactamente
    // cuadrado y la cuadrícula 米 coincide con el centro del carácter.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LienzoEscritura(
                key: _claveLienzo,
                caracter: c.caracter,
                trazosSvg: _trazosSvg,
                medianas: _medianas,
                modoNovato: widget.modoNovato,
                ajusteCaligrafico: _ajusteCaligrafico,
                onCompletado: (errores) => setState(() {
                  _completado = true;
                  _errores = errores;
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Panel inferior: calificación ─────────────────────────────────────────

  Widget _panelInferior() {
    if (!_completado) {
      return Center(
        child: Text(
          'Escribe el carácter trazo por trazo',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontStyle: FontStyle.italic),
        ),
      );
    }
    final sugerida = Calificacion.sugerida(_errores);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _errores == 0 ? 'Sin errores ✨' : '$_errores ${_errores == 1 ? 'error' : 'errores'} de trazo',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (cal, color) in const [
              (Calificacion.dificil, Colors.red),
              (Calificacion.medio, Colors.orange),
              (Calificacion.facil, Colors.green),
            ])
              _BotonCalificacion(
                calificacion: cal,
                color: color,
                resaltado: cal == sugerida,
                onTap: _guardando ? null : () => _calificar(cal),
              ),
          ],
        ),
      ],
    );
  }

  // ── Fin de la sesión ─────────────────────────────────────────────────────

  Widget _vistaFin() {
    final resumen = 'Nuevos: ${_sesion.nuevasEnSesion} · Repasados: ${_sesion.repasadasEnSesion}';
    final volver = OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Volver'));
    return switch (_sesion.fin) {
      FinSesion.limiteDiario => MensajeCentrado(
          emoji: '🎯',
          titulo: 'Cumpliste tu meta de caracteres nuevos por hoy',
          texto: '$resumen\n\nPuedes seguir con más nuevos o volver mañana para tus repasos.',
          acciones: [
            volver,
            FilledButton(
              onPressed: () {
                _sesion.estudiarMas();
                _cargarSiguiente();
              },
              child: const Text('Estudiar más'),
            ),
          ],
        ),
      FinSesion.unicoTerminado => MensajeCentrado(emoji: '✅', titulo: 'Práctica terminada', acciones: [volver]),
      _ => MensajeCentrado(
          emoji: '🎉',
          titulo: 'No hay nada pendiente aquí',
          texto: '$resumen\n\nTerminaste los nuevos y los repasos de este grupo por ahora.',
          acciones: [volver],
        ),
    };
  }
}

// ─── Piezas de la pantalla ───────────────────────────────────────────────────

/// Botón redondeado pequeño con ícono y texto.
class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.icono, required this.texto, required this.color, required this.onTap});

  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: 0.30)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonCalificacion extends StatelessWidget {
  const _BotonCalificacion({
    required this.calificacion,
    required this.color,
    required this.resaltado,
    required this.onTap,
  });

  final Calificacion calificacion;
  final MaterialColor color;
  final bool resaltado;
  /// null = desactivado (mientras se guarda la respuesta anterior).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: resaltado ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: resaltado ? color.shade100 : color.shade50,
          elevation: resaltado ? 2 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: resaltado ? BorderSide(color: color.shade300, width: 1.5) : BorderSide.none,
          ),
        ),
        onPressed: onTap,
        child: Text(calificacion.etiqueta,
            style: TextStyle(color: color.shade800, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Hoja inferior con las oraciones de ejemplo.
class _HojaEjemplos extends StatelessWidget {
  const _HojaEjemplos({required this.caracter, required this.ejemplos});

  final Caracter caracter;
  final List<Ejemplo> ejemplos;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFAFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFBDBDBD), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(caracter.caracter, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w400)),
                const SizedBox(width: 12),
                const Text('Ejemplos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (ejemplos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text('Aún no hay ejemplos para este carácter.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                itemCount: ejemplos.length,
                separatorBuilder: (_, _) => const Divider(height: 20, color: Color(0xFFEEEEEE)),
                itemBuilder: (_, i) => _FilaEjemplo(ejemplo: ejemplos[i], resaltar: caracter.caracter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaEjemplo extends StatelessWidget {
  const _FilaEjemplo({required this.ejemplo, required this.resaltar});

  final Ejemplo ejemplo;

  /// Carácter que se resalta en la oración.
  final String resaltar;

  @override
  Widget build(BuildContext context) {
    final esEspanol = ejemplo.espanol != null && ejemplo.espanol!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                for (final ch in ejemplo.chino.split(''))
                  TextSpan(
                    text: ch,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: ch == resaltar ? FontWeight.w700 : FontWeight.w400,
                      color: ch == resaltar ? const Color(0xFFC62828) : Colors.black87,
                    ),
                  ),
              ])),
            ),
            BotonVoz(texto: ejemplo.chino, pinyinPorPalabras: ejemplo.pinyin, tamano: 16),
          ],
        ),
        const SizedBox(height: 2),
        Text(ejemplo.pinyin, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          esEspanol ? ejemplo.traduccion : 'EN  ${ejemplo.traduccion}',
          style: TextStyle(
            fontSize: 14,
            fontStyle: esEspanol ? FontStyle.normal : FontStyle.italic,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
