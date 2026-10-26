// ─────────────────────────────────────────────────────────────────────────────
// pantalla_ejercicio_frases.dart — Ejercicios de las frases esenciales
//
// Rondas de hasta 10 frases de una situación (o de todas): primero las que
// tocan hoy, luego las que nunca has practicado (frases.dart, elegirRonda).
//   · Escuchar y elegir → suena la frase y eliges qué significa entre cuatro
//                         (los distractores son de la misma situación).
//   · Armar la frase    → ves qué quiere decir y tocas las fichas en orden;
//                         sobran dos. Al comprobar suena la frase.
// Cada respuesta va al repaso espaciado de la frase (registrarFrase): bien a la
// primera, Fácil; si no, Difícil.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/frases.dart';
import '../datos/repositorio_frases.dart';
import '../tema.dart';
import '../widgets/boton_reportar.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../idioma.dart';

enum ModoFrases { escuchar, armar }

class PantallaEjercicioFrases extends StatefulWidget {
  const PantallaEjercicioFrases({super.key, required this.modo, this.situacion});

  final ModoFrases modo;

  /// null = frases de todas las situaciones.
  final Situacion? situacion;

  @override
  State<PantallaEjercicioFrases> createState() => _PantallaEjercicioFrasesState();
}

class _PantallaEjercicioFrasesState extends State<PantallaEjercicioFrases> {
  final _azar = Random();
  bool _cargando = true;

  /// Todas las frases (de aquí salen los distractores) y las de esta ronda.
  List<Frase> _todas = const [];
  List<Frase> _ronda = const [];
  int _indice = 0;
  int _aciertos = 0;
  DateTime _inicio = DateTime.now();
  bool _sonando = false;

  /// null mientras no contestas; después, si estuvo bien.
  bool? _resultado;

  // Escuchar y elegir: la pregunta y la opción que tocaste.
  PreguntaFrase? _pregunta;
  int? _elegida;

  // Armar la frase: las fichas y las que vas poniendo, en orden.
  ArmarFrase? _armar;
  List<int> _puestas = [];

  bool get _escuchando => widget.modo == ModoFrases.escuchar;

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
    final todas = await DatosApp.de(context).frases();
    final candidatas = [
      for (final f in todas)
        if (widget.situacion == null || f.situacion == widget.situacion) f,
    ];
    if (!mounted) return;
    setState(() {
      _todas = todas;
      _ronda = elegirRonda(candidatas, _azar, ahora: DateTime.now());
      _cargando = false;
    });
    _prepararPregunta();
  }

  void _prepararPregunta() {
    if (_indice >= _ronda.length) return;
    final objetivo = _ronda[_indice];
    setState(() {
      _resultado = null;
      _elegida = null;
      _puestas = [];
      _inicio = DateTime.now();
      _pregunta = _escuchando ? PreguntaFrase.armar(objetivo, _todas, _azar) : null;
      _armar = _escuchando ? null : ArmarFrase.armar(objetivo, _todas, _azar);
    });
    if (_escuchando) _escuchar();
  }

  Future<void> _escuchar({bool lento = false}) async {
    if (_indice >= _ronda.length) return;
    final f = _ronda[_indice];
    setState(() => _sonando = true);
    await Voz.decir(f.chino, pinyin: f.silabas, rapidez: lento ? Voz.velocidadLenta : null);
    if (mounted) setState(() => _sonando = false);
  }

  /// Guarda la respuesta en el repaso de la frase y en ejercicios.
  void _registrar({required bool bien, required String respuesta}) {
    setState(() {
      _resultado = bien;
      if (bien) _aciertos++;
    });
    DatosApp.de(context).registrarFrase(
      _ronda[_indice],
      calificacionFrase(bien: bien),
      respuesta: respuesta,
      duracionMs: DateTime.now().difference(_inicio).inMilliseconds,
    );
  }

  void _contestar(int i) {
    if (_resultado != null) return;
    final pregunta = _pregunta!;
    _elegida = i;
    _registrar(bien: i == pregunta.correcta, respuesta: '${pregunta.opciones[i].id}');
  }

  void _tocarFicha(int i) {
    if (_resultado != null) return;
    setState(() {
      if (!_puestas.remove(i)) _puestas.add(i);
    });
  }

  void _comprobar() {
    final armar = _armar!;
    final elegidas = [for (final i in _puestas) armar.fichas[i]];
    _registrar(bien: armar.esCorrecta(elegidas), respuesta: elegidas.map((p) => p.chino).join(' '));
    _escuchar();
  }

  void _siguiente() {
    setState(() => _indice++);
    _prepararPregunta();
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: _escuchando ? tr('Escuchar y elegir') : tr('Armar la frase'),
          subtitulo: widget.situacion?.nombre ?? tr('Frases esenciales'),
          acciones: [
            BotonReportar(
              donde: () => _indice < _ronda.length
                  ? tr('Frase esencial: {0} ({1})', [_ronda[_indice].chino, _ronda[_indice].pinyin])
                  : tr('Frases esenciales'),
            ),
          ],
        ),
        body: SafeArea(top: false, child: _cuerpo(context)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_ronda.isEmpty) return MensajeCentrado(emoji: '💬', titulo: tr('No hay frases para practicar'));
    if (_indice >= _ronda.length) {
      return ResumenRonda(aciertos: _aciertos, total: _ronda.length, onOtraRonda: _nuevaRonda);
    }
    final contestada = _resultado != null;
    return Column(
      children: [
        EncabezadoRonda(indice: _indice, total: _ronda.length, aciertos: _aciertos),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _escuchando ? _escucharYElegir(context) : _armarFrase(context),
          ),
        ),
        if (contestada || !_escuchando)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: contestada
                  ? FilledButton(
                      onPressed: _siguiente,
                      child: Text(_indice + 1 < _ronda.length ? tr('Siguiente') : tr('Ver resultado'),
                          style: const TextStyle(fontSize: 16)),
                    )
                  : FilledButton(
                      onPressed: _puestas.isEmpty ? null : _comprobar,
                      child: Text(tr('Comprobar'), style: const TextStyle(fontSize: 16)),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _escucharYElegir(BuildContext context) {
    final c = context.colores;
    final pregunta = _pregunta!;
    final contestada = _resultado != null;

    EstadoOpcion estado(int i) {
      if (!contestada) return EstadoOpcion.normal;
      if (i == pregunta.correcta) return EstadoOpcion.correcta;
      if (i == _elegida) return EstadoOpcion.incorrecta;
      return EstadoOpcion.apagada;
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        BotonEscuchar(onEscuchar: _escuchar, onLento: () => _escuchar(lento: true), sonando: _sonando),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: contestada
                  ? _Solucion(key: ValueKey('r$_indice'), frase: pregunta.objetivo)
                  : Text(tr('¿Qué significa?'),
                      key: const ValueKey('pregunta'), style: TextStyle(fontSize: 16, color: c.suave)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < pregunta.opciones.length; i++) ...[
          BotonOpcion(
            alto: 56,
            estado: estado(i),
            onTap: () => _contestar(i),
            child: Text(pregunta.opciones[i].traduccion,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _armarFrase(BuildContext context) {
    final c = context.colores;
    final armar = _armar!;
    final resultado = _resultado;
    final colorZona = switch (resultado) {
      true => ColoresRespuesta.bien(context),
      false => ColoresRespuesta.mal(context),
      null => c.bordeLienzo,
    };
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(armar.objetivo.traduccion,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(tr('¿Cómo se dice en chino?'), style: TextStyle(fontSize: 13, color: c.suave)),
        const SizedBox(height: 16),
        // Lo que vas armando: toca una ficha para quitarla.
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.tarjeta,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorZona, width: resultado == null ? 1.2 : 2),
          ),
          child: _puestas.isEmpty
              ? Center(
                  child: Text(tr('Toca las palabras en orden'), style: TextStyle(fontSize: 13, color: c.tenue)),
                )
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in _puestas)
                      _Ficha(pieza: armar.fichas[i], onTap: resultado == null ? () => _tocarFicha(i) : null),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (resultado == null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < armar.fichas.length; i++)
                if (!_puestas.contains(i)) _Ficha(pieza: armar.fichas[i], onTap: () => _tocarFicha(i)),
            ],
          )
        else ...[
          Text(resultado ? tr('¡Así se dice!') : tr('Se dice así:'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: resultado ? ColoresRespuesta.bien(context) : ColoresRespuesta.mal(context),
              )),
          const SizedBox(height: 8),
          _Solucion(frase: armar.objetivo),
          const SizedBox(height: 8),
          BotonVoz(texto: armar.objetivo.chino, pinyin: armar.objetivo.silabas),
        ],
      ],
    );
  }
}

/// La frase completa: chino, pinyin y traducción.
class _Solucion extends StatelessWidget {
  const _Solucion({super.key, required this.frase});

  final Frase frase;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(frase.chino, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26)),
        Text(frase.pinyin, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: c.suave)),
        Text(frase.traduccion,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: c.suave)),
      ],
    );
  }
}

/// Una ficha de «Armar la frase»: la palabra y su pinyin.
class _Ficha extends StatelessWidget {
  const _Ficha({required this.pieza, required this.onTap});

  final PalabraFrase pieza;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.tarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.bordeLienzo, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pieza.chino, style: const TextStyle(fontSize: 22)),
              Text(pieza.pinyin, style: TextStyle(fontSize: 11, color: c.tenue)),
            ],
          ),
        ),
      ),
    );
  }
}
