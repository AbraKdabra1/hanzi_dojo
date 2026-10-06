// ─────────────────────────────────────────────────────────────────────────────
// pantalla_escucha.dart — Ejercicio de escucha
//
// Suena una palabra grabada del nivel elegido y eliges entre cuatro:
//   · Carácter     → cuál se escribe así (sin pinyin: hay que reconocerla).
//   · Significado  → qué quiere decir.
// Los distractores nunca suenan igual que la respuesta (是 / 事) y son del
// mismo largo (practica.dart, PreguntaOpciones.armar).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/audio.dart';
import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/practica.dart';
import '../datos/repositorio_practica.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../idioma.dart';

enum _ModoEscucha { caracter, significado }

class PantallaEscucha extends StatefulWidget {
  const PantallaEscucha({super.key, required this.nivel});

  final int nivel;

  @override
  State<PantallaEscucha> createState() => _PantallaEscuchaState();
}

class _PantallaEscuchaState extends State<PantallaEscucha> {
  static const _porRonda = 10;

  final _azar = Random();
  _ModoEscucha _modo = _ModoEscucha.caracter;
  bool _cargando = true;
  List<PreguntaOpciones> _preguntas = const [];
  int _indice = 0;
  int _aciertos = 0;
  int? _elegida;
  bool _sonando = false;
  DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nuevaRonda());
  }

  @override
  void dispose() {
    Voz.detener();
    super.dispose();
  }

  Future<void> _nuevaRonda() async {
    setState(() {
      _cargando = true;
      _indice = 0;
      _aciertos = 0;
    });
    final repo = DatosApp.de(context);
    final objetivos = await repo.palabrasAlAzar(nivel: widget.nivel, conAudio: true, cantidad: _porRonda);
    final otras = await repo.palabrasAlAzar(nivel: widget.nivel, cantidad: 120);
    final porSignificado = _modo == _ModoEscucha.significado;
    final preguntas = [
      for (final o in objetivos) PreguntaOpciones.armar(o, otras, _azar, porSignificado: porSignificado),
    ];
    if (!mounted) return;
    setState(() {
      _preguntas = preguntas;
      _cargando = false;
    });
    _prepararPregunta();
  }

  void _prepararPregunta() {
    setState(() {
      _elegida = null;
      _inicio = DateTime.now();
    });
    if (_indice < _preguntas.length) _escuchar();
  }

  Future<void> _escuchar({bool lento = false}) async {
    if (_indice >= _preguntas.length) return;
    final palabra = _preguntas[_indice].objetivo.palabra;
    setState(() => _sonando = true);
    await Voz.tocar([Clip.palabra(Audio.nombrePalabra(palabra))], rapidez: lento ? Voz.velocidadLenta : null);
    if (mounted) setState(() => _sonando = false);
  }

  void _contestar(int i) {
    if (_elegida != null) return;
    final pregunta = _preguntas[_indice];
    final bien = i == pregunta.correcta;
    setState(() {
      _elegida = i;
      if (bien) _aciertos++;
    });
    DatosApp.de(context).registrarEjercicio(
      TipoEjercicio.escucha,
      pregunta.objetivo.palabra,
      correcto: bien,
      respuesta: pregunta.opciones[i].palabra,
      duracionMs: DateTime.now().difference(_inicio).inMilliseconds,
    );
  }

  void _siguiente() {
    setState(() => _indice++);
    _prepararPregunta();
  }

  void _cambiarModo(_ModoEscucha modo) {
    if (modo == _modo) return;
    setState(() => _modo = modo);
    _nuevaRonda();
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Escucha'), subtitulo: nombreDeNivel(widget.nivel)),
        body: SafeArea(top: false, child: _cuerpo(context)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final c = context.colores;
    final selector = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_ModoEscucha>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
          ),
          segments: [
            ButtonSegment(value: _ModoEscucha.caracter, label: Text(tr('Carácter'))),
            ButtonSegment(value: _ModoEscucha.significado, label: Text(tr('Significado'))),
          ],
          selected: {_modo},
          onSelectionChanged: (elegido) => _cambiarModo(elegido.first),
        ),
      ),
    );

    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_preguntas.isEmpty) {
      return Column(children: [
        selector,
        Expanded(
          child: MensajeCentrado(emoji: '🔇', titulo: tr('No encontré grabaciones para este nivel')),
        ),
      ]);
    }
    if (_indice >= _preguntas.length) {
      return Column(children: [
        selector,
        Expanded(child: ResumenRonda(aciertos: _aciertos, total: _preguntas.length, onOtraRonda: _nuevaRonda)),
      ]);
    }

    final pregunta = _preguntas[_indice];
    final contestada = _elegida != null;
    final porSignificado = _modo == _ModoEscucha.significado;

    EstadoOpcion estado(int i) {
      if (!contestada) return EstadoOpcion.normal;
      if (i == pregunta.correcta) return EstadoOpcion.correcta;
      if (i == _elegida) return EstadoOpcion.incorrecta;
      return EstadoOpcion.apagada;
    }

    Widget opcion(int i) {
      final p = pregunta.opciones[i];
      return BotonOpcion(
        alto: porSignificado ? 56 : 86,
        estado: estado(i),
        onTap: () => _contestar(i),
        child: porSignificado
            ? Text(p.significado,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.palabra, style: TextStyle(fontSize: p.palabra.length > 2 ? 28 : 34)),
                  // Después de contestar se ve la lectura de cada opción.
                  if (contestada) PinyinPorTonos(silabas: p.silabas, tamano: 13),
                ],
              ),
      );
    }

    return Column(
      children: [
        selector,
        EncabezadoRonda(indice: _indice, total: _preguntas.length, aciertos: _aciertos),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                BotonEscuchar(onEscuchar: _escuchar, onLento: () => _escuchar(lento: true), sonando: _sonando),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: contestada
                          ? Column(
                              key: ValueKey('r$_indice'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(pregunta.objetivo.palabra, style: const TextStyle(fontSize: 30)),
                                PinyinPorTonos(silabas: pregunta.objetivo.silabas, tamano: 18),
                                Text(pregunta.objetivo.significado,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: c.suave)),
                              ],
                            )
                          : Text(porSignificado ? tr('¿Qué significa?') : tr('¿Cuál escuchaste?'),
                              key: const ValueKey('pregunta'), style: TextStyle(fontSize: 16, color: c.suave)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (porSignificado)
                  for (var i = 0; i < pregunta.opciones.length; i++) ...[
                    opcion(i),
                    const SizedBox(height: 10),
                  ]
                else
                  for (var fila = 0; fila < pregunta.opciones.length; fila += 2) ...[
                    Row(
                      children: [
                        Expanded(child: opcion(fila)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: fila + 1 < pregunta.opciones.length ? opcion(fila + 1) : const SizedBox(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
        if (contestada)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _siguiente,
                child: Text(_indice + 1 < _preguntas.length ? tr('Siguiente') : tr('Ver resultado'),
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
      ],
    );
  }
}
