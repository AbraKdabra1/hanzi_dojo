// ─────────────────────────────────────────────────────────────────────────────
// piezas_desde_cero.dart — Las piezas interactivas de «Chino desde cero»
//
// Cada lección (screens/pantalla_desde_cero.dart) se arma con estas piezas,
// para que se aprenda haciendo y no solo leyendo:
//   FichaHanzi / FilaFichas   un carácter o palabra; al tocarlo suena.
//   SumaHanzi                 parte + parte = ? (se descubre al tocar).
//   PreguntaSimple            opción múltiple con explicación.
//   TablaSonidos              sonidos del pinyin con su pista; al tocar suenan.
//   AdivinaSonido             ¿cuál oíste? entre sílabas parecidas.
//   DibujoTonos / AdivinaTono los cuatro tonos dibujados y ¿qué tono oíste?
//   TablaReglas               una fila por trazo básico o por regla de orden.
//   OrdenHanzi / EscribirHanzi el orden de trazos animado y escribir en el lienzo.
//   DatoGrande                un número que importa, con su explicación.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/audio.dart';
import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../helpers/pinyin_entrada.dart';
import '../helpers/pinyin_helper.dart';
import '../helpers/sensaciones.dart';
import '../idioma.dart';
import '../tema.dart';
import 'animacion_trazos.dart';
import 'boton_voz.dart';
import 'lienzo_escritura.dart';
import 'tarjeta_vidrio.dart';

/// Toca un carácter o palabra con su pinyin (una sílaba por carácter).
Future<void> _sonar(String texto, List<String> pinyin) =>
    Voz.decir(texto, pinyin: pinyin.length == texto.runes.length ? pinyin : null);

/// Toca una sílaba grabada ('ma1').
Future<void> _sonarSilaba(String silaba) => Voz.tocar([Clip.silaba(silaba)]);

/// Un carácter o palabra; al tocarlo suena.
class FichaHanzi extends StatelessWidget {
  const FichaHanzi({
    super.key,
    required this.texto,
    required this.pinyin,
    required this.significado,
    this.nota,
    this.audio,
    this.tamano = 40,
  });

  final String texto;

  /// Como se muestra ('huǒ shān').
  final String pinyin;
  final String significado;

  /// Una línea más, opcional (de dónde viene el dibujo, por ejemplo).
  final String? nota;

  /// Sílabas para el sonido, si no son las de [pinyin] (你好 suena ní hǎo).
  final List<String>? audio;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return TarjetaVidrio(
      relleno: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      onTap: () => _sonar(texto, audio ?? pinyin.split(RegExp(r'\s+'))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texto, style: TextStyle(fontSize: tamano, height: 1.15)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pinyin, style: TextStyle(fontSize: 15, color: c.tinta, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.volume_up_outlined, size: 15, color: c.tenue),
            ],
          ),
          Text(significado, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.suave)),
          if (nota != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(nota!, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: c.tenue)),
            ),
        ],
      ),
    );
  }
}

/// Varias fichas que se acomodan solas.
class FilaFichas extends StatelessWidget {
  const FilaFichas({super.key, required this.fichas});

  final List<FichaHanzi> fichas;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: fichas,
      );
}

/// parte + parte = ?  (el resultado se descubre al tocarlo).
class SumaHanzi extends StatefulWidget {
  const SumaHanzi({super.key, required this.partes, required this.resultado});

  /// (carácter, qué aporta).
  final List<(String, String)> partes;

  /// (carácter, pinyin, significado).
  final (String, String, String) resultado;

  @override
  State<SumaHanzi> createState() => _SumaHanziState();
}

class _SumaHanziState extends State<SumaHanzi> {
  bool _visto = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget pieza(String arriba, String abajo, {VoidCallback? alTocar, bool resaltada = false}) => TarjetaVidrio(
          relleno: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          colorBorde: resaltada ? c.tinta : null,
          onTap: alTocar,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(arriba, style: const TextStyle(fontSize: 34, height: 1.15)),
              Text(abajo, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.suave)),
            ],
          ),
        );
    Widget signo(String s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(s, style: TextStyle(fontSize: 24, color: c.tenue)),
        );
    final (letra, pinyin, significado) = widget.resultado;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: [
        for (var i = 0; i < widget.partes.length; i++) ...[
          if (i > 0) signo('+'),
          pieza(widget.partes[i].$1, widget.partes[i].$2),
        ],
        signo('='),
        pieza(
          _visto ? letra : '?',
          _visto ? '$pinyin · $significado' : tr('toca'),
          resaltada: !_visto,
          alTocar: () {
            setState(() => _visto = true);
            _sonar(letra, pinyin.split(RegExp(r'\s+')));
          },
        ),
      ],
    );
  }
}

/// Opción múltiple: al elegir se ve si era y por qué.
class PreguntaSimple extends StatefulWidget {
  const PreguntaSimple({
    super.key,
    required this.pregunta,
    required this.opciones,
    required this.correcta,
    required this.explicacion,
  });

  final String pregunta;
  final List<String> opciones;
  final int correcta;
  final String explicacion;

  @override
  State<PreguntaSimple> createState() => _PreguntaSimpleState();
}

class _PreguntaSimpleState extends State<PreguntaSimple> {
  int? _elegida;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final elegida = _elegida;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.pregunta, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.opciones.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Opcion(
              texto: widget.opciones[i],
              estado: elegida == null
                  ? null
                  : (i == widget.correcta ? true : (i == elegida ? false : null)),
              onTap: elegida != null
                  ? null
                  : () {
                      Sensaciones.respuesta(i == widget.correcta);
                      setState(() => _elegida = i);
                    },
            ),
          ),
        if (elegida != null)
          Text(
            '${elegida == widget.correcta ? tr('¡Exacto!') : tr('Casi.')} ${widget.explicacion}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: c.suave, height: 1.4),
          ),
      ],
    );
  }
}

/// Un botón de respuesta: null = sin contestar, true = correcta, false = la
/// que elegiste y no era.
class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.estado, required this.onTap});

  final String texto;
  final bool? estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = switch (estado) {
      true => c.oscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      false => c.oscuro ? const Color(0xFFE57373) : const Color(0xFFC62828),
      null => null,
    };
    return TarjetaVidrio(
      relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      colorBorde: color,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(texto, style: TextStyle(fontSize: 16, color: color ?? c.tinta))),
          if (estado != null) Icon(estado! ? Icons.check_circle : Icons.cancel, color: color, size: 20),
        ],
      ),
    );
  }
}

/// Un sonido del pinyin: cómo se escribe, la sílaba grabada y una pista.
class SonidoPinyin {
  const SonidoPinyin(this.letras, this.silaba, this.pista);

  final String letras;
  final String silaba;
  final String pista;
}

class TablaSonidos extends StatelessWidget {
  const TablaSonidos({super.key, required this.sonidos});

  final List<SonidoPinyin> sonidos;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      children: [
        for (final s in sonidos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaVidrio(
              relleno: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              onTap: () => _sonarSilaba(s.silaba),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Text(s.letras, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        Text(PinyinEntrada.numAAcentos(s.silaba), style: TextStyle(fontSize: 13, color: c.suave)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.pista, style: TextStyle(fontSize: 14, color: c.tinta, height: 1.3))),
                  Icon(Icons.volume_up_outlined, size: 18, color: c.tenue),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ¿Cuál oíste? Cada ronda toca una sílaba de un grupo de sílabas parecidas.
class AdivinaSonido extends StatefulWidget {
  const AdivinaSonido({super.key, required this.grupos, this.azar});

  /// Grupos de sílabas grabadas que se confunden ('xi1', 'shi1', 'si1').
  final List<List<String>> grupos;

  /// Para las pruebas (siempre el mismo orden).
  final math.Random? azar;

  @override
  State<AdivinaSonido> createState() => _AdivinaSonidoState();
}

class _AdivinaSonidoState extends State<AdivinaSonido> {
  late final math.Random _azar = widget.azar ?? math.Random();
  int _ronda = 0;
  int _aciertos = 0;
  late List<String> _opciones;
  late String _correcta;
  String? _elegida;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  void _preparar() {
    final grupo = widget.grupos[_ronda % widget.grupos.length];
    _opciones = [...grupo]..shuffle(_azar);
    _correcta = grupo[_azar.nextInt(grupo.length)];
    _elegida = null;
  }

  void _siguiente() {
    setState(() {
      _ronda++;
      _preparar();
    });
    _sonarSilaba(_correcta);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final elegida = _elegida;
    return Column(
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _sonarSilaba(_correcta),
          icon: const Icon(Icons.volume_up_rounded),
          label: Text(tr('Escuchar')),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in _opciones)
              SizedBox(
                width: 96,
                child: _Opcion(
                  texto: PinyinEntrada.numAAcentos(o),
                  estado: elegida == null ? null : (o == _correcta ? true : (o == elegida ? false : null)),
                  onTap: elegida != null
                      ? null
                      : () {
                          final bien = o == _correcta;
                          Sensaciones.respuesta(bien);
                          setState(() {
                            _elegida = o;
                            if (bien) _aciertos++;
                          });
                        },
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (elegida != null) ...[
          Text(
            tr('{0} de {1}', [_aciertos, _ronda + 1]),
            style: TextStyle(fontSize: 14, color: c.suave),
          ),
          TextButton(onPressed: _siguiente, child: Text(tr('Otra'))),
        ] else
          Text(tr('Toca «Escuchar» y elige.'), style: TextStyle(fontSize: 14, color: c.suave)),
      ],
    );
  }
}

/// Los cuatro tonos: la melodía dibujada, la marca y cómo suena (ma).
class DibujoTonos extends StatelessWidget {
  const DibujoTonos({super.key});

  /// Altura (1 grave a 5 aguda) al principio, en medio y al final: la
  /// escala de cinco niveles con que se suelen describir los tonos.
  static const _contornos = [
    [5.0, 5.0, 5.0],
    [3.0, 4.0, 5.0],
    [2.0, 1.0, 3.5],
    [5.0, 3.0, 1.0],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = [
      tr('Alto y parejo, como sosteniendo una nota.'),
      tr('Sube, como cuando preguntas «¿sí?».'),
      tr('Baja hasta el fondo; a veces sube un poco al final.'),
      tr('Baja de golpe, como una orden: «¡no!».'),
    ];
    return Column(
      children: [
        for (var t = 0; t < 4; t++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaVidrio(
              relleno: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              onTap: () => _sonarSilaba('ma${t + 1}'),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 40,
                    child: CustomPaint(
                      painter: _PintorTono(_contornos[t], PinyinHelper.colorDeTono(t + 1, oscuro: c.oscuro), c.separador),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    child: Text(PinyinEntrada.numAAcentos('ma${t + 1}'),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: PinyinHelper.colorDeTono(t + 1, oscuro: c.oscuro))),
                  ),
                  Expanded(
                    child: Text('${tr('{0}.º tono', [t + 1])}: ${textos[t]}',
                        style: TextStyle(fontSize: 13.5, color: c.tinta, height: 1.3)),
                  ),
                  Icon(Icons.volume_up_outlined, size: 18, color: c.tenue),
                ],
              ),
            ),
          ),
        Text(
          tr('Tono neutro: sin marca, corto y suave, como el ma de 吗 (al final de una pregunta).'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: c.suave, height: 1.35),
        ),
      ],
    );
  }
}

class _PintorTono extends CustomPainter {
  _PintorTono(this.niveles, this.color, this.guia);

  final List<double> niveles;
  final Color color;
  final Color guia;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double nivel) => size.height - (nivel - 1) / 4 * size.height;
    final lineaGuia = Paint()
      ..color = guia
      ..strokeWidth = 1;
    for (var n = 1; n <= 5; n += 2) {
      canvas.drawLine(Offset(0, y(n.toDouble())), Offset(size.width, y(n.toDouble())), lineaGuia);
    }
    final camino = Path()
      ..moveTo(0, y(niveles[0]))
      ..quadraticBezierTo(size.width / 2, y(niveles[1]) * 2 - (y(niveles[0]) + y(niveles[2])) / 2, size.width,
          y(niveles[2]));
    canvas.drawPath(
      camino,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorTono viejo) => viejo.color != color || viejo.guia != guia;
}

/// ¿Qué tono oíste? Rondas con sílabas comunes en sus cuatro tonos.
class AdivinaTono extends StatefulWidget {
  const AdivinaTono({super.key, this.azar});

  final math.Random? azar;

  /// Sílabas grabadas en los cuatro tonos.
  static const bases = ['ma', 'ba', 'yi', 'shi', 'wu', 'da'];

  @override
  State<AdivinaTono> createState() => _AdivinaTonoState();
}

class _AdivinaTonoState extends State<AdivinaTono> {
  late final math.Random _azar = widget.azar ?? math.Random();
  late String _base;
  late int _tono;
  int? _elegido;
  int _ronda = 0;
  int _aciertos = 0;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  void _preparar() {
    _base = AdivinaTono.bases[_azar.nextInt(AdivinaTono.bases.length)];
    _tono = 1 + _azar.nextInt(4);
    _elegido = null;
  }

  void _siguiente() {
    setState(() {
      _ronda++;
      _preparar();
    });
    _sonarSilaba('$_base$_tono');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final elegido = _elegido;
    return Column(
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _sonarSilaba('$_base$_tono'),
          icon: const Icon(Icons.volume_up_rounded),
          label: Text(tr('Escuchar')),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var t = 1; t <= 4; t++)
              SizedBox(
                width: 76,
                child: _Opcion(
                  texto: PinyinEntrada.numAAcentos('$_base$t'),
                  estado: elegido == null ? null : (t == _tono ? true : (t == elegido ? false : null)),
                  onTap: elegido != null
                      ? null
                      : () {
                          final bien = t == _tono;
                          Sensaciones.respuesta(bien);
                          setState(() {
                            _elegido = t;
                            if (bien) _aciertos++;
                          });
                        },
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (elegido != null) ...[
          Text(tr('{0} de {1}', [_aciertos, _ronda + 1]), style: TextStyle(fontSize: 14, color: c.suave)),
          TextButton(onPressed: _siguiente, child: Text(tr('Otra'))),
        ] else
          Text(tr('Toca «Escuchar» y elige.'), style: TextStyle(fontSize: 14, color: c.suave)),
      ],
    );
  }
}

/// Filas de (ejemplo, título, explicación): los trazos básicos o las reglas
/// del orden de trazos.
class TablaReglas extends StatelessWidget {
  const TablaReglas({super.key, required this.filas});

  final List<(String, String, String)> filas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      children: [
        for (final (ejemplo, titulo, texto) in filas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaVidrio(
              relleno: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(ejemplo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(texto, style: TextStyle(fontSize: 13, color: c.suave, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Un número grande con lo que significa.
class DatoGrande extends StatelessWidget {
  const DatoGrande({super.key, required this.numero, required this.texto});

  final String numero;
  final String texto;

  @override
  Widget build(BuildContext context) => TarjetaVidrio(
        relleno: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Text(numero, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(width: 14),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 14, color: context.colores.suave, height: 1.3))),
          ],
        ),
      );
}

/// Carga un carácter con sus trazos (para animarlo o escribirlo).
class _ConTrazos extends StatefulWidget {
  const _ConTrazos({required this.caracter, required this.constructor});

  final String caracter;
  final Widget Function(BuildContext context, Caracter c) constructor;

  @override
  State<_ConTrazos> createState() => _ConTrazosState();
}

class _ConTrazosState extends State<_ConTrazos> {
  Caracter? _c;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = await DatosApp.de(context).caracterConTrazos(widget.caracter);
      if (mounted) setState(() => _c = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return c == null ? const SizedBox(height: 200) : widget.constructor(context, c);
  }
}

/// El orden de trazos de un carácter, animado (se repite al tocarlo).
class OrdenHanzi extends StatelessWidget {
  const OrdenHanzi({super.key, required this.caracter});

  final String caracter;

  @override
  Widget build(BuildContext context) => _ConTrazos(
        caracter: caracter,
        constructor: (context, c) => SizedBox(
          height: 240,
          child: AnimacionTrazos(caracter: c.caracter, trazosSvg: c.trazosSvg, medianas: c.medianas),
        ),
      );
}

/// Escribir un carácter en el lienzo, en modo novato (con silueta y guía).
class EscribirHanzi extends StatefulWidget {
  const EscribirHanzi({super.key, required this.caracter});

  final String caracter;

  @override
  State<EscribirHanzi> createState() => _EscribirHanziState();
}

class _EscribirHanziState extends State<EscribirHanzi> {
  bool _listo = false;
  Key _clave = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return _ConTrazos(
      caracter: widget.caracter,
      constructor: (context, car) => LayoutBuilder(builder: (context, r) {
        final lado = math.min(r.maxWidth, 280.0);
        return Column(
          children: [
            Container(
              width: lado,
              height: lado,
              decoration: BoxDecoration(
                color: c.lienzo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.bordeLienzo, width: 1.5),
                boxShadow: [BoxShadow(color: c.sombra, blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LienzoEscritura(
                  key: _clave,
                  caracter: car.caracter,
                  trazosSvg: car.trazosSvg,
                  medianas: car.medianas,
                  modoNovato: true,
                  onCompletado: (_) {
                    Sensaciones.respuesta(true);
                    setState(() => _listo = true);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_listo)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(tr('¡Muy bien!'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.tinta)),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _listo = false;
                      _clave = UniqueKey();
                    }),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(tr('Otra vez')),
                  ),
                ],
              )
            else
              Text(tr('Sigue la silueta. Si te equivocas, te muestra el trazo.'),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.suave)),
          ],
        );
      }),
    );
  }
}
