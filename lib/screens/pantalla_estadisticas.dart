// ─────────────────────────────────────────────────────────────────────────────
// pantalla_estadisticas.dart — Mi progreso
//
// De arriba hacia abajo:
//   · Cifras: caracteres estudiados, dominados, repasos para hoy, racha de
//     días seguidos y minutos de esta semana.
//   · Calendario de los últimos 4 meses: cada cuadrito es un día; más oscuro =
//     más repasos (un solo tono, de claro a oscuro). Al tocarlo dice cuántos.
//   · Últimos 7 días: barras con los repasos de cada día.
//   · Precisión: repasos sin ningún trazo fallado (novato y experto).
//   · Los caracteres que más te cuestan, con un botón para practicarlos.
//   · Los trazos que más fallas, dibujados en rojo dentro de su carácter.
//   · Avance por nivel HSK.
// Todo sale del historial de repasos (fase 1).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/estadisticas.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../helpers/cache_trazos.dart';
import '../painters/geometria.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';
import 'pantalla_estudio.dart';

/// Rampa de un solo tono (verde), de poco a mucho. El primero es "sin nada".
const _rampaClara = [Color(0x14000000), Color(0xFFC8E6C9), Color(0xFF81C784), Color(0xFF43A047), Color(0xFF1B5E20)];

/// De noche la rampa va de verde apagado a verde vivo (más días = más brillo).
const _rampaOscura = [Color(0x1FFFFFFF), Color(0xFF0E4429), Color(0xFF006D32), Color(0xFF26A641), Color(0xFF39D353)];

List<Color> _rampaDe(BuildContext context) => context.colores.oscuro ? _rampaOscura : _rampaClara;
const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _diasLargos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String _fecha(DateTime d) => '${_diasLargos[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  List<AvanceNivel>? _niveles;
  int _total = 0;
  int _pendientes = 0;
  List<DiaActividad> _actividad = const [];
  Racha _racha = const Racha(actual: 0, maxima: 0);
  Precision? _precision;
  List<CaracterDificil> _dificiles = const [];
  List<(TrazoFallado, Caracter?)> _trazos = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final hoy = DateTime.now();
    final niveles = await repo.avancePorNivel();
    final total = await repo.totalEstudiados();
    final pendientes = await repo.repasosPendientes();
    final actividad = await repo.actividadPorDia();
    final precision = await repo.precision();
    final dificiles = await repo.caracteresDificiles();
    final trazos = <(TrazoFallado, Caracter?)>[
      for (final t in await repo.trazosFallados()) (t, await repo.caracterConTrazos(t.caracter)),
    ];
    if (!mounted) return;
    setState(() {
      _niveles = niveles;
      _total = total;
      _pendientes = pendientes;
      _actividad = actividad;
      _racha = Estadisticas.racha(actividad.map((d) => d.dia), hoy);
      _precision = precision;
      _dificiles = dificiles;
      _trazos = trazos;
    });
  }

  Future<void> _practicar(Caracter c) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PantallaEstudio(filtro: FiltroEstudio.unico(c.id), modoNovato: true)),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final niveles = _niveles;
    final hoy = DateTime.now();
    final lunes = Estadisticas.lunes(hoy);
    final minutosSemana =
        _actividad.where((d) => !d.dia.isBefore(lunes)).fold(0, (s, d) => s + d.segundos) ~/ 60;
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Mi progreso'),
        body: niveles == null
            ? Center(child: CircularProgressIndicator(color: context.colores.icono))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(child: _Cifra(valor: '$_total', etiqueta: 'caracteres estudiados')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Cifra(
                          valor: '${niveles.fold(0, (s, n) => s + n.dominados)}',
                          etiqueta: 'dominados',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _Cifra(valor: '$_pendientes', etiqueta: 'repasos para hoy')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Cifra(
                          valor: '🔥 ${_racha.actual}',
                          etiqueta: _racha.actual == 1 ? 'día seguido' : 'días seguidos',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _Cifra(valor: '${_racha.maxima}', etiqueta: 'racha más larga')),
                      const SizedBox(width: 10),
                      Expanded(child: _Cifra(valor: '$minutosSemana', etiqueta: 'minutos esta semana')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_actividad.isEmpty)
                    TarjetaVidrio(
                      child: Text(
                        'Cuando practiques, aquí verás tu calendario, tu racha y los caracteres y trazos '
                        'que más te cuestan.',
                        style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.35),
                      ),
                    )
                  else ...[
                    _Seccion(
                      titulo: 'Tu calendario',
                      child: _Calendario(actividad: _actividad, hoy: hoy),
                    ),
                    _Seccion(
                      titulo: 'Últimos 7 días',
                      child: _UltimosDias(actividad: _actividad, hoy: hoy),
                    ),
                    if (_precision case final p? when p.total != null)
                      _Seccion(titulo: 'Precisión (últimos 30 días)', child: _VistaPrecision(precision: p)),
                    if (_dificiles.isNotEmpty)
                      _Seccion(
                        titulo: 'Los que más te cuestan',
                        child: Column(
                          children: [
                            for (final d in _dificiles) _FilaDificil(dificil: d, onPracticar: () => _practicar(d.caracter)),
                          ],
                        ),
                      ),
                    if (_trazos.isNotEmpty)
                      _Seccion(
                        titulo: 'Los trazos que más fallas',
                        child: Column(
                          children: [
                            for (final (t, c) in _trazos)
                              _FilaTrazo(trazo: t, caracter: c, onPracticar: c == null ? null : () => _practicar(c)),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 6),
                  for (final n in niveles) ...[
                    TarjetaVidrio(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            EtiquetaNivel(nivel: n.nivel),
                            const Spacer(),
                            Text('${(n.fraccion * 100).round()} %',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 10),
                          BarraAvance(valor: n.estudiados, total: n.total, color: EtiquetaNivel.colorPara(context, n.nivel)),
                          const SizedBox(height: 4),
                          Text('${n.dominados} dominados',
                              style: TextStyle(fontSize: 11, color: context.colores.tenue)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

// ─── Piezas ──────────────────────────────────────────────────────────────────

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      relleno: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(etiqueta,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: context.colores.tenue)),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaVidrio(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Calendario tipo mapa de calor: columnas = semanas (lunes arriba), las
/// últimas [semanas]. Cada cuadrito tiene su tooltip con el detalle del día.
class _Calendario extends StatelessWidget {
  const _Calendario({required this.actividad, required this.hoy});

  final List<DiaActividad> actividad;
  final DateTime hoy;

  static const semanas = 18;
  static const separacion = 2.0;

  @override
  Widget build(BuildContext context) {
    final porDia = {for (final d in actividad) d.dia: d};
    final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
    final primerLunes = Estadisticas.lunes(hoyDia).subtract(const Duration(days: 7 * (semanas - 1)));
    final etiqueta = TextStyle(fontSize: 10, color: context.colores.tenue);

    return LayoutBuilder(builder: (context, restricciones) {
      const anchoDias = 14.0;
      final lado = ((restricciones.maxWidth - anchoDias) / semanas - separacion).clamp(6.0, 22.0);
      DateTime diaDe(int semana, int fila) =>
          DateTime(primerLunes.year, primerLunes.month, primerLunes.day + semana * 7 + fila);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meses: sobre la semana donde empieza cada uno.
          Row(children: [
            const SizedBox(width: anchoDias),
            for (int s = 0; s < semanas; s++)
              SizedBox(
                width: lado + separacion,
                child: Builder(builder: (_) {
                  final inicio = diaDe(s, 0);
                  final nuevo = s == 0 || diaDe(s - 1, 0).month != inicio.month;
                  return nuevo
                      ? Text(_meses[inicio.month - 1], style: etiqueta, softWrap: false, overflow: TextOverflow.visible)
                      : const SizedBox.shrink();
                }),
              ),
          ]),
          const SizedBox(height: 3),
          for (int fila = 0; fila < 7; fila++)
            Row(children: [
              SizedBox(
                width: anchoDias,
                height: lado + separacion,
                child: fila.isEven ? Text(_dias[fila], style: etiqueta) : null,
              ),
              for (int s = 0; s < semanas; s++)
                Builder(builder: (_) {
                  final dia = diaDe(s, fila);
                  if (dia.isAfter(hoyDia)) return SizedBox(width: lado + separacion);
                  final a = porDia[dia];
                  final n = a?.repasos ?? 0;
                  return Tooltip(
                    message: n == 0
                        ? '${_fecha(dia)} · sin repasos'
                        : '${_fecha(dia)} · $n ${n == 1 ? 'repaso' : 'repasos'} · ${a!.minutos} min',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      width: lado,
                      height: lado,
                      margin: const EdgeInsets.only(right: separacion, bottom: separacion),
                      decoration: BoxDecoration(
                        color: _rampaDe(context)[Estadisticas.nivelCalendario(n)],
                        borderRadius: BorderRadius.circular(3),
                        border: dia == hoyDia ? Border.all(color: context.colores.icono, width: 1.2) : null,
                      ),
                    ),
                  );
                }),
            ]),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Menos ', style: etiqueta),
              for (final c in _rampaDe(context))
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                ),
              Text('  Más', style: etiqueta),
            ],
          ),
        ],
      );
    });
  }
}

/// Barras de los últimos 7 días (repasos). Hoy va resaltado; el resto en gris.
class _UltimosDias extends StatelessWidget {
  const _UltimosDias({required this.actividad, required this.hoy});

  final List<DiaActividad> actividad;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final porDia = {for (final d in actividad) d.dia: d};
    final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
    final dias = [for (int i = 6; i >= 0; i--) DateTime(hoyDia.year, hoyDia.month, hoyDia.day - i)];
    final maximo = dias.map((d) => porDia[d]?.repasos ?? 0).fold(1, (a, b) => a > b ? a : b);
    final deHoy = porDia[hoyDia];
    final etiqueta = TextStyle(fontSize: 11, color: context.colores.suave);
    const alto = 90.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: alto + 34,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in dias)
                Expanded(
                  child: Tooltip(
                    message:
                        '${_fecha(d)} · ${porDia[d]?.repasos ?? 0} repasos · ${porDia[d]?.minutos ?? 0} min',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d == hoyDia && (porDia[d]?.repasos ?? 0) > 0)
                          Text('${porDia[d]!.repasos}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Container(
                          width: 18,
                          height: ((porDia[d]?.repasos ?? 0) / maximo * alto).clamp(2.0, alto),
                          decoration: BoxDecoration(
                            color: d == hoyDia ? _rampaDe(context)[3] : const Color(0xFF9E9E9E),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_dias[d.weekday - 1],
                            style: etiqueta.copyWith(fontWeight: d == hoyDia ? FontWeight.w800 : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          deHoy == null ? 'Hoy aún no practicas.' : 'Hoy: ${deHoy.repasos} repasos en ${deHoy.minutos} min.',
          style: etiqueta,
        ),
      ],
    );
  }
}

class _VistaPrecision extends StatelessWidget {
  const _VistaPrecision({required this.precision});

  final Precision precision;

  @override
  Widget build(BuildContext context) {
    String pct(double f) => '${(f * 100).round()} %';
    final p = precision;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${pct(p.total!)} de tus repasos sin ningún trazo fallado',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          [
            if (p.novato != null) 'Novato: ${pct(p.novato!)}',
            if (p.experto != null) 'Experto: ${pct(p.experto!)}',
            '${p.repasos} repasos',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: context.colores.suave),
        ),
      ],
    );
  }
}

class _FilaDificil extends StatelessWidget {
  const _FilaDificil({required this.dificil, required this.onPracticar});

  final CaracterDificil dificil;
  final VoidCallback onPracticar;

  @override
  Widget build(BuildContext context) {
    final c = dificil.caracter;
    final promedio = dificil.erroresPromedio.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(c.caracter, style: const TextStyle(fontSize: 30))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.pinyin} · ${c.significado}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Text(
                  '$promedio trazos fallados en promedio · ${dificil.veces} '
                  '${dificil.veces == 1 ? 'repaso' : 'repasos'}',
                  style: TextStyle(fontSize: 11.5, color: context.colores.tenue),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onPracticar, child: const Text('Practicar')),
        ],
      ),
    );
  }
}

class _FilaTrazo extends StatelessWidget {
  const _FilaTrazo({required this.trazo, required this.caracter, required this.onPracticar});

  final TrazoFallado trazo;
  final Caracter? caracter;
  final VoidCallback? onPracticar;

  @override
  Widget build(BuildContext context) {
    final c = caracter;
    final total = c?.trazosSvg.length ?? 0;
    final contornos = c == null ? const <Path>[] : CacheTrazos.contornos(c.caracter, c.trazosSvg);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colores.lienzo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colores.bordeLienzo),
            ),
            child: contornos.isEmpty || trazo.indice >= contornos.length
                ? Center(child: Text(trazo.caracter, style: const TextStyle(fontSize: 30)))
                : CustomPaint(painter: _MiniaturaTrazo(contornos, trazo.indice)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trazo.caracter} · trazo ${trazo.indice + 1}${total > 0 ? ' de $total' : ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  'Fallado ${trazo.veces} veces'
                  '${trazo.alReves > 0 ? ' (${trazo.alReves} al revés)' : ''}',
                  style: TextStyle(fontSize: 11.5, color: context.colores.tenue),
                ),
              ],
            ),
          ),
          if (onPracticar != null) TextButton(onPressed: onPracticar, child: const Text('Practicar')),
        ],
      ),
    );
  }
}

/// El carácter en gris con el trazo [indice] en rojo.
class _MiniaturaTrazo extends CustomPainter {
  _MiniaturaTrazo(this.contornos, this.indice);

  final List<Path> contornos;
  final int indice;

  static final Paint _gris = Paint()..color = const Color(0xFFBDBDBD);
  static final Paint _rojo = Paint()..color = const Color(0xFFD32F2F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    GeometriaLienzo.aplicar(canvas, size);
    for (int i = 0; i < contornos.length; i++) {
      canvas.drawPath(contornos[i], i == indice ? _rojo : _gris);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniaturaTrazo old) => old.indice != indice || !identical(old.contornos, contornos);
}
