// ─────────────────────────────────────────────────────────────────────────────
// pantalla_lectura.dart — El lector: un capítulo a la vez
//
// Arriba: título del capítulo, de dónde viene la historia y las palabras
// nuevas que conviene conocer antes de leer.
// En medio: los párrafos (texto_lectura.dart). Toca un carácter para ver su
// ficha; cada párrafo se puede escuchar y traducir.
// Abajo: "Terminé este capítulo" (queda marcado ✓) y el siguiente.
//
// Botones de la barra (se recuerdan para la próxima vez):
//   拼  pinyin encima de los caracteres
//   🌐  traducción de todos los párrafos
//   Aa  tamaño de letra
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../widgets/texto_lectura.dart';

class PantallaLectura extends StatefulWidget {
  const PantallaLectura({super.key, required this.libro, required this.capitulos, required this.indice});

  final Libro libro;
  final List<CapituloLibro> capitulos;

  /// Capítulo con el que se abre (posición en [capitulos]).
  final int indice;

  @override
  State<PantallaLectura> createState() => _PantallaLecturaState();
}

class _PantallaLecturaState extends State<PantallaLectura> {
  late int _indice = widget.indice;
  List<ParrafoLibro>? _parrafos;
  AjustesLectura _ajustes = const AjustesLectura();

  /// Párrafos donde cambiaste la traducción a mano: se ven al revés de como
  /// dice el botón global (si está apagado, estos se traducen; si está
  /// encendido, estos se ocultan).
  final Set<int> _invertidos = {};

  /// Capítulos que marcaste como leídos en esta visita.
  final Set<int> _leidosAhora = {};

  /// Carácter con la ficha abierta: (párrafo, posición).
  (int, int)? _seleccion;

  final ScrollController _desplazamiento = ScrollController();

  CapituloLibro get _capitulo => widget.capitulos[_indice];
  bool get _leido => _capitulo.leido || _leidosAhora.contains(_capitulo.orden);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ajustes = await DatosApp.de(context).ajustesLectura();
      if (mounted) setState(() => _ajustes = ajustes);
      await _cargar();
    });
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _parrafos = null;
      _invertidos.clear();
      _seleccion = null;
    });
    final parrafos = await DatosApp.de(context).parrafos(_capitulo.id, propio: widget.libro.propio);
    if (!mounted) return;
    setState(() => _parrafos = parrafos);
    if (_desplazamiento.hasClients) _desplazamiento.jumpTo(0);
  }

  void _cambiarAjustes(AjustesLectura nuevos) {
    setState(() => _ajustes = nuevos);
    DatosApp.de(context).guardarAjustesLectura(nuevos);
  }

  Future<void> _tocarCaracter(int parrafo, int posicion) async {
    final p = _parrafos![parrafo];
    setState(() => _seleccion = (parrafo, posicion));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FichaCaracterLectura(
        texto: p.caracteres[posicion],
        pinyinEnTexto: p.pinyin[posicion],
        donde: widget.libro.propio ? null : _dondeReporte(p),
      ),
    );
    if (mounted) setState(() => _seleccion = null);
  }

  /// "Libro «Mitos chinos», capítulo 2 · párrafo «盘古以后，地上有了山和河…»"
  String _dondeReporte(ParrafoLibro p) {
    final titulo = widget.libro.tituloEs.isEmpty ? widget.libro.titulo : widget.libro.tituloEs;
    final inicio = p.chino.length > 16 ? '${p.chino.substring(0, 16)}…' : p.chino;
    return 'Libro «$titulo», capítulo ${_capitulo.orden} · párrafo «$inicio»';
  }

  Future<void> _terminar() async {
    await DatosApp.de(context).marcarCapitulo(widget.libro.clave, _capitulo.orden);
    if (!mounted) return;
    setState(() => _leidosAhora.add(_capitulo.orden));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Capítulo ${_capitulo.orden} leído ✓')),
    );
  }

  void _irA(int indice) {
    setState(() => _indice = indice);
    _cargar();
  }

  /// "Terminé este capítulo" y el botón al siguiente.
  Widget _pie(bool hayMas) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _leido
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, color: EtiquetaNivel.colorDe(widget.libro.nivelHsk)),
                  const SizedBox(width: 6),
                  const Text('Capítulo leído', style: TextStyle(fontWeight: FontWeight.w600)),
                ])
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xDE000000),
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Terminé este capítulo'),
                  onPressed: _terminar,
                ),
          if (hayMas) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: Text('Siguiente: ${widget.capitulos[_indice + 1].titulo}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => _irA(_indice + 1),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cap = _capitulo;
    final parrafos = _parrafos;
    final hayMas = _indice + 1 < widget.capitulos.length;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: widget.libro.titulo,
          subtitulo: 'Capítulo ${cap.orden} de ${widget.capitulos.length}',
          acciones: [
            _BotonAjuste(
              activo: _ajustes.pinyin,
              tooltip: 'Pinyin',
              onTap: () => _cambiarAjustes(_ajustes.copia(pinyin: !_ajustes.pinyin)),
              child: const Text('拼', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            // Los libros propios no traen traducción.
            if (!widget.libro.propio)
              _BotonAjuste(
                activo: _ajustes.traduccion,
                tooltip: 'Traducción',
                onTap: () {
                  _invertidos.clear();
                  _cambiarAjustes(_ajustes.copia(traduccion: !_ajustes.traduccion));
                },
                child: const Icon(Icons.translate, size: 20),
              ),
            _BotonAjuste(
              activo: false,
              tooltip: 'Tamaño de letra',
              onTap: () => _cambiarAjustes(_ajustes.copia(tamano: _ajustes.siguienteTamano)),
              child: const Icon(Icons.format_size, size: 21),
            ),
          ],
        ),
        body: parrafos == null
            ? const Center(child: CircularProgressIndicator(color: Colors.black54))
            // Lista perezosa: un capítulo de un libro propio puede tener
            // cientos de párrafos y solo se construyen los que se ven.
            : ListView.builder(
                controller: _desplazamiento,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount: parrafos.length + 2,
                itemBuilder: (context, k) {
                  if (k == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Encabezado(capitulo: cap, tamano: _ajustes.tamano),
                    );
                  }
                  if (k == parrafos.length + 1) return _pie(hayMas);
                  final i = k - 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ParrafoLectura(
                      parrafo: parrafos[i],
                      tamano: _ajustes.tamano,
                      mostrarPinyin: _ajustes.pinyin,
                      mostrarTraduccion: _ajustes.traduccion != _invertidos.contains(i),
                      onAlternarTraduccion: () => setState(() {
                        if (!_invertidos.remove(i)) _invertidos.add(i);
                      }),
                      seleccionado: _seleccion?.$1 == i ? _seleccion?.$2 : null,
                      onTocarCaracter: (posicion) => _tocarCaracter(i, posicion),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Título del capítulo, su origen y las palabras nuevas.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.capitulo, required this.tamano});

  final CapituloLibro capitulo;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (capitulo.tituloPinyin.isNotEmpty)
          Text(capitulo.tituloPinyin,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(capitulo.titulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: tamano + 6, fontWeight: FontWeight.w600, letterSpacing: 2)),
        if (capitulo.tituloEs.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(capitulo.tituloEs,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
        if (capitulo.origen.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(capitulo.origen,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic, height: 1.35)),
        ],
        if (capitulo.palabras.isNotEmpty) ...[
          const SizedBox(height: 14),
          TarjetaVidrio(
            relleno: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Palabras de este capítulo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                for (final p in capitulo.palabras)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(p.chino, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(p.pinyin, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.espanol, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón redondo de la barra que se ve "encendido" cuando está activo.
class _BotonAjuste extends StatelessWidget {
  const _BotonAjuste({required this.activo, required this.tooltip, required this.onTap, required this.child});

  final bool activo;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo ? const Color(0xDE000000) : Colors.transparent,
          ),
          child: IconTheme(
            data: IconThemeData(color: activo ? Colors.white : Colors.black54),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: activo ? Colors.white : Colors.black54),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
