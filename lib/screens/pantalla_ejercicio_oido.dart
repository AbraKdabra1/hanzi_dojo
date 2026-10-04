// ─────────────────────────────────────────────────────────────────────────────
// pantalla_ejercicio_oido.dart — Una ronda de 10 preguntas de oído
//
// Tonos, Escucha o Pinyin (ver datos/oido.dart). Al responder:
//   · acierto → verde y pasa sola a la siguiente;
//   · error → se marca en rojo, se muestra la correcta y puedes tocar cada
//     opción para oírla y comparar (así se aprende la diferencia).
// Al final: resumen y la sesión se guarda (cuenta para tu racha).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/oido.dart';
import '../helpers/pinyin_helper.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaEjercicioOido extends StatefulWidget {
  const PantallaEjercicioOido({super.key, required this.ejercicio, this.tonos = const [1, 2, 3, 4], this.nivelMax = 2});

  final EjercicioOido ejercicio;

  /// Tonos entre los que se elige (solo Tonos).
  final List<int> tonos;

  /// Hasta qué nivel HSK salen caracteres (Escucha y Pinyin).
  final int nivelMax;

  @override
  State<PantallaEjercicioOido> createState() => _PantallaEjercicioOidoState();
}

class _PantallaEjercicioOidoState extends State<PantallaEjercicioOido> {
  static const _total = 10;

  final _inicio = DateTime.now();
  GeneradorTonos? _tonos;
  GeneradorEscucha? _escucha;
  List<Caracter> _caracteresPinyin = const [];
  bool _cargando = true;
  String? _sinDatos;

  int _numero = 0; // pregunta actual (0-based)
  int _aciertos = 0;
  bool _terminado = false;

  // Pregunta actual
  PreguntaTono? _pTono;
  PreguntaEscucha? _pEscucha;
  Caracter? _pPinyin;

  /// Lo que elegiste (tono, id de carácter) o null si aún no respondes.
  Object? _respuesta;
  bool? _acerto;
  ResultadoPinyin? _resultadoPinyin;
  final _texto = TextEditingController();
  Timer? _siguiente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  @override
  void dispose() {
    _siguiente?.cancel();
    _texto.dispose();
    Voz.detener();
    super.dispose();
  }

  Future<void> _preparar() async {
    final repo = DatosApp.de(context);
    final (_, silabas) = await Voz.listas();
    switch (widget.ejercicio) {
      case EjercicioOido.tonos:
        _tonos = GeneradorTonos(silabas: silabas, frecuencia: await repo.frecuenciaSilabas());
      case EjercicioOido.escucha:
        final g = GeneradorEscucha(candidatos: await repo.caracteresDeNiveles(widget.nivelMax), silabas: silabas);
        if (g.alcanza) _escucha = g;
      case EjercicioOido.pinyin:
        _caracteresPinyin = [...await repo.caracteresDeNiveles(widget.nivelMax)]..shuffle();
    }
    if (!mounted) return;
    setState(() {
      _cargando = false;
      final hay = switch (widget.ejercicio) {
        EjercicioOido.tonos => _tonos!.bases.isNotEmpty,
        EjercicioOido.escucha => _escucha != null,
        EjercicioOido.pinyin => _caracteresPinyin.isNotEmpty,
      };
      if (!hay) _sinDatos = 'No hay suficientes grabaciones para este ejercicio.';
    });
    if (_sinDatos == null) _nuevaPregunta();
  }

  void _nuevaPregunta() {
    _siguiente?.cancel();
    setState(() {
      _respuesta = null;
      _acerto = null;
      _resultadoPinyin = null;
      _texto.clear();
      switch (widget.ejercicio) {
        case EjercicioOido.tonos:
          _pTono = _tonos!.siguiente(widget.tonos);
        case EjercicioOido.escucha:
          _pEscucha = _escucha!.siguiente();
        case EjercicioOido.pinyin:
          _pPinyin = _caracteresPinyin[_numero % _caracteresPinyin.length];
      }
    });
    _sonar();
  }

  /// Toca el audio de la pregunta (el de Pinyin suena solo al responder).
  void _sonar() {
    switch (widget.ejercicio) {
      case EjercicioOido.tonos:
        Voz.tocarSilaba(_pTono!.clave);
      case EjercicioOido.escucha:
        Voz.tocarSilaba(_pEscucha!.silaba);
      case EjercicioOido.pinyin:
        final c = _pPinyin!;
        Voz.decir(c.caracter, pinyin: [c.pinyin]);
    }
  }

  void _registrar(bool acierto) {
    setState(() {
      _acerto = acierto;
      if (acierto) _aciertos++;
    });
    HapticFeedback.selectionClick();
    if (widget.ejercicio == EjercicioOido.tonos) {
      DatosApp.de(context).registrarOido('tono', '${_pTono!.tono}', acierto);
    }
    // Acierto: pasa sola a la siguiente (tras oír la respuesta en Pinyin).
    if (acierto) {
      _siguiente = Timer(Duration(milliseconds: widget.ejercicio == EjercicioOido.pinyin ? 1400 : 800), _avanzar);
    }
  }

  void _elegirTono(int tono) {
    if (_respuesta != null) {
      // Ya respondió: tocar una opción la hace sonar para comparar.
      Voz.tocarSilaba('${_pTono!.base}$tono');
      return;
    }
    _respuesta = tono;
    _registrar(tono == _pTono!.tono);
    if (tono != _pTono!.tono) Voz.tocarSilaba('${_pTono!.base}$tono');
  }

  void _elegirCaracter(Caracter c) {
    if (_respuesta != null) {
      Voz.decir(c.caracter, pinyin: [c.pinyin]);
      return;
    }
    _respuesta = c.id;
    _registrar(c.id == _pEscucha!.correcto.id);
  }

  void _comprobarPinyin() {
    if (_respuesta != null || _texto.text.trim().isEmpty) return;
    final c = _pPinyin!;
    final r = revisarPinyin(_texto.text, c);
    _respuesta = _texto.text;
    _resultadoPinyin = r;
    _registrar(r == ResultadoPinyin.correcto);
    Voz.decir(c.caracter, pinyin: [c.pinyin]);
  }

  void _avanzar() {
    if (!mounted) return;
    if (_numero + 1 >= _total) {
      setState(() => _terminado = true);
      DatosApp.de(context).guardarSesion(
        tipo: widget.ejercicio.clave,
        inicio: _inicio,
        segundos: DateTime.now().difference(_inicio).inSeconds,
        preguntas: _total,
        aciertos: _aciertos,
      );
      return;
    }
    _numero++;
    _nuevaPregunta();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: widget.ejercicio.nombre,
          subtitulo: _terminado || _cargando ? null : 'Pregunta ${_numero + 1} de $_total · $_aciertos ✓',
        ),
        body: SafeArea(
          child: _cargando
              ? Center(child: CircularProgressIndicator(color: c.icono))
              : _sinDatos != null
                  ? MensajeCentrado(emoji: '🔇', titulo: _sinDatos!)
                  : _terminado
                      ? _resumen()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: (_numero + (_respuesta == null ? 0 : 1)) / _total,
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(2),
                                backgroundColor: c.separador,
                                color: c.tinta,
                              ),
                              const SizedBox(height: 16),
                              Expanded(child: _pregunta()),
                              if (_respuesta != null && _acerto == false)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: c.boton,
                                      foregroundColor: c.textoBoton,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: _avanzar,
                                    child: Text(_numero + 1 >= _total ? 'Ver resultado' : 'Siguiente'),
                                  ),
                                ),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _pregunta() => switch (widget.ejercicio) {
        EjercicioOido.tonos => _preguntaTono(),
        EjercicioOido.escucha => _preguntaEscucha(),
        EjercicioOido.pinyin => _preguntaPinyin(),
      };

  Widget _botonOir({String texto = 'Oír otra vez'}) {
    final c = context.colores;
    return Column(
      children: [
        Material(
          color: c.tarjeta,
          shape: CircleBorder(side: BorderSide(color: c.bordeTarjeta, width: 1.5)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _sonar,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(Icons.volume_up_rounded, size: 40, color: c.tinta),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(texto, style: TextStyle(fontSize: 12, color: c.tenue)),
      ],
    );
  }

  Widget _mensaje() {
    final c = context.colores;
    if (_acerto == null) return const SizedBox(height: 22);
    final texto = _acerto! ? '¡Bien!' : 'Toca las opciones para oírlas y comparar.';
    return Text(texto,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _acerto! ? (c.oscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32)) : c.suave));
  }

  // ── Tonos ──────────────────────────────────────────────────────────────

  Widget _preguntaTono() {
    final p = _pTono!;
    final c = context.colores;
    return Column(
      children: [
        Text('¿Qué tono escuchas?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.tinta)),
        const SizedBox(height: 18),
        _botonOir(),
        const Spacer(),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            for (final t in p.opciones)
              _Opcion(
                estado: _estado(t, t == p.tono),
                onTap: () => _elegirTono(t),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(PinyinHelper.conTono(p.base, t),
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            color: PinyinHelper.colorDeTono(t, oscuro: c.oscuro))),
                    Text('Tono $t', style: TextStyle(fontSize: 12, color: c.tenue)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _mensaje(),
        const Spacer(),
      ],
    );
  }

  // ── Escucha ────────────────────────────────────────────────────────────

  Widget _preguntaEscucha() {
    final p = _pEscucha!;
    final c = context.colores;
    final respondida = _respuesta != null;
    return Column(
      children: [
        Text('¿Qué carácter escuchas?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.tinta)),
        const SizedBox(height: 18),
        _botonOir(),
        const Spacer(),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            for (final o in p.opciones)
              _Opcion(
                estado: _estado(o.id, o.id == p.correcto.id),
                onTap: () => _elegirCaracter(o),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.caracter, style: TextStyle(fontSize: 44, color: c.tinta, height: 1.15)),
                    if (respondida)
                      Text(o.pinyin,
                          style: TextStyle(
                              fontSize: 14,
                              color: PinyinHelper.colorDeTono(PinyinHelper.tonoDeNumero(o.pinyinNum), oscuro: c.oscuro))),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (respondida)
          Text('${p.correcto.caracter} ${p.correcto.pinyin}: ${p.correcto.significado}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: c.suave)),
        const SizedBox(height: 6),
        _mensaje(),
        const Spacer(),
      ],
    );
  }

  // ── Pinyin ─────────────────────────────────────────────────────────────

  Widget _preguntaPinyin() {
    final ch = _pPinyin!;
    final c = context.colores;
    final respondida = _respuesta != null;
    final verde = c.oscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final rojo = c.oscuro ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
    return SingleChildScrollView(
      child: Column(
        children: [
          Text('¿Cómo se lee?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.tinta)),
          const SizedBox(height: 12),
          TarjetaVidrio(
            relleno: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
            child: Text(ch.caracter, style: TextStyle(fontSize: 96, color: c.tinta, height: 1.1)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _texto,
            autofocus: true,
            enabled: !respondida,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'hao3 o hǎo',
              filled: true,
              fillColor: c.tarjeta,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _comprobarPinyin(),
          ),
          const SizedBox(height: 10),
          // Teclas de tono: agregan el número al final.
          if (!respondida)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final t in [1, 2, 3, 4, 5])
                  ActionChip(
                    label: Text(t == 5 ? 'neutro' : 'tono $t',
                        style: TextStyle(color: PinyinHelper.colorDeTono(t, oscuro: c.oscuro))),
                    onPressed: () {
                      final sinNumero = _texto.text.replaceAll(RegExp(r'[1-5]$'), '');
                      _texto.text = '$sinNumero$t';
                      _texto.selection = TextSelection.collapsed(offset: _texto.text.length);
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (!respondida)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.boton,
                  foregroundColor: c.textoBoton,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _comprobarPinyin,
                child: const Text('Comprobar'),
              ),
            )
          else ...[
            Text(
              switch (_resultadoPinyin!) {
                ResultadoPinyin.correcto => '¡Bien! ${ch.pinyin}',
                ResultadoPinyin.tonoEquivocado => 'Casi: la sílaba está bien, pero es ${ch.pinyin}',
                ResultadoPinyin.incorrecto => 'Se lee ${ch.pinyin}',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _resultadoPinyin == ResultadoPinyin.correcto ? verde : rojo,
              ),
            ),
            const SizedBox(height: 4),
            Text(ch.significado,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.suave)),
            if (ch.otrasLecturas.isNotEmpty)
              Text('También se lee ${ch.otrasLecturas}', style: TextStyle(fontSize: 12, color: c.tenue)),
          ],
        ],
      ),
    );
  }

  /// Estado visual de una opción tras responder.
  _EstadoOpcion _estado(Object valor, bool esCorrecta) {
    if (_respuesta == null) return _EstadoOpcion.normal;
    if (esCorrecta) return _EstadoOpcion.correcta;
    if (valor == _respuesta) return _EstadoOpcion.equivocada;
    return _EstadoOpcion.apagada;
  }

  // ── Resumen ────────────────────────────────────────────────────────────

  Widget _resumen() {
    final c = context.colores;
    final minutos = DateTime.now().difference(_inicio).inSeconds / 60;
    final emoji = _aciertos >= 9
        ? '🏆'
        : _aciertos >= 7
            ? '🎉'
            : _aciertos >= 5
                ? '👍'
                : '💪';
    return MensajeCentrado(
      emoji: emoji,
      titulo: '$_aciertos de $_total',
      texto: _aciertos >= 7
          ? '¡Muy buen oído! (${minutos.toStringAsFixed(1)} min)'
          : 'Con práctica el oído se afina rápido. (${minutos.toStringAsFixed(1)} min)',
      acciones: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.boton, foregroundColor: c.textoBoton),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  PantallaEjercicioOido(ejercicio: widget.ejercicio, tonos: widget.tonos, nivelMax: widget.nivelMax),
            ),
          ),
          child: const Text('Otra ronda'),
        ),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Terminar')),
      ],
    );
  }
}

enum _EstadoOpcion { normal, correcta, equivocada, apagada }

class _Opcion extends StatelessWidget {
  const _Opcion({required this.estado, required this.onTap, required this.child});

  final _EstadoOpcion estado;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    const verde = Color(0xFF43A047);
    const rojo = Color(0xFFE53935);
    final (fondo, borde) = switch (estado) {
      _EstadoOpcion.normal => (c.tarjeta, c.bordeTarjeta),
      _EstadoOpcion.correcta => (verde.withValues(alpha: 0.16), verde),
      _EstadoOpcion.equivocada => (rojo.withValues(alpha: 0.14), rojo),
      _EstadoOpcion.apagada => (c.tarjeta.withValues(alpha: c.tarjeta.a * 0.6), c.bordeTarjeta),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borde, width: estado == _EstadoOpcion.normal ? 1.2 : 2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
