// ─────────────────────────────────────────────────────────────────────────────
// pantalla_tonos.dart — Entrenador de tonos
//
// Sílabas: suena una sílaba grabada (mā, má, mǎ, mà…) y eliges su tono entre
// cuatro botones que dibujan la curva de cada tono. Las 10 preguntas de la
// ronda reparten los cuatro tonos de forma pareja.
//
// Palabras: suena una palabra de dos sílabas y eliges el tono de cada una
// (incluido el neutro). Se omiten las palabras donde el tono cambia al
// hablar (3.º + 3.º se dice 2.º + 3.º; 一 y 不 cambian según lo que sigue):
// la grabación no sonaría como dice el pinyin del diccionario.
//
// Cada respuesta se guarda (tabla ejercicios) para las estadísticas: así la
// app sabe qué tonos confundes.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/audio.dart';
import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/practica.dart';
import '../datos/repositorio_practica.dart';
import '../helpers/pinyin_helper.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';

enum _ModoTonos { silabas, palabras }

class PantallaTonos extends StatefulWidget {
  const PantallaTonos({super.key, required this.nivel});

  final int nivel;

  @override
  State<PantallaTonos> createState() => _PantallaTonosState();
}

class _PantallaTonosState extends State<PantallaTonos> {
  static const _porRonda = 10;

  final _azar = Random();
  _ModoTonos _modo = _ModoTonos.silabas;
  bool _cargando = true;
  List<SilabaTono> _silabas = const [];
  List<Palabra> _palabras = const [];
  int _indice = 0;
  int _aciertos = 0;

  /// Tono elegido (modo sílabas).
  int? _elegido;

  /// Tono elegido para cada sílaba (modo palabras).
  List<int?> _elegidos = [null, null];
  bool _contestada = false;
  bool _sonando = false;
  DateTime _inicio = DateTime.now();

  /// (lo que sonó, lo que elegiste) de los errores de esta ronda.
  final List<(String, String)> _errores = [];

  int get _total => _modo == _ModoTonos.silabas ? _silabas.length : _palabras.length;

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
      _errores.clear();
    });
    final repo = DatosApp.de(context);
    final (_, grabadas) = await Voz.listas();
    var silabas = const <SilabaTono>[];
    var palabras = const <Palabra>[];
    if (_modo == _ModoTonos.silabas) {
      final caracteres = await repo.caracteresParaTonos(nivel: widget.nivel);
      silabas = SilabaTono.equilibradas(SilabaTono.conGrabacion(caracteres, grabadas), _porRonda, _azar);
    } else {
      final candidatas = await repo.palabrasAlAzar(
          nivel: widget.nivel, soloEseNivel: false, conAudio: true, caracteres: 2, sinErhua: true, cantidad: 80);
      palabras = candidatas.where(_sinCambiosDeTono).take(_porRonda).toList();
    }
    if (!mounted) return;
    setState(() {
      _silabas = silabas;
      _palabras = palabras;
      _cargando = false;
    });
    _prepararPregunta();
  }

  /// Palabras cuya grabación suena como dice su pinyin (ver arriba).
  static bool _sinCambiosDeTono(Palabra p) {
    if (p.palabra.contains('一') || p.palabra.contains('不')) return false;
    final t = p.tonos;
    return t.length == 2 && !(t[0] == 3 && t[1] == 3);
  }

  void _prepararPregunta() {
    setState(() {
      _elegido = null;
      _elegidos = [null, null];
      _contestada = false;
      _inicio = DateTime.now();
    });
    if (_indice < _total) _escuchar();
  }

  Future<void> _escuchar({bool lento = false}) async {
    if (_indice >= _total) return;
    final clips = _modo == _ModoTonos.silabas
        ? [Clip.silaba(_silabas[_indice].archivo)]
        : [Clip.palabra(Audio.nombrePalabra(_palabras[_indice].palabra))];
    setState(() => _sonando = true);
    await Voz.tocar(clips, rapidez: lento ? Voz.velocidadLenta : null);
    if (mounted) setState(() => _sonando = false);
  }

  int get _duracionMs => DateTime.now().difference(_inicio).inMilliseconds;

  void _contestarSilaba(int tono) {
    if (_contestada) return;
    final s = _silabas[_indice];
    final bien = tono == s.tono;
    final elemento = s.archivo.replaceAll('_', '');
    setState(() {
      _elegido = tono;
      _contestada = true;
      if (bien) _aciertos++;
    });
    if (!bien) _errores.add((elemento, '$tono'));
    DatosApp.de(context)
        .registrarEjercicio(TipoEjercicio.tono, elemento, correcto: bien, respuesta: '$tono', duracionMs: _duracionMs);
    if (!bien) _escuchar(); // que suene otra vez, ya sabiendo cuál era
  }

  void _elegirEnPalabra(int silaba, int tono) {
    if (_contestada) return;
    setState(() => _elegidos[silaba] = tono);
    if (_elegidos.every((t) => t != null)) _contestarPalabra();
  }

  void _contestarPalabra() {
    final p = _palabras[_indice];
    final esperados = p.tonos;
    final elegidos = [for (final t in _elegidos) t ?? 0];
    final bien = esperados.length == elegidos.length &&
        [for (var k = 0; k < esperados.length; k++) esperados[k] == elegidos[k]].every((b) => b);
    final elemento = p.claves.join(' ');
    final respuesta = elegidos.join(' ');
    setState(() {
      _contestada = true;
      if (bien) _aciertos++;
    });
    if (!bien) _errores.add((elemento, respuesta));
    DatosApp.de(context).registrarEjercicio(TipoEjercicio.tonosPalabra, elemento,
        correcto: bien, respuesta: respuesta, duracionMs: _duracionMs);
    if (!bien) _escuchar();
  }

  void _siguiente() {
    setState(() => _indice++);
    _prepararPregunta();
  }

  void _cambiarModo(_ModoTonos modo) {
    if (modo == _modo) return;
    setState(() => _modo = modo);
    _nuevaRonda();
  }

  String? _detalleRonda() {
    final confusiones = confusionesDeTono(_errores, limite: 1);
    if (confusiones.isEmpty) return null;
    final c = confusiones.first;
    return 'Lo que más confundiste: el ${c.esperado}.º tono (${nombreDeTono(c.esperado)}) '
        'con el ${c.elegido}.º (${nombreDeTono(c.elegido)}), ${c.veces} veces.';
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: 'Tonos', subtitulo: nombreDeNivel(widget.nivel)),
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
        child: SegmentedButton<_ModoTonos>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
          ),
          segments: const [
            ButtonSegment(value: _ModoTonos.silabas, label: Text('Sílabas')),
            ButtonSegment(value: _ModoTonos.palabras, label: Text('Palabras')),
          ],
          selected: {_modo},
          onSelectionChanged: (elegido) => _cambiarModo(elegido.first),
        ),
      ),
    );

    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_total == 0) {
      return Column(children: [
        selector,
        const Expanded(
          child: MensajeCentrado(
            emoji: '🔇',
            titulo: 'No encontré grabaciones para este nivel',
            texto: 'Prueba con otro nivel o con el otro modo.',
          ),
        ),
      ]);
    }
    if (_indice >= _total) {
      return Column(children: [
        selector,
        Expanded(
          child: ResumenRonda(
            aciertos: _aciertos,
            total: _total,
            onOtraRonda: _nuevaRonda,
            detalle: _detalleRonda(),
          ),
        ),
      ]);
    }

    return Column(
      children: [
        selector,
        EncabezadoRonda(indice: _indice, total: _total, aciertos: _aciertos),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                BotonEscuchar(
                  onEscuchar: _escuchar,
                  onLento: () => _escuchar(lento: true),
                  sonando: _sonando,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _contestada
                          ? _revelado(context)
                          : Text(
                              _modo == _ModoTonos.silabas
                                  ? '¿Qué tono escuchaste?'
                                  : '¿Qué tono tiene cada sílaba?',
                              key: const ValueKey('pregunta'),
                              style: TextStyle(fontSize: 16, color: c.suave),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_modo == _ModoTonos.silabas) _opcionesSilaba() else _opcionesPalabra(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _contestada
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _siguiente,
                      child: Text(_indice + 1 < _total ? 'Siguiente' : 'Ver resultado',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Lo que sonaba, después de contestar.
  Widget _revelado(BuildContext context) {
    final c = context.colores;
    if (_modo == _ModoTonos.silabas) {
      final s = _silabas[_indice];
      final bien = _elegido == s.tono;
      return Column(
        key: ValueKey('s$_indice'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bien ? '¡Correcto!' : 'Era el ${s.tono}.º tono',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: bien ? ColoresRespuesta.bien(context) : ColoresRespuesta.mal(context))),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.caracter, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 14),
              Text(s.pinyin,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: PinyinHelper.colorDeTono(s.tono, oscuro: c.oscuro))),
            ],
          ),
          Text(s.significado,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.suave)),
        ],
      );
    }
    final p = _palabras[_indice];
    final elegidos = [for (final t in _elegidos) t ?? 0];
    final bien = p.tonos.join() == elegidos.join();
    return Column(
      key: ValueKey('p$_indice'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(bien ? '¡Correcto!' : 'Era ${p.tonos.map((t) => t == 5 ? 'neutro' : '$t.º').join(' + ')}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: bien ? ColoresRespuesta.bien(context) : ColoresRespuesta.mal(context))),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.palabra, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            PinyinPorTonos(silabas: p.silabas, tamano: 24),
          ],
        ),
        Text(p.significado,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.suave)),
      ],
    );
  }

  EstadoOpcion _estado(int tono, int correcto, int? elegido) {
    if (!_contestada) return tono == elegido ? EstadoOpcion.elegida : EstadoOpcion.normal;
    if (tono == correcto) return EstadoOpcion.correcta;
    if (tono == elegido) return EstadoOpcion.incorrecta;
    return EstadoOpcion.apagada;
  }

  Widget _opcionesSilaba() {
    final correcto = _silabas[_indice].tono;
    Widget boton(int tono) => Expanded(
          child: BotonOpcion(
            alto: 92,
            estado: _estado(tono, correcto, _elegido),
            onTap: () => _contestarSilaba(tono),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ContornoTono(tono: tono, ancho: 52, alto: 30),
                const SizedBox(height: 6),
                Text('$tono.º tono', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(nombreDeTono(tono), style: TextStyle(fontSize: 12, color: context.colores.suave)),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(children: [boton(1), const SizedBox(width: 12), boton(2)]),
        const SizedBox(height: 12),
        Row(children: [boton(3), const SizedBox(width: 12), boton(4)]),
      ],
    );
  }

  Widget _opcionesPalabra(BuildContext context) {
    final p = _palabras[_indice];
    final esperados = p.tonos;
    return Column(
      children: [
        for (var k = 0; k < 2; k++) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 4),
              child: Text(k == 0 ? '1.ª sílaba' : '2.ª sílaba',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colores.tenue)),
            ),
          ),
          Row(
            children: [
              for (final tono in [1, 2, 3, 4, 5]) ...[
                if (tono > 1) const SizedBox(width: 8),
                Expanded(
                  child: BotonOpcion(
                    alto: 64,
                    estado: _estado(tono, esperados.length > k ? esperados[k] : 0, _elegidos[k]),
                    onTap: () => _elegirEnPalabra(k, tono),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ContornoTono(tono: tono, ancho: 30, alto: 18),
                        const SizedBox(height: 4),
                        Text(tono == 5 ? '·' : '$tono',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
