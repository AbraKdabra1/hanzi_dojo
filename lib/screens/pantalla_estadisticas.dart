import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  List<Map<String, dynamic>> _datosPorNivel = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final db = await DatabaseHelper.instance.database;
    final stats = await db.rawQuery('''
      SELECT nivel,
             COUNT(id) as total,
             SUM(CASE WHEN veces_visto > 0 THEN 1 ELSE 0 END) as estudiados
      FROM caracteres
      GROUP BY nivel
      ORDER BY nivel ASC
    ''');
    if (mounted) setState(() { _datosPorNivel = stats; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mi Progreso',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _datosPorNivel.length,
              itemBuilder: (context, index) {
                final d = _datosPorNivel[index];
                final int nivel = d['nivel'];
                final int total = d['total'];
                final int estudiados = d['estudiados'] ?? 0;
                final double pct = total > 0 ? estudiados / total : 0.0;

                if (nivel > 7 || nivel == 10) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60, height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: pct,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.black87,
                            ),
                            Text("${(pct * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nivel == 7 ? "HSK 7-9 (Avanzado)" : "Nivel HSK $nivel",
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text("$estudiados de $total hanzi aprendidos",
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 14)),
                                    // Botón temporal de diagnóstico
                            ElevatedButton(
                              onPressed: () async {
                                final db = await DatabaseHelper.instance.database;
                                final res = await db.rawQuery(
                                  'SELECT nivel, COUNT(*) as total, '
                                  'SUM(CASE WHEN trazos IS NOT NULL AND trazos != "[]" THEN 1 ELSE 0 END) as con_trazos, '
                                  'SUM(CASE WHEN es_radical = 1 THEN 1 ELSE 0 END) as radicales '
                                  'FROM caracteres GROUP BY nivel ORDER BY nivel'
                                );
                                for (var r in res) { debugPrint('$r'); }
                              },
                              child: const Text('Diagnóstico DB'),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}