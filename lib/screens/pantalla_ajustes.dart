// ─────────────────────────────────────────────────────────────────────────────
// pantalla_ajustes.dart — Ajustes y acceso a Créditos
//
// Por ahora un solo ajuste: cuántos caracteres NUEVOS quieres por día. Los
// repasos no tienen límite (siempre conviene hacer los que tocan).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_creditos.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  int? _limite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final n = await DatosApp.de(context).limiteNuevosPorDia();
      if (mounted) setState(() => _limite = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final limite = _limite;
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Ajustes'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Caracteres nuevos por día',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Al llegar a este número, la sesión te ofrece parar o seguir. '
                    'Entre 10 y 20 es un buen ritmo para no acumular repasos.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
                  ),
                  if (limite != null)
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: limite.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 9,
                            label: '$limite',
                            onChanged: (v) => setState(() => _limite = v.round()),
                            onChangeEnd: (v) => DatosApp.de(context).guardarLimiteNuevosPorDia(v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('$limite',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PantallaCreditos()),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(child: Text('Créditos y licencias', style: TextStyle(fontSize: 15))),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
