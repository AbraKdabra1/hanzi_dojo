// ─────────────────────────────────────────────────────────────────────────────
// pantalla_radicales.dart — Los 214 radicales Kangxi
//
// Cuadrícula de 3 columnas: cada celda muestra el radical, su número, su
// nombre en español y cuántos caracteres HSK de su familia llevas.
// Toca uno para ver su familia. El botón de arriba estudia los radicales en
// sí, empezando por los que forman más caracteres HSK.
//
// Rendimiento: las celdas NO usan desenfoque (BackdropFilter); ver
// tarjeta_vidrio.dart. Con desenfoque por celda, desplazar la lista trababa.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_estudio.dart';
import 'pantalla_familia_radical.dart';

class PantallaRadicales extends StatefulWidget {
  const PantallaRadicales({super.key, required this.modoNovato});
  final bool modoNovato;

  @override
  State<PantallaRadicales> createState() => _PantallaRadicalesState();
}

class _PantallaRadicalesState extends State<PantallaRadicales> {
  late final Repositorio _repo = DatosApp.de(context);
  final _busqueda = TextEditingController();
  List<Radical> _todos = const [];
  List<Radical> _filtrados = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final lista = await _repo.radicales();
    if (!mounted) return;
    setState(() {
      _todos = lista;
      _cargando = false;
    });
    _filtrar(_busqueda.text);
  }

  /// Filtra por forma (水 o 氵), número, nombre o pinyin.
  void _filtrar(String texto) {
    final q = texto.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? _todos
          : _todos
              .where((r) =>
                  r.todasLasFormas.contains(q) ||
                  '${r.numero}' == q ||
                  r.nombreEs.toLowerCase().contains(q) ||
                  r.pinyin.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargar(); // refrescar avance al volver
  }

  @override
  Widget build(BuildContext context) {
    final vistos = _todos.where((r) => r.practicado).length;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: 'Radicales Kangxi',
          subtitulo: _cargando ? null : '$vistos de 214 practicados',
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: Colors.black54))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _busqueda,
                            onChanged: _filtrar,
                            decoration: InputDecoration(
                              hintText: 'Buscar: 水, 85, agua, shui…',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xB3FFFFFF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Estudiar'),
                          onPressed: () => _ir(PantallaEstudio(
                            filtro: const FiltroEstudio.radicales(),
                            modoNovato: widget.modoNovato,
                          )),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.9,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _filtrados.length,
                      itemBuilder: (_, i) {
                        final r = _filtrados[i];
                        return _CeldaRadical(
                          radical: r,
                          onTap: () => _ir(PantallaFamiliaRadical(numero: r.numero, modoNovato: widget.modoNovato)),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CeldaRadical extends StatelessWidget {
  const _CeldaRadical({required this.radical, required this.onTap});

  final Radical radical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = radical;
    final visto = r.practicado;
    return TarjetaVidrio(
      onTap: onTap,
      radio: 16,
      relleno: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      color: visto ? const Color(0xBFE8F5E9) : const Color(0x99FFFFFF),
      colorBorde: visto ? const Color(0xCCA5D6A7) : const Color(0xB3FFFFFF),
      child: Column(
        children: [
          Row(
            children: [
              Text('${r.numero}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: visto ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E))),
              const Spacer(),
              if (visto) Icon(Icons.check_circle, size: 12, color: Colors.green.shade400),
            ],
          ),
          Expanded(
            child: FittedBox(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: r.formaPrincipal, style: const TextStyle(fontSize: 30, height: 1.0)),
                if (r.variantes.isNotEmpty)
                  TextSpan(
                    text: ' ${r.variantes.first}',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
              ])),
            ),
          ),
          Text(r.nombreEs,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          if (r.totalHsk > 0)
            // borderRadius propio en vez de ClipRRect: sin una capa de recorte por celda.
            LinearProgressIndicator(
              value: r.aprendidosHsk / r.totalHsk,
              minHeight: 3,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: const Color(0x14000000),
              color: const Color(0xFF6A1B9A),
            ),
        ],
      ),
    );
  }
}
