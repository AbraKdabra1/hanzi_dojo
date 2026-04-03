import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'pantalla_estudio.dart';

class PantallaRadicales extends StatefulWidget {
  final bool modoNovato;
  const PantallaRadicales({super.key, required this.modoNovato});

  @override
  State<PantallaRadicales> createState() => _PantallaRadicalesState();
}

class _PantallaRadicalesState extends State<PantallaRadicales> {
  List<Map<String, dynamic>> _radicales = [];
  List<Map<String, dynamic>> _filtrados = [];
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
              final simp = (r['simplificado'] ?? '').toString().toLowerCase();
              final sig  = (r['significados'] ?? '').toString().toLowerCase();
              final pin  = (r['pinyin']       ?? '').toString().toLowerCase();
              final num  = r['numero_radical'].toString();
              return simp.contains(q) ||
                  sig.contains(q) ||
                  pin.contains(q) ||
                  num.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            const Text('Radicales Kangxi',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600,
                    fontSize: 16)),
            Text(
              widget.modoNovato ? '🐣 Modo novato' : '🥋 Modo experto',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Botón estudiar siguiente radical pendiente
          IconButton(
            icon: const Icon(Icons.play_circle_outline,
                color: Colors.black87, size: 24),
            tooltip: "Estudiar siguiente",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PantallaEstudio(
                  nivelHSK: 0,
                  modoNovato: widget.modoNovato,
                  modoRadical: true,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                // Barra de búsqueda
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                  child: TextField(
                    controller: _busqueda,
                    onChanged: _filtrar,
                    decoration: InputDecoration(
                      hintText: 'Buscar por carácter, número o significado...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Contador
                Padding(
                  padding: const EdgeInsets.only(left: 22, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtrados.length} radicales',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ),
                ),

                // Lista de radicales
                Expanded(
                  child: _filtrados.isEmpty
                      ? const Center(
                          child: Text('Sin resultados',
                              style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _filtrados.length,
                          itemBuilder: (context, index) {
                            final r = _filtrados[index];
                            final int num    = r['numero_radical'] ?? 0;
                            final String sig = r['significados']   ?? '';
                            final bool visto = (r['veces_visto'] ?? 0) > 0;

                            return GestureDetector(
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
                              child: Container(
                                decoration: BoxDecoration(
                                  color: visto
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: visto
                                        ? Colors.green.shade200
                                        : Colors.grey.shade200,
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      r['simplificado'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w300),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nº $num',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500),
                                    ),
                                    if (sig.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0),
                                        child: Text(
                                          sig.split(',').first.trim(),
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade400),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}