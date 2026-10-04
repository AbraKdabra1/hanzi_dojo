// ─────────────────────────────────────────────────────────────────────────────
// pantalla_bateria.dart — Batería y fluidez (Ajustes → Batería y fluidez)
//
// · Fluidez de la pantalla: Automática (120 Hz solo al tocar o desplazar) o
//   Siempre máxima. Ver helpers/energia.dart.
// · Consumo ahora: nivel, corriente (mA), cuánto bajaría en una hora,
//   temperatura y a cuántos Hz va la pantalla. Se actualiza cada 2 s solo
//   mientras esta pantalla está abierta.
// · Medir mi consumo: deja leyendo la batería cada 15 s mientras usas la app
//   (por ejemplo, durante una práctica) y luego muestra el promedio. Así se
//   puede comprobar con números si un cambio ahorra batería.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../helpers/energia.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';

class PantallaBateria extends StatefulWidget {
  const PantallaBateria({super.key});

  @override
  State<PantallaBateria> createState() => _PantallaBateriaState();
}

class _PantallaBateriaState extends State<PantallaBateria> {
  LecturaBateria? _lectura;
  bool _sinLectura = false;
  Timer? _reloj;
  ModoFluidez _modo = Energia.modo;

  @override
  void initState() {
    super.initState();
    _leer();
    _reloj = Timer.periodic(const Duration(seconds: 2), (_) => _leer());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _leer() async {
    final l = await Energia.leerBateria();
    if (!mounted) return;
    setState(() {
      _lectura = l;
      _sinLectura = l == null;
    });
  }

  Future<void> _cambiarModo(ModoFluidez? m) async {
    if (m == null) return;
    setState(() => _modo = m);
    await Energia.cambiarModo(m);
    if (!mounted) return;
    await DatosApp.de(context).guardarFluidezMaxima(m == ModoFluidez.maxima);
  }

  @override
  Widget build(BuildContext context) {
    final suave = TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3);
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Batería y fluidez'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fluidez de la pantalla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Una pantalla a 120 Hz se ve más fluida, pero gasta más batería aunque nada se mueva.',
                    style: suave,
                  ),
                  RadioGroup<ModoFluidez>(
                    groupValue: _modo,
                    onChanged: _cambiarModo,
                    child: const Column(
                      children: [
                        RadioListTile<ModoFluidez>(
                          contentPadding: EdgeInsets.zero,
                          value: ModoFluidez.automatica,
                          title: Text('Automática (recomendada)'),
                          subtitle: Text('120 Hz solo mientras tocas o algo se desplaza; '
                              'al quedarse quieta la pantalla, el teléfono baja la tasa.'),
                        ),
                        RadioListTile<ModoFluidez>(
                          contentPadding: EdgeInsets.zero,
                          value: ModoFluidez.maxima,
                          title: Text('Siempre al máximo'),
                          subtitle: Text('120 Hz todo el tiempo. Gasta más.'),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: Energia.ahorro,
                    builder: (context, ahorro, _) => ahorro
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '🔋 Tu teléfono tiene activado el ahorro de batería: la app no pide 120 Hz '
                              'y la rama del inicio no se mueve.',
                              style: suave,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(child: _Ahora(lectura: _lectura, sinLectura: _sinLectura, estiloSuave: suave)),
            const SizedBox(height: 12),
            TarjetaVidrio(child: _Medicion(estiloSuave: suave)),
            const SizedBox(height: 12),
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Qué hace la app para ahorrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '• 120 Hz solo cuando hace falta (modo automático).\n'
                    '• La rama del inicio se anima a 30 cuadros por segundo, 30 segundos, y se apaga sola.\n'
                    '• Nada se anima ni corre con otra pantalla encima o con la app en segundo plano.\n'
                    '• Al escribir, la cuadrícula y la silueta se dibujan una sola vez.\n'
                    '• El sonido suelta el reproductor al terminar.',
                    style: suave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _numero(double v, [int decimales = 0]) => v.toStringAsFixed(decimales);

class _Ahora extends StatelessWidget {
  const _Ahora({required this.lectura, required this.sinLectura, required this.estiloSuave});

  final LecturaBateria? lectura;
  final bool sinLectura;
  final TextStyle estiloSuave;

  @override
  Widget build(BuildContext context) {
    final l = lectura;
    final filas = <(String, String)>[];
    if (l != null) {
      filas.add(('Batería', '${l.nivel} %${l.cargando ? ' · cargando' : ''}'));
      final ma = l.miliamperios;
      if (ma != null) filas.add(('Corriente', '${_numero(ma)} mA'));
      final ph = l.porcentajePorHora;
      if (ph != null) filas.add(('A este ritmo', '−${_numero(ph, 1)} % por hora'));
      if (l.temperatura > 0) filas.add(('Temperatura', '${_numero(l.temperatura, 1)} °C'));
      if (l.tasaPantalla > 0) filas.add(('Pantalla', '${_numero(l.tasaPantalla)} Hz'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Consumo ahora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (sinLectura)
          Text('No se pudo leer la batería en este teléfono.', style: estiloSuave)
        else if (l == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          for (final (nombre, valor) in filas) _Fila(nombre: nombre, valor: valor),
          if (l.cargando)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Desconecta el cargador para ver cuánto gasta.', style: estiloSuave),
            )
          else if (l.miliamperios == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tu teléfono no informa la corriente; queda el porcentaje.', style: estiloSuave),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Incluye todo el teléfono (pantalla, señal, otras apps), no solo Hanzi Dojo.',
                style: estiloSuave.copyWith(fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

class _Medicion extends StatelessWidget {
  const _Medicion({required this.estiloSuave});

  final TextStyle estiloSuave;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MedicionConsumo?>(
      valueListenable: Energia.medicion,
      builder: (context, m, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medir mi consumo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              m == null
                  ? 'Enciéndelo, desconecta el cargador y usa la app como siempre (por ejemplo, '
                      'una práctica de 10 minutos). Al volver aquí verás el promedio. Lee la batería '
                      'cada 15 s solo con la app abierta.'
                  : 'Midiendo desde las ${TimeOfDay.fromDateTime(m.inicio).format(context)}. '
                      'Sigue usando la app y vuelve aquí.',
              style: estiloSuave,
            ),
            if (m != null && m.ultima != null) ...[
              const SizedBox(height: 6),
              _Fila(nombre: 'Tiempo medido', valor: '${(m.segundosEnPantalla / 60).toStringAsFixed(1)} min'),
              if (m.promedioMa != null) _Fila(nombre: 'Corriente promedio', valor: '${_numero(m.promedioMa!)} mA'),
              if (m.porcentajePorHora != null)
                _Fila(nombre: 'Equivale a', valor: '−${_numero(m.porcentajePorHora!, 1)} % por hora'),
              if (m.bajo != null) _Fila(nombre: 'Bajó la batería', valor: '${m.bajo} puntos'),
              if (m.huboCarga)
                Text('⚠️ El teléfono estuvo cargando: esta medición no sirve. Reiníciala.', style: estiloSuave),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (m == null)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Empezar a medir'),
                    onPressed: Energia.iniciarMedicion,
                  )
                else ...[
                  OutlinedButton(onPressed: Energia.iniciarMedicion, child: const Text('Reiniciar')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: Energia.detenerMedicion, child: const Text('Terminar')),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.nombre, required this.valor});

  final String nombre;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(nombre, style: TextStyle(fontSize: 14, color: context.colores.suave))),
          Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
