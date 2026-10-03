// ─────────────────────────────────────────────────────────────────────────────
// pantalla_ajustes.dart — Ajustes y acceso a Créditos
//
// · Cuántos caracteres NUEVOS quieres por día. Los repasos no tienen límite
//   (siempre conviene hacer los que tocan).
// · Ajuste caligráfico: si cada trazo correcto se acomoda (con un rebote
//   suave) en la forma exacta del pincel, o se queda como lo dibujaste.
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
  bool? _ajuste;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = DatosApp.de(context);
      final n = await repo.limiteNuevosPorDia();
      final ajuste = await repo.ajusteCaligrafico();
      if (mounted) {
        setState(() {
          _limite = n;
          _ajuste = ajuste;
        });
      }
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
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Acomodar mis trazos a la caligrafía',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'Cada trazo correcto se transforma, con un rebote suave, en la forma '
                  'exacta del pincel. Apágalo si prefieres ver tu trazo tal cual.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
                ),
                value: _ajuste ?? true,
                onChanged: _ajuste == null
                    ? null
                    : (v) {
                        setState(() => _ajuste = v);
                        DatosApp.de(context).guardarAjusteCaligrafico(v);
                      },
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
