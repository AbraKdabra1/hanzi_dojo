import 'dart:ui';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../widgets/fondo_tinta.dart';
import 'pantalla_estudio.dart';

class PantallaRadicales extends StatefulWidget {
  final bool modoNovato;
  const PantallaRadicales({super.key, required this.modoNovato});

  @override
  State<PantallaRadicales> createState() => _PantallaRadicalesState();
}

class _PantallaRadicalesState extends State<PantallaRadicales> {
  List<Map<String, dynamic>> _radicales = [];
  List<Map<String, dynamic>> _filtrados  = [];
  bool _cargando = true;
  final TextEditingController _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRadicales();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarRadicales() async {
    final lista = await DatabaseHelper.instance.obtenerTodosLosRadicales();
    if (mounted) {
      setState(() {
        _radicales = lista;
        _filtrados  = lista;
        _cargando   = false;
      });
    }
  }

  void _filtrar(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? _radicales
          : _radicales.where((r) {
              final simp = (r['simplificado'] ?? '').toString();
              final sig  = (r['significados'] ?? '').toString().toLowerCase();
              final pin  = (r['pinyin']       ?? '').toString().toLowerCase();
              final num  = r['numero_radical'].toString();
              return simp.contains(q) ||
                  sig.contains(q)     ||
                  pin.contains(q)     ||
                  num.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            children: [
              const Text('Radicales Kangxi',
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              Text(
                widget.modoNovato ? '🐣 Modo novato' : '🥋 Modo experto',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaEstudio(
                          nivelHSK: 0,
                          modoNovato: widget.modoNovato,
                          modoRadical: true,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x22000000),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0x33000000), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.black87, size: 16),
                          SizedBox(width: 4),
                          Text('Estudiar',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black))
            : Column(
                children: [
                  // ── Barra de búsqueda glass ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x8DFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0x99FFFFFF), width: 1),
                          ),
                          child: TextField(
                            controller: _busqueda,
                            onChanged: _filtrar,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar por carácter, número o significado...',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey.shade500, size: 20),
                              suffixIcon: _busqueda.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Colors.grey.shade400,
                                          size: 18),
                                      onPressed: () {
                                        _busqueda.clear();
                                        _filtrar('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Contador y leyenda ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '${_filtrados.length} radicales',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const Spacer(),
                        const _Leyenda(
                            color: Color(0xFFA5D6A7), label: 'Visto'),
                        const SizedBox(width: 12),
                        const _Leyenda(
                            color: Color(0xB3FFFFFF), label: 'Nuevo'),
                      ],
                    ),
                  ),

                  // ── Grid glass ───────────────────────────────────────
                  Expanded(
                    child: _filtrados.isEmpty
                        ? Center(
                            child: Text('Sin resultados',
                                style: TextStyle(
                                    color: Colors.grey.shade500)))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.95,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _filtrados.length,
                            itemBuilder: (context, index) {
                              final r   = _filtrados[index];
                              final int num = r['numero_radical'] ?? 0;
                              final String sig =
                                  (r['significados'] ?? '').toString();
                              final String primerSig = sig.isNotEmpty
                                  ? sig.split(',').first.trim()
                                  : '';
                              final bool visto =
                                  (r['veces_visto'] ?? 0) > 0;

                              return _BotonRadical(
                                caracter: r['simplificado'] ?? '',
                                numero: num,
                                significado: primerSig,
                                visto: visto,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PantallaEstudio(
                                      nivelHSK: 0,
                                      hanziIdBuscado: r['id'],
                                      modoNovato: widget.modoNovato,
                                      modoRadical: true,
                                    ),
                                  ),
                                ),
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

// ─── Botón de cristal individual ─────────────────────────────────────────────
class _BotonRadical extends StatelessWidget {
  final String caracter;
  final int    numero;
  final String significado;
  final bool   visto;
  final VoidCallback onTap;

  const _BotonRadical({
    required this.caracter,
    required this.numero,
    required this.significado,
    required this.visto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colores expresados como Color con alpha en hex para evitar withOpacity
    const Color fondoVisto  = Color(0xBFE8F5E9); // green.shade50 ~75% opacidad
    const Color fondoNuevo  = Color(0x99FFFFFF);  // white ~60%
    const Color bordeVisto  = Color(0xCCA5D6A7);  // green.shade200 ~80%
    const Color bordeNuevo  = Color(0xB3FFFFFF);  // white ~70%
    const Color numVisto    = Color(0xFF2E7D32);  // green.shade700
    const Color numNuevo    = Color(0xFF9E9E9E);  // grey.shade400
    const Color sombraColor = Color(0x0F000000);  // black ~6%

    final Color fondo  = visto ? fondoVisto  : fondoNuevo;
    final Color borde  = visto ? bordeVisto  : bordeNuevo;
    final Color numColor = visto ? numVisto  : numNuevo;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borde, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: sombraColor,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Número (esquina superior izquierda)
                Positioned(
                  top: 7,
                  left: 9,
                  child: Text(
                    '$numero',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: numColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // Check si ya fue visto (esquina superior derecha)
                if (visto)
                  Positioned(
                    top: 7,
                    right: 9,
                    child: Icon(Icons.check_circle,
                        size: 11, color: Colors.green.shade400),
                  ),

                // Carácter y significado (centro)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        caracter,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (significado.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text(
                            significado,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widget de leyenda ────────────────────────────────────────────────────────
class _Leyenda extends StatelessWidget {
  final Color  color;
  final String label;
  const _Leyenda({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFBDBDBD), width: 0.8),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}