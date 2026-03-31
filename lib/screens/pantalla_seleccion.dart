import 'package:flutter/material.dart';
import '/database/db_helper.dart';
import 'pantalla_estudio.dart';

class PantallaSeleccion extends StatefulWidget {
  const PantallaSeleccion({super.key});

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  bool _estaBuscando = false;
  List<Map<String, dynamic>> _resultadosBusqueda = [];

  void _alEscribir(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _estaBuscando = false; _resultadosBusqueda = []; });
      return;
    }
    setState(() => _estaBuscando = true);
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'caracteres',
      where: 'simplificado LIKE ? OR pinyin LIKE ? OR significados LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 15,
    );
    if (mounted) setState(() => _resultadosBusqueda = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Biblioteca HSK',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: TextField(
              onChanged: _alEscribir,
              decoration: InputDecoration(
                hintText: 'Buscar hanzi, pinyin o significado...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _estaBuscando
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: 7,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, index) {
                  final nivel = index + 1;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                    title: Text(nivel == 7 ? "HSK 7-9" : "HSK $nivel",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text('Estudiar y repasar tarjetas',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PantallaEstudio(nivelHSK: nivel))),
                  );
                },
              ),
              secondChild: _resultadosBusqueda.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("Sin resultados",
                            style: TextStyle(color: Colors.grey)),
                      ))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: _resultadosBusqueda.length,
                      separatorBuilder: (_,__) =>
                          Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (context, index) {
                        final hanzi = _resultadosBusqueda[index];
                        return ListTile(
                          title: Text(
                              "${hanzi['simplificado']}  (${hanzi['pinyin']})",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          subtitle: Text("${hanzi['significados']}",
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.draw, size: 18, color: Colors.blue),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PantallaEstudio(
                                nivelHSK: hanzi['nivel'],
                                hanziIdBuscado: hanzi['id'],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}