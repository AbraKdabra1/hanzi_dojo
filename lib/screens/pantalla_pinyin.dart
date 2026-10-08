// ─────────────────────────────────────────────────────────────────────────────
// pantalla_pinyin.dart — Escribe el pinyin
//
// Ves una palabra (con su significado como pista) y escribes cómo se lee.
// Vale con números (hao3), con acentos (hǎo) o sin número para el tono
// neutro (ba4ba). Los botones de tono agregan el número donde está el cursor,
// y debajo se ve cómo queda con acentos mientras escribes.
// Al comprobar, cada sílaba se pinta de su color de tono y la que fallaste
// se subraya en rojo; suena la grabación.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/practica.dart';
import '../datos/repositorio_practica.dart';
import '../helpers/pinyin_entrada.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../idioma.dart';

class PantallaPinyin extends StatefulWidget {
  const PantallaPinyin({super.key, required this.nivel});

  final int nivel;

  @override
  State<PantallaPinyin> createState() => _PantallaPinyinState();
}

class _PantallaPinyinState extends State<PantallaPinyin> {
  static const _porRonda = 10;

  final _texto = TextEditingController();
  final _foco = FocusNode();
  bool _cargando = true;
  List<Palabra> _palabras = const [];
  Set<String> _bases = const {};
  int _indice = 0;
  int _aciertos = 0;
  ResultadoPinyin? _resultado;
  List<String>? _escritas;
  DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _nuevaRonda());
  }

  @override
  void dispose() {
    Voz.detener();
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _nuevaRonda() async {
    setState(() {
      _cargando = true;
      _indice = 0;
      _aciertos = 0;
    });
    final repo = DatosApp.de(context);
    final (_, grabadas) = await Voz.listas();
    final palabras = await repo.palabrasAlAzar(nivel: widget.nivel, sinErhua: true, cantidad: _porRonda);
    if (!mounted) return;
    setState(() {
      _bases = PinyinEntrada.basesDe(grabadas);
      _palabras = palabras;
      _cargando = false;
    });
    _prepararPregunta();
  }

  void _prepararPregunta() {
    _texto.clear();
    setState(() {
      _resultado = null;
      _escritas = null;
      _inicio = DateTime.now();
    });
    if (_indice < _palabras.length) _foco.requestFocus();
  }

  /// Agrega el número de tono donde está el cursor.
  void _ponerTono(int tono) {
    final valor = _texto.value;
    final sel = valor.selection;
    final inicio = sel.isValid ? sel.start : valor.text.length;
    final fin = sel.isValid ? sel.end : valor.text.length;
    final nuevo = valor.text.replaceRange(inicio, fin, '$tono');
    _texto.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: inicio + 1),
    );
    _foco.requestFocus();
  }

  void _comprobar({bool rendirse = false}) {
    if (_resultado != null) return;
    final p = _palabras[_indice];
    final escritas = rendirse ? null : PinyinEntrada.analizar(_texto.text, _bases);
    final resultado = PinyinEntrada.comparar(p.claves, escritas);
    final bien = resultado.veredicto == Veredicto.correcto;
    setState(() {
      _resultado = resultado;
      _escritas = escritas;
      if (bien) _aciertos++;
    });
    DatosApp.de(context).registrarEjercicio(
      TipoEjercicio.pinyin,
      p.palabra,
      correcto: bien,
      respuesta: escritas?.join(' ') ?? (rendirse ? '?' : _texto.text.trim()),
      duracionMs: DateTime.now().difference(_inicio).inMilliseconds,
    );
    _foco.unfocus();
    Voz.decir(p.palabra, pinyin: p.pinyinPorCaracter);
  }

  void _siguiente() {
    setState(() => _indice++);
    _prepararPregunta();
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Pinyin'), subtitulo: nombreDeNivel(widget.nivel)),
        body: SafeArea(top: false, child: _cuerpo(context)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final c = context.colores;
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_palabras.isEmpty) {
      return MensajeCentrado(emoji: '📭', titulo: tr('No hay palabras en este nivel'));
    }
    if (_indice >= _palabras.length) {
      return ResumenRonda(aciertos: _aciertos, total: _palabras.length, onOtraRonda: _nuevaRonda);
    }

    final p = _palabras[_indice];
    final resultado = _resultado;
    final previa = PinyinEntrada.vistaPrevia(_texto.text, _bases);

    return Column(
      children: [
        EncabezadoRonda(indice: _indice, total: _palabras.length, aciertos: _aciertos),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(p.palabra, style: TextStyle(fontSize: p.palabra.length > 3 ? 48 : 64)),
                const SizedBox(height: 4),
                Text(p.significado,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.suave)),
                const SizedBox(height: 24),
                if (resultado == null) ...[
                  TextField(
                    controller: _texto,
                    focusNode: _foco,
                    autocorrect: false,
                    enableSuggestions: false,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 22, letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: tr('p. ej. ni3hao3 o nǐhǎo'),
                      hintStyle: TextStyle(color: c.tenue, fontSize: 16),
                      filled: true,
                      fillColor: c.tarjeta,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (_) => _comprobar(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final tono in [1, 2, 3, 4, 5]) ...[
                        if (tono > 1) const SizedBox(width: 8),
                        Expanded(
                          child: BotonOpcion(
                            alto: 48,
                            estado: EstadoOpcion.normal,
                            onTap: () => _ponerTono(tono),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ContornoTono(tono: tono, ancho: 18, alto: 12),
                                const SizedBox(width: 4),
                                Text('$tono', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 30,
                    child: Text(
                      previa ?? (_texto.text.trim().isEmpty ? '' : '…'),
                      style: TextStyle(fontSize: 20, color: c.suave),
                    ),
                  ),
                ] else
                  _resultadoVista(context, p, resultado),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: resultado == null
              ? Row(
                  children: [
                    TextButton(onPressed: () => _comprobar(rendirse: true), child: Text(tr('No sé'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _texto.text.trim().isEmpty ? null : _comprobar,
                          child: Text(tr('Comprobar'), style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _siguiente,
                    child: Text(_indice + 1 < _palabras.length ? tr('Siguiente') : tr('Ver resultado'),
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _resultadoVista(BuildContext context, Palabra p, ResultadoPinyin r) {
    final c = context.colores;
    final (titulo, color) = switch (r.veredicto) {
      Veredicto.correcto => (tr('¡Correcto!'), ColoresRespuesta.bien(context)),
      Veredicto.tonos => (tr('Casi: las sílabas están bien, revisa los tonos'), ColoresRespuesta.mal(context)),
      Veredicto.incorrecto => (tr('Se lee así:'), ColoresRespuesta.mal(context)),
    };
    final escritas = _escritas;
    return Column(
      children: [
        Text(titulo,
            textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PinyinPorTonos(silabas: p.silabas, tamano: 30, marcadas: r.silabasBien),
            const SizedBox(width: 12),
            BotonVoz(texto: p.palabra, pinyin: p.pinyinPorCaracter),
          ],
        ),
        if (r.veredicto != Veredicto.correcto && escritas != null) ...[
          const SizedBox(height: 8),
          Text(tr('Escribiste: {0}', [escritas.map(PinyinEntrada.numAAcentos).join(' ')]),
              style: TextStyle(fontSize: 14, color: c.tenue)),
        ],
      ],
    );
  }
}
