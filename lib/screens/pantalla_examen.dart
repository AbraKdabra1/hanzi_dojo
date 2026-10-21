// ─────────────────────────────────────────────────────────────────────────────
// pantalla_examen.dart — Simulacro HSK y examen de ubicación (fase 7)
//
// Simulacro: 30 preguntas (escucha, lectura y caracteres) del nivel elegido,
// 12 minutos, sin ver si acertaste hasta el final. Al terminar: calificación
// de 0 a 100 (se aprueba con 60), aciertos por sección y las palabras que
// fallaste para repasarlas.
//
// Ubicación: empieza en HSK 1 y sube mientras aciertes 4 de 5. Al final te
// dice en qué nivel empezar y lo deja elegido para la práctica con audio.
//
// "No lo sé" cuenta como error: es mejor que adivinar para que el resultado
// diga la verdad.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/audio.dart';
import '../datos/datos_app.dart';
import '../datos/examen.dart';
import '../datos/modelos.dart';
import '../datos/repositorio_practica.dart';
import '../idioma.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaExamen extends StatefulWidget {
  /// Simulacro del nivel [nivel] (1-7).
  const PantallaExamen.simulacro({super.key, required int this.nivel});

  /// Examen de ubicación.
  const PantallaExamen.ubicacion({super.key}) : nivel = null;

  final int? nivel;

  bool get esUbicacion => nivel == null;

  @override
  State<PantallaExamen> createState() => _PantallaExamenState();
}

class _PantallaExamenState extends State<PantallaExamen> {
  final _azar = Random();
  final _reloj = Stopwatch();
  final _segundos = ValueNotifier<int>(0);
  Timer? _tic;

  bool _cargando = true;
  bool _terminado = false;
  bool _sonando = false;
  final List<PreguntaExamen> _preguntas = [];
  final List<int?> _respuestas = [];
  int _indice = 0;

  /// Ubicación: nivel que se está preguntando y aciertos de cada nivel.
  int _nivelActual = 1;
  final List<int> _aciertosPorNivel = [];
  int? _mejorAnterior;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _empezar());
  }

  @override
  void dispose() {
    _tic?.cancel();
    _segundos.dispose();
    Voz.detener();
    super.dispose();
  }

  Future<void> _empezar() async {
    final repo = DatosApp.de(context);
    setState(() {
      _cargando = true;
      _terminado = false;
      _preguntas.clear();
      _respuestas.clear();
      _aciertosPorNivel.clear();
      _indice = 0;
      _nivelActual = 1;
    });
    if (widget.esUbicacion) {
      await _agregarNivel(1);
    } else {
      final nivel = widget.nivel!;
      final conAudio = await repo.palabrasAlAzar(nivel: nivel, conAudio: true, cantidad: 40);
      final todas = await repo.palabrasAlAzar(nivel: nivel, cantidad: 200);
      _mejorAnterior = (await repo.mejoresSimulacros())[nivel];
      _preguntas.addAll(Examen.simulacro(conAudio, todas, _azar));
      _respuestas.addAll(List.filled(_preguntas.length, null));
    }
    if (!mounted) return;
    _reloj
      ..reset()
      ..start();
    _tic?.cancel();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      _segundos.value = _reloj.elapsed.inSeconds;
      if (!widget.esUbicacion && _reloj.elapsed.inMinutes >= Examen.minutosSimulacro && !_terminado) {
        _terminar();
      }
    });
    setState(() => _cargando = false);
    _alMostrar();
  }

  Future<void> _agregarNivel(int nivel) async {
    final repo = DatosApp.de(context);
    final conAudio = await repo.palabrasAlAzar(nivel: nivel, conAudio: true, cantidad: 20);
    final todas = await repo.palabrasAlAzar(nivel: nivel, cantidad: 120);
    final nuevas = Examen.ubicacion(conAudio, todas, _azar);
    _preguntas.addAll(nuevas);
    _respuestas.addAll(List.filled(nuevas.length, null));
    _nivelActual = nivel;
  }

  void _alMostrar() {
    if (_indice < _preguntas.length && _preguntas[_indice].seccion == SeccionExamen.escucha) _escuchar();
  }

  Future<void> _escuchar({bool lento = false}) async {
    final palabra = _preguntas[_indice].pregunta.objetivo.palabra;
    setState(() => _sonando = true);
    await Voz.tocar([Clip.palabra(Audio.nombrePalabra(palabra))], rapidez: lento ? Voz.velocidadLenta : null);
    if (mounted) setState(() => _sonando = false);
  }

  Future<void> _responder(int? opcion) async {
    if (_terminado) return;
    _respuestas[_indice] = opcion;
    final siguiente = _indice + 1;

    if (widget.esUbicacion && siguiente % Examen.preguntasUbicacion == 0) {
      // Terminó un nivel: ¿pasa al siguiente?
      final desde = siguiente - Examen.preguntasUbicacion;
      var aciertos = 0;
      for (var k = desde; k < siguiente; k++) {
        if (_respuestas[k] == _preguntas[k].pregunta.correcta) aciertos++;
      }
      _aciertosPorNivel.add(aciertos);
      if (aciertos >= Examen.aciertosParaPasar && _nivelActual < 7) {
        setState(() => _cargando = true);
        await _agregarNivel(_nivelActual + 1);
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _indice = siguiente;
        });
        _alMostrar();
      } else {
        _terminar();
      }
      return;
    }
    if (siguiente >= _preguntas.length) {
      _terminar();
      return;
    }
    setState(() => _indice = siguiente);
    _alMostrar();
  }

  int get _aciertos {
    var n = 0;
    for (var k = 0; k < _preguntas.length; k++) {
      if (_respuestas[k] == _preguntas[k].pregunta.correcta) n++;
    }
    return n;
  }

  void _terminar() {
    if (_terminado) return;
    _reloj.stop();
    _tic?.cancel();
    Voz.detener();
    final repo = DatosApp.de(context);
    if (widget.esUbicacion) {
      final nivel = Examen.nivelSugerido(_aciertosPorNivel);
      repo.registrarEjercicio(Examen.tipo, Examen.elementoUbicacion,
          correcto: true, respuesta: '$nivel', duracionMs: _reloj.elapsedMilliseconds);
      repo.guardarNivelPractica(nivel);
    } else {
      final nota = Examen.calificacion(_aciertos, _preguntas.length);
      repo.registrarEjercicio(Examen.tipo, Examen.elementoSimulacro(widget.nivel!),
          correcto: nota >= Examen.aprobado, respuesta: '$nota', duracionMs: _reloj.elapsedMilliseconds);
    }
    setState(() => _terminado = true);
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: widget.esUbicacion ? tr('Examen de ubicación') : tr('Simulacro {0}', [nombreDeNivel(widget.nivel!)]),
          acciones: [
            if (!_terminado && !_cargando && !widget.esUbicacion)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _segundos,
                    builder: (context, s, _) {
                      final restan = max(0, Examen.minutosSimulacro * 60 - s);
                      return Text(
                        '${restan ~/ 60}:${(restan % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: restan < 60 ? ColoresRespuesta.mal(context) : context.colores.suave,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(top: false, child: _cuerpo(context)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_preguntas.isEmpty) {
      return MensajeCentrado(emoji: '📭', titulo: tr('No hay palabras en este nivel'));
    }
    if (_terminado) return widget.esUbicacion ? _resultadoUbicacion(context) : _resultadoSimulacro(context);

    final c = context.colores;
    final q = _preguntas[_indice];
    final p = q.pregunta;
    final total = _preguntas.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: c.separador, borderRadius: BorderRadius.circular(10)),
                child: Text(q.seccion.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              if (widget.esUbicacion) EtiquetaNivel(nivel: _nivelActual),
              const Spacer(),
              Text(widget.esUbicacion ? '${_indice % Examen.preguntasUbicacion + 1} / ${Examen.preguntasUbicacion}' : '${_indice + 1} / $total',
                  style: TextStyle(fontSize: 13, color: c.suave, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LinearProgressIndicator(
            value: widget.esUbicacion
                ? (_indice % Examen.preguntasUbicacion) / Examen.preguntasUbicacion
                : _indice / total,
            minHeight: 5,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: c.separador,
            color: c.tinta,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              children: [
                SizedBox(height: 150, child: Center(child: _enunciado(context, q))),
                const SizedBox(height: 12),
                if (q.opcionesSonSignificados)
                  for (var i = 0; i < p.opciones.length; i++) ...[
                    BotonOpcion(
                      alto: 54,
                      estado: EstadoOpcion.normal,
                      onTap: () => _responder(i),
                      child: Text(p.opciones[i].significado,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: 10),
                  ]
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < p.opciones.length; i++)
                        SizedBox(
                          width: 140,
                          child: BotonOpcion(
                            alto: 80,
                            estado: EstadoOpcion.normal,
                            onTap: () => _responder(i),
                            child: Text(p.opciones[i].palabra,
                                style: TextStyle(fontSize: p.opciones[i].palabra.length > 2 ? 26 : 32)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton(onPressed: () => _responder(null), child: Text(tr('No lo sé'))),
        ),
      ],
    );
  }

  Widget _enunciado(BuildContext context, PreguntaExamen q) {
    final c = context.colores;
    final p = q.pregunta.objetivo;
    switch (q.seccion) {
      case SeccionExamen.escucha:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BotonEscuchar(onEscuchar: _escuchar, onLento: () => _escuchar(lento: true), sonando: _sonando, tamano: 80),
            const SizedBox(height: 10),
            Text(tr('¿Qué significa lo que escuchas?'), style: TextStyle(fontSize: 14, color: c.suave)),
          ],
        );
      case SeccionExamen.lectura:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.palabra, style: TextStyle(fontSize: p.palabra.length > 3 ? 44 : 60)),
            const SizedBox(height: 6),
            Text(tr('¿Qué significa?'), style: TextStyle(fontSize: 14, color: c.suave)),
          ],
        );
      case SeccionExamen.caracteres:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinyinPorTonos(silabas: p.silabas, tamano: 30),
            const SizedBox(height: 6),
            Text(p.significado,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: c.tinta)),
            const SizedBox(height: 6),
            Text(tr('¿Cómo se escribe?'), style: TextStyle(fontSize: 14, color: c.suave)),
          ],
        );
    }
  }

  Widget _resultadoSimulacro(BuildContext context) {
    final c = context.colores;
    final nota = Examen.calificacion(_aciertos, _preguntas.length);
    final aprobo = nota >= Examen.aprobado;
    final minutos = _reloj.elapsed.inMinutes;
    final segundos = _reloj.elapsed.inSeconds % 60;
    final errores = [
      for (var k = 0; k < _preguntas.length; k++)
        if (_respuestas[k] != _preguntas[k].pregunta.correcta) (_preguntas[k], _respuestas[k]),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TarjetaVidrio(
          child: Column(
            children: [
              Text(aprobo ? '🏅' : '📘', style: const TextStyle(fontSize: 44)),
              Text('$nota',
                  style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: aprobo ? ColoresRespuesta.bien(context) : ColoresRespuesta.mal(context))),
              Text(aprobo ? tr('¡Aprobado! (se aprueba con {0})', [Examen.aprobado]) : tr('Aún no: se aprueba con {0}', [Examen.aprobado]),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.tinta)),
              const SizedBox(height: 4),
              Text(tr('{0} de {1} correctas · {2}:{3}', [_aciertos, _preguntas.length, minutos, segundos.toString().padLeft(2, '0')]),
                  style: TextStyle(fontSize: 13, color: c.suave)),
              if (_mejorAnterior != null)
                Text(tr('Tu mejor calificación anterior: {0}', [_mejorAnterior]),
                    style: TextStyle(fontSize: 12, color: c.tenue)),
              const SizedBox(height: 12),
              for (final s in SeccionExamen.values) _filaSeccion(context, s),
            ],
          ),
        ),
        if (errores.isNotEmpty) ...[
          const SizedBox(height: 12),
          TarjetaVidrio(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Para repasar'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final (q, r) in errores)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 70, child: Text(q.pregunta.objetivo.palabra, style: const TextStyle(fontSize: 22))),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PinyinPorTonos(silabas: q.pregunta.objetivo.silabas, tamano: 14),
                              Text(q.pregunta.objetivo.significado,
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              Text(
                                r == null
                                    ? tr('No respondiste')
                                    : tr('Elegiste: {0}', [
                                        q.opcionesSonSignificados
                                            ? q.pregunta.opciones[r].significado
                                            : q.pregunta.opciones[r].palabra
                                      ]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: ColoresRespuesta.mal(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _empezar,
              icon: const Icon(Icons.replay_rounded),
              label: Text(tr('Otro simulacro')),
            ),
            OutlinedButton(onPressed: () => Navigator.maybePop(context), child: Text(tr('Terminar'))),
          ],
        ),
      ],
    );
  }

  Widget _filaSeccion(BuildContext context, SeccionExamen s) {
    final c = context.colores;
    var total = 0, bien = 0;
    for (var k = 0; k < _preguntas.length; k++) {
      if (_preguntas[k].seccion != s) continue;
      total++;
      if (_respuestas[k] == _preguntas[k].pregunta.correcta) bien++;
    }
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(s.nombre, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: LinearProgressIndicator(
              value: bien / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: c.separador,
              color: ColoresRespuesta.bien(context),
            ),
          ),
          const SizedBox(width: 8),
          Text('$bien / $total', style: TextStyle(fontSize: 12, color: c.tenue)),
        ],
      ),
    );
  }

  Widget _resultadoUbicacion(BuildContext context) {
    final c = context.colores;
    final nivel = Examen.nivelSugerido(_aciertosPorNivel);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TarjetaVidrio(
          child: Column(
            children: [
              const Text('🧭', style: TextStyle(fontSize: 44)),
              Text(tr('Tu nivel para empezar'), style: TextStyle(fontSize: 15, color: c.suave)),
              const SizedBox(height: 4),
              Text(nombreDeNivel(nivel),
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: EtiquetaNivel.colorPara(context, nivel))),
              const SizedBox(height: 8),
              Text(
                tr('Quedó elegido para la práctica con audio. Para escribir, elige este nivel en Estudiar › Niveles HSK.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.suave, height: 1.35),
              ),
              const SizedBox(height: 12),
              for (final (i, a) in _aciertosPorNivel.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      EtiquetaNivel(nivel: i + 1),
                      const SizedBox(width: 10),
                      Text(a >= Examen.aciertosParaPasar ? '✓' : '·',
                          style: TextStyle(
                              fontSize: 16,
                              color: a >= Examen.aciertosParaPasar ? ColoresRespuesta.bien(context) : c.tenue)),
                      const Spacer(),
                      Text('$a / ${Examen.preguntasUbicacion}', style: TextStyle(fontSize: 13, color: c.suave)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: () => Navigator.maybePop(context), child: Text(tr('Listo')))),
      ],
    );
  }
}
