// ─────────────────────────────────────────────────────────────────────────────
// pantalla_vocabulario.dart — Repaso espaciado de palabras
//
// Como el estudio de caracteres, pero con las palabras de la lista HSK:
//   1. Ves la palabra y tratas de recordar cómo se lee y qué significa.
//   2. «Mostrar» → pinyin por tonos, significado, la grabación y de qué
//      caracteres está hecha.
//   3. Te calificas: Difícil / Medio / Fácil (debajo de cada botón, cuándo
//      volverá a salir).
// Primero salen las palabras que tocan hoy (de cualquier nivel) y luego
// nuevas del nivel elegido, empezando por las que usan caracteres que ya
// estudiaste (practica.dart, SesionPalabras).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/practica.dart';
import '../datos/repositorio_practica.dart';
import '../datos/srs.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/ejercicio.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaVocabulario extends StatefulWidget {
  const PantallaVocabulario({super.key, required this.nivel});

  final int nivel;

  @override
  State<PantallaVocabulario> createState() => _PantallaVocabularioState();
}

class _PantallaVocabularioState extends State<PantallaVocabulario> {
  SesionPalabras? _sesion;
  Palabra? _actual;
  bool _cargando = true;
  bool _revelada = false;
  bool _guardando = false;
  List<Caracter> _componentes = const [];
  DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sesion = SesionPalabras(FuentePalabrasRepositorio(DatosApp.de(context)), widget.nivel);
      _siguiente();
    });
  }

  @override
  void dispose() {
    Voz.detener();
    super.dispose();
  }

  Future<void> _siguiente() async {
    setState(() {
      _cargando = true;
      _revelada = false;
      _componentes = const [];
    });
    final p = await _sesion!.siguiente();
    if (!mounted) return;
    setState(() {
      _actual = p;
      _cargando = false;
      _inicio = DateTime.now();
    });
  }

  Future<void> _mostrar() async {
    final p = _actual;
    if (p == null) return;
    setState(() => _revelada = true);
    Voz.decir(p.palabra, pinyin: p.pinyinPorCaracter);
    final repo = DatosApp.de(context);
    final componentes = <Caracter>[];
    for (final r in p.palabra.runes) {
      final c = await repo.caracterPorTexto(String.fromCharCode(r));
      if (c != null && !componentes.any((x) => x.id == c.id)) componentes.add(c);
    }
    if (mounted && _actual == p) setState(() => _componentes = componentes);
  }

  Future<void> _calificar(Calificacion calificacion) async {
    final p = _actual;
    if (p == null || _guardando) return;
    setState(() => _guardando = true);
    await _sesion!.responder(p, calificacion, duracionMs: DateTime.now().difference(_inicio).inMilliseconds);
    if (!mounted) return;
    setState(() => _guardando = false);
    await _siguiente();
  }

  /// "mañana", "en 6 días"… para mostrar debajo de cada botón.
  static String _cuando(Palabra p, Calificacion calificacion) {
    if (!calificacion.aprobado) return 'otra vez hoy';
    final estado = EstadoSrs(
      intervaloDias: p.progreso?.intervaloDias ?? 0,
      factor: p.progreso?.factor ?? EstadoSrs.factorInicial,
      aciertosSeguidos: p.progreso?.aciertosSeguidos ?? 0,
    ).calificar(calificacion);
    final d = estado.intervaloDias;
    if (d <= 1) return 'mañana';
    if (d < 30) return 'en $d días';
    final meses = (d / 30).round();
    return meses <= 1 ? 'en un mes' : 'en $meses meses';
  }

  @override
  Widget build(BuildContext context) {
    final sesion = _sesion;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: 'Vocabulario',
          subtitulo: sesion == null || (sesion.nuevas + sesion.repasadas) == 0
              ? nombreDeNivel(widget.nivel)
              : '${sesion.repasadas} repasadas · ${sesion.nuevas} nuevas',
        ),
        body: SafeArea(top: false, child: _cuerpo(context)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final sesion = _sesion;
    if (_cargando || sesion == null) return const Center(child: CircularProgressIndicator());
    final p = _actual;
    if (p == null) {
      if (sesion.fin == FinSesionPalabras.limiteDiario) {
        return MensajeCentrado(
          emoji: '✅',
          titulo: 'Listas las palabras nuevas de hoy',
          texto: 'Repasaste ${sesion.repasadas} y aprendiste ${sesion.nuevas}. '
              'Puedes seguir con más o volver mañana (el límite se cambia en Ajustes).',
          acciones: [
            FilledButton(
              onPressed: () {
                sesion.estudiarMas();
                _siguiente();
              },
              child: const Text('Estudiar más'),
            ),
            OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Terminar')),
          ],
        );
      }
      return MensajeCentrado(
        emoji: '🎉',
        titulo: '¡Vocabulario al día!',
        texto: sesion.nuevas + sesion.repasadas == 0
            ? 'No hay palabras por repasar ni nuevas en ${nombreDeNivel(widget.nivel)}.'
            : 'Repasaste ${sesion.repasadas} y aprendiste ${sesion.nuevas} palabras.',
        acciones: [OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Terminar'))],
      );
    }

    final c = context.colores;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: TarjetaVidrio(
              relleno: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              onTap: _revelada ? null : _mostrar,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EtiquetaNivel(nivel: p.nivelHsk),
                      if (p.progreso == null) ...[
                        const SizedBox(width: 8),
                        Text('nueva', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.tenue)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(p.palabra,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: p.palabra.length > 3 ? 48 : 64)),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _revelada
                        ? _reverso(context, p)
                        : Padding(
                            key: const ValueKey('frente'),
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('¿Cómo se lee y qué significa?',
                                style: TextStyle(fontSize: 15, color: c.suave)),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: _revelada
              ? Row(
                  children: [
                    for (final (cal, color) in [
                      (Calificacion.dificil, Colors.red),
                      (Calificacion.medio, Colors.orange),
                      (Calificacion.facil, Colors.green),
                    ]) ...[
                      if (cal != Calificacion.dificil) const SizedBox(width: 10),
                      Expanded(
                        child: _BotonNota(
                          etiqueta: cal.etiqueta,
                          detalle: _cuando(p, cal),
                          color: color,
                          onTap: _guardando ? null : () => _calificar(cal),
                        ),
                      ),
                    ],
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _mostrar,
                    child: const Text('Mostrar', style: TextStyle(fontSize: 16)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _reverso(BuildContext context, Palabra p) {
    final c = context.colores;
    return Column(
      key: const ValueKey('reverso'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: PinyinPorTonos(silabas: p.silabas, tamano: 26)),
            const SizedBox(width: 12),
            BotonVoz(texto: p.palabra, pinyin: p.pinyinPorCaracter),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            if (!p.tieneEspanol)
              TextSpan(text: 'EN  ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.tenue)),
            TextSpan(text: p.significado),
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, height: 1.35, color: c.tinta),
        ),
        if (p.forma != p.palabra) ...[
          const SizedBox(height: 6),
          Text('En la lista oficial: ${p.forma.replaceAll('|', ' / ')}',
              style: TextStyle(fontSize: 12, color: c.tenue)),
        ],
        if (_componentes.length > 1) ...[
          const SizedBox(height: 16),
          Divider(color: c.separador),
          const SizedBox(height: 8),
          for (final car in _componentes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text(car.caracter, style: const TextStyle(fontSize: 24))),
                  SizedBox(width: 64, child: Text(car.pinyin, style: TextStyle(fontSize: 14, color: c.suave))),
                  Expanded(
                    child: Text(car.significado,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.suave)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Botón de calificación con "cuándo vuelve" debajo.
class _BotonNota extends StatelessWidget {
  const _BotonNota({required this.etiqueta, required this.detalle, required this.color, required this.onTap});

  final String etiqueta;
  final String detalle;
  final MaterialColor color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final oscuro = context.colores.oscuro;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: oscuro ? color.shade900.withValues(alpha: 0.55) : color.shade50,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta,
              style: TextStyle(color: oscuro ? color.shade200 : color.shade800, fontWeight: FontWeight.w700)),
          Text(detalle,
              style: TextStyle(fontSize: 11, color: (oscuro ? color.shade200 : color.shade800).withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}
