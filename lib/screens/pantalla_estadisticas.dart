// ─────────────────────────────────────────────────────────────────────────────
// pantalla_estadisticas.dart — Tu avance
//
// Totales generales y, por cada nivel HSK: caracteres estudiados (al menos
// una vez) y dominados (su próximo repaso está a 3 semanas o más).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  List<AvanceNivel>? _niveles;
  int _total = 0;
  int _pendientes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final niveles = await repo.avancePorNivel();
    final total = await repo.totalEstudiados();
    final pendientes = await repo.repasosPendientes();
    if (!mounted) return;
    setState(() {
      _niveles = niveles;
      _total = total;
      _pendientes = pendientes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final niveles = _niveles;
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Mi progreso'),
        body: niveles == null
            ? const Center(child: CircularProgressIndicator(color: Colors.black54))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(child: _Cifra(valor: _total, etiqueta: 'caracteres estudiados')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Cifra(
                          valor: niveles.fold(0, (s, n) => s + n.dominados),
                          etiqueta: 'dominados',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _Cifra(valor: _pendientes, etiqueta: 'repasos para hoy')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final n in niveles) ...[
                    TarjetaVidrio(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            EtiquetaNivel(nivel: n.nivel),
                            const Spacer(),
                            Text('${(n.fraccion * 100).round()} %',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 10),
                          BarraAvance(valor: n.estudiados, total: n.total, color: EtiquetaNivel.colorDe(n.nivel)),
                          const SizedBox(height: 4),
                          Text('${n.dominados} dominados',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      relleno: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text('$valor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(etiqueta,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
