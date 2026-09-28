// ─────────────────────────────────────────────────────────────────────────────
// pantalla_seleccion.dart — Niveles HSK y búsqueda
//
// Lista los niveles oficiales HSK 3.0 (1 a 6 y 7-9) con tu avance en cada
// uno. Arriba hay un buscador: por carácter (好), pinyin con o sin tonos
// (hao, hǎo) o significado (bueno). Toca un resultado para practicarlo.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_estudio.dart';

class PantallaSeleccion extends StatefulWidget {
  const PantallaSeleccion({super.key, required this.modoNovato});
  final bool modoNovato;

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  late final Repositorio _repo = DatosApp.de(context);
  final _busqueda = TextEditingController();
  Timer? _espera;
  List<AvanceNivel> _niveles = const [];
  List<Caracter> _resultados = const [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final n = await _repo.avancePorNivel();
    if (mounted) setState(() => _niveles = n);
  }

  /// Busca 250 ms después de la última tecla (para no consultar en cada letra).
  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 250), () async {
      final q = texto.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _buscando = false);
        return;
      }
      final r = await _repo.buscar(q);
      // Si mientras buscaba cambiaste (o borraste) el texto, este resultado
      // ya no sirve: se descarta.
      if (mounted && _busqueda.text.trim() == q) {
        setState(() {
          _buscando = true;
          _resultados = r;
        });
      }
    });
  }

  Future<void> _estudiar(FiltroEstudio filtro) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PantallaEstudio(filtro: filtro, modoNovato: widget.modoNovato)),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: 'Niveles HSK',
          subtitulo: widget.modoNovato ? '🐣 Modo novato' : '🥋 Modo experto',
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _busqueda,
                onChanged: _alEscribir,
                decoration: InputDecoration(
                  hintText: 'Buscar: 好, hao, bueno…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _buscando
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _espera?.cancel();
                            _busqueda.clear();
                            setState(() => _buscando = false);
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xB3FFFFFF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(child: _buscando ? _listaResultados() : _listaNiveles()),
          ],
        ),
      ),
    );
  }

  Widget _listaNiveles() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _niveles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final n = _niveles[i];
        return TarjetaVidrio(
          onTap: () => _estudiar(FiltroEstudio.nivel(n.nivel)),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EtiquetaNivel.colorDe(n.nivel).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(n.nivel == 7 ? '7-9' : '${n.nivel}',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: EtiquetaNivel.colorDe(n.nivel))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombreDeNivel(n.nivel), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      n.dominados > 0 ? '${n.dominados} dominados' : '${n.total} caracteres oficiales',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    BarraAvance(valor: n.estudiados, total: n.total, color: EtiquetaNivel.colorDe(n.nivel)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            ],
          ),
        );
      },
    );
  }

  Widget _listaResultados() {
    if (_resultados.isEmpty) {
      return const MensajeCentrado(emoji: '🔍', titulo: 'Sin resultados');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _resultados.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = _resultados[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Text(c.caracter, style: const TextStyle(fontSize: 32)),
          title: Row(children: [
            Text(c.pinyin, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            EtiquetaNivel(nivel: c.nivelHsk),
          ]),
          subtitle: Text(c.significado, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.draw_outlined, size: 18, color: Colors.blue),
          onTap: () => _estudiar(FiltroEstudio.unico(c.id)),
        );
      },
    );
  }
}
