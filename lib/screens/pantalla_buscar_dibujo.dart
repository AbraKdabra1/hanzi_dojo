// ─────────────────────────────────────────────────────────────────────────────
// pantalla_buscar_dibujo.dart — Buscar un carácter dibujándolo (fase 7)
//
// Dibujas el carácter en el cuadro (de preferencia en su orden de trazos) y,
// con cada trazo, abajo aparecen los caracteres HSK más parecidos. Al tocar
// uno se abre su ficha (significado, nivel, practicar su escritura).
//
// Funciona sin internet: compara tu dibujo con las medianas de make-me-a-hanzi
// (helpers/reconocedor.dart). La primera vez se preparan los 3,000 caracteres
// HSK en segundo plano (compute; en la web, en el mismo hilo) y quedan en
// memoria mientras la app esté abierta.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/repositorio.dart';
import '../helpers/reconocedor.dart';
import '../idioma.dart';
import '../painters/grid_painter.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/texto_lectura.dart';

/// Los modelos de los caracteres HSK (se arman una sola vez).
class ModelosReconocimiento {
  ModelosReconocimiento._();

  static Future<List<ModeloTrazos>>? _modelos;

  static Future<List<ModeloTrazos>> de(Repositorio repo) => _modelos ??= () async {
        final filas = await repo.medianasHsk();
        return compute(_armarModelos, filas);
      }();
}

/// En otro isolate (compute necesita una función de primer nivel).
List<ModeloTrazos> _armarModelos(List<(String, String)> filas) =>
    [for (final (c, json) in filas) Reconocedor.modeloDeJson(c, json)];

class PantallaBuscarDibujo extends StatefulWidget {
  const PantallaBuscarDibujo({super.key});

  @override
  State<PantallaBuscarDibujo> createState() => _PantallaBuscarDibujoState();
}

class _PantallaBuscarDibujoState extends State<PantallaBuscarDibujo> {
  final _trazos = _Trazos();
  List<ModeloTrazos>? _modelos;
  List<String> _candidatos = const [];
  Map<String, String> _pinyin = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = DatosApp.de(context);
      final modelos = await ModelosReconocimiento.de(repo);
      final pinyin = await repo.pinyinHsk();
      if (mounted) {
        setState(() {
          _modelos = modelos;
          _pinyin = pinyin;
        });
        _buscar();
      }
    });
  }

  @override
  void dispose() {
    _trazos.dispose();
    super.dispose();
  }

  void _buscar() {
    final modelos = _modelos;
    if (modelos == null) return;
    setState(() => _candidatos = Reconocedor.buscar(_trazos.lista, modelos));
  }

  void _deshacer() {
    _trazos.deshacer();
    _buscar();
  }

  void _borrar() {
    _trazos.borrar();
    _buscar();
  }

  void _abrir(String caracter) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FichaCaracterLectura(texto: caracter, pinyinEnTexto: _pinyin[caracter] ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: tr('Buscar dibujando'),
          acciones: [
            IconButton(
              icon: Icon(Icons.undo_rounded, color: c.icono),
              tooltip: tr('Deshacer trazo'),
              onPressed: _deshacer,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: c.icono),
              tooltip: tr('Borrar'),
              onPressed: _borrar,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, r) {
            final horizontal = r.maxWidth > r.maxHeight * 1.15;
            final lado = (horizontal ? r.maxHeight : r.maxWidth) - 40;
            final lienzo = Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: lado.clamp(160.0, 520.0),
                height: lado.clamp(160.0, 520.0),
                child: _Lienzo(trazos: _trazos, alTerminarTrazo: _buscar),
              ),
            );
            final resultados = _Resultados(
              cargando: _modelos == null,
              vacio: _trazos.lista.isEmpty,
              candidatos: _candidatos,
              pinyin: _pinyin,
              onTap: _abrir,
            );
            return horizontal
                ? Row(children: [lienzo, Expanded(child: resultados)])
                : Column(children: [lienzo, Expanded(child: resultados)]);
          }),
        ),
      ),
    );
  }
}

/// Los trazos dibujados (el lienzo se repinta solo cuando cambian).
class _Trazos extends ChangeNotifier {
  final List<List<Offset>> lista = [];

  void empezar(Offset p) {
    lista.add([p]);
    notifyListeners();
  }

  void agregar(Offset p) {
    if (lista.isEmpty) return;
    lista.last.add(p);
    notifyListeners();
  }

  void deshacer() {
    if (lista.isEmpty) return;
    lista.removeLast();
    notifyListeners();
  }

  void borrar() {
    lista.clear();
    notifyListeners();
  }
}

class _Lienzo extends StatelessWidget {
  const _Lienzo({required this.trazos, required this.alTerminarTrazo});

  final _Trazos trazos;
  final VoidCallback alTerminarTrazo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.lienzo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.bordeLienzo, width: 1.5),
        boxShadow: [BoxShadow(color: c.sombra, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Listener(
        onPointerDown: (e) => trazos.empezar(e.localPosition),
        onPointerMove: (e) => trazos.agregar(e.localPosition),
        onPointerUp: (_) => alTerminarTrazo(),
        // Recortado a las esquinas redondeadas: que las diagonales de la
        // cuadrícula (y los trazos) no se salgan del cuadro.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: GridPainter(color: c.cuadricula),
              foregroundPainter: _PintorTrazos(trazos, c.trazo),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorTrazos extends CustomPainter {
  _PintorTrazos(this.trazos, this.color) : super(repaint: trazos);

  final _Trazos trazos;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final t in trazos.lista) {
      if (t.length == 1) {
        canvas.drawCircle(t.first, pincel.strokeWidth / 2, Paint()..color = color);
        continue;
      }
      final ruta = Path()..moveTo(t.first.dx, t.first.dy);
      for (final p in t.skip(1)) {
        ruta.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(ruta, pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorTrazos old) => old.color != color || old.trazos != trazos;
}

class _Resultados extends StatelessWidget {
  const _Resultados({
    required this.cargando,
    required this.vacio,
    required this.candidatos,
    required this.pinyin,
    required this.onTap,
  });

  final bool cargando;
  final bool vacio;
  final List<String> candidatos;
  final Map<String, String> pinyin;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    if (cargando) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.icono)),
            const SizedBox(width: 10),
            Text(tr('Preparando los caracteres…'), style: TextStyle(color: c.suave)),
          ],
        ),
      );
    }
    if (vacio) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          tr('Dibuja un carácter en el cuadro, de preferencia en su orden de trazos. '
              'Con cada trazo verás aquí los más parecidos.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.suave, height: 1.4),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (final (i, car) in candidatos.indexed)
            Material(
              color: i == 0 ? c.boton : c.tarjeta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: i == 0 ? c.boton : c.bordeTarjeta),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTap(car),
                child: SizedBox(
                  width: 68,
                  height: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(car, style: TextStyle(fontSize: 32, color: i == 0 ? c.textoBoton : c.tinta)),
                      Text(pinyin[car] ?? '',
                          style: TextStyle(fontSize: 11, color: i == 0 ? c.textoBoton.withValues(alpha: 0.75) : c.tenue)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
