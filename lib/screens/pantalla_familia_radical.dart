// ─────────────────────────────────────────────────────────────────────────────
// pantalla_familia_radical.dart — Un radical y todos los caracteres que lo usan
//
// Arriba: el radical con sus variantes (水 氵 氺), su nombre y su avance.
// Botones: practicar el radical en sí, o estudiar su familia completa
//          (del nivel HSK más bajo al más alto).
// Abajo: la familia agrupada por nivel; toca cualquiera para practicarlo.
//        Los caracteres fuera de HSK se ocultan salvo que los pidas.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';
import 'pantalla_estudio.dart';

class PantallaFamiliaRadical extends StatefulWidget {
  const PantallaFamiliaRadical({super.key, required this.numero, required this.modoNovato});

  final int numero;
  final bool modoNovato;

  @override
  State<PantallaFamiliaRadical> createState() => _PantallaFamiliaRadicalState();
}

class _PantallaFamiliaRadicalState extends State<PantallaFamiliaRadical> {
  late final Repositorio _repo = DatosApp.de(context);
  Radical? _radical;
  List<Caracter> _familia = const [];
  bool _incluirFueraHsk = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final r = await _repo.radical(widget.numero);
    final f = await _repo.familia(widget.numero, incluirFueraHsk: _incluirFueraHsk);
    if (!mounted) return;
    setState(() {
      _radical = r;
      _familia = f;
      _cargando = false;
    });
  }

  Future<void> _abrir(FiltroEstudio filtro) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PantallaEstudio(filtro: filtro, modoNovato: widget.modoNovato)),
    );
    _cargar(); // al volver, refrescar el avance
  }

  @override
  Widget build(BuildContext context) {
    final r = _radical;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: 'Radical ${widget.numero}', subtitulo: r?.nombreEs),
        body: _cargando || r == null
            ? Center(child: CircularProgressIndicator(color: context.colores.icono))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _cabecera(r)),
                  ..._secciones(),
                  SliverToBoxAdapter(child: _interruptorFueraHsk(r)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  Widget _cabecera(Radical r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: TarjetaVidrio(
        relleno: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Text(r.formaPrincipal, style: const TextStyle(fontSize: 56, height: 1.1)),
                const SizedBox(width: 12),
                if (r.variantes.isNotEmpty)
                  Text(r.variantes.join('  '),
                      style: TextStyle(fontSize: 30, color: context.colores.suave, height: 1.1)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(r.pinyin, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text('${r.trazos} ${r.trazos == 1 ? 'trazo' : 'trazos'}',
                        style: TextStyle(fontSize: 12, color: context.colores.tenue)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(r.nombreEs, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            BarraAvance(valor: r.aprendidosHsk, total: r.totalHsk, color: (context.colores.oscuro ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A))),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('caracteres HSK de la familia que ya estudiaste',
                  style: TextStyle(fontSize: 11, color: context.colores.tenue)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (r.caracterId != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(r.practicado ? Icons.check_circle : Icons.edit, size: 18),
                      label: const Text('Practicar radical'),
                      onPressed: () => _abrir(FiltroEstudio.unico(r.caracterId!)),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Estudiar familia'),
                    onPressed: r.totalHsk == 0 && !_incluirFueraHsk
                        ? null
                        : () => _abrir(FiltroEstudio.familia(r.numero, incluirFueraHsk: _incluirFueraHsk)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Un encabezado y una cuadrícula por nivel HSK.
  List<Widget> _secciones() {
    if (_familia.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Ningún carácter HSK usa este radical.',
                textAlign: TextAlign.center, style: TextStyle(color: context.colores.tenue)),
          ),
        ),
      ];
    }
    final porNivel = <int, List<Caracter>>{};
    for (final c in _familia) {
      porNivel.putIfAbsent(c.nivelHsk, () => []).add(c);
    }
    return [
      for (final entrada in porNivel.entries) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              EtiquetaNivel(nivel: entrada.key),
              const SizedBox(width: 8),
              Text('${entrada.value.length}', style: TextStyle(fontSize: 12, color: context.colores.tenue)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 72,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: entrada.value.length,
            itemBuilder: (_, i) => _CeldaCaracter(
              caracter: entrada.value[i],
              onTap: () => _abrir(FiltroEstudio.unico(entrada.value[i].id)),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _interruptorFueraHsk(Radical r) {
    final fuera = r.total - r.totalHsk;
    if (fuera == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: SwitchListTile(
        value: _incluirFueraHsk,
        title: Text('Mostrar caracteres fuera de HSK ($fuera)'),
        subtitle: const Text('Poco comunes; útiles para leer, no para el examen'),
        onChanged: (v) {
          setState(() => _incluirFueraHsk = v);
          _cargar();
        },
      ),
    );
  }
}

/// Celda con un carácter; verde si ya lo estudiaste.
class _CeldaCaracter extends StatelessWidget {
  const _CeldaCaracter({required this.caracter, required this.onTap});

  final Caracter caracter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visto = caracter.progreso != null;
    return TarjetaVidrio(
      onTap: onTap,
      radio: 12,
      sombra: false,
      relleno: const EdgeInsets.symmetric(vertical: 4),
      color: visto
          ? (context.colores.oscuro ? const Color(0x332E7D32) : const Color(0xBFE8F5E9))
          : context.colores.translucido,
      colorBorde: visto
          ? (context.colores.oscuro ? const Color(0x664CAF50) : const Color(0xCCA5D6A7))
          : context.colores.bordeTarjeta,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(caracter.caracter, style: const TextStyle(fontSize: 26, height: 1.1)),
          Text(caracter.pinyin, style: TextStyle(fontSize: 10, color: context.colores.tenue)),
        ],
      ),
    );
  }
}
