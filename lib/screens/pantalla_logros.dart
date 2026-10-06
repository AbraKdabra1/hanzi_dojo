// ─────────────────────────────────────────────────────────────────────────────
// pantalla_logros.dart — Logros y racha
//
// Arriba: tu racha (actual y máxima) y si te queda protector de racha esta
// semana. Abajo: todos los logros; los que ya tienes, a color con su fecha
// (tócalos para compartirlos); los que faltan, tenues y con su avance.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/estadisticas.dart';
import '../datos/logros.dart';
import '../datos/repositorio_habito.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_compartir.dart';
import '../idioma.dart';

String _fecha(DateTime d) => '${d.day} ${mesesCortos[d.month - 1]} ${d.year}';

class PantallaLogros extends StatefulWidget {
  const PantallaLogros({super.key});

  @override
  State<PantallaLogros> createState() => _PantallaLogrosState();
}

class _PantallaLogrosState extends State<PantallaLogros> {
  DatosLogros? _datos;
  Map<String, DateTime> _desbloqueados = const {};
  Racha _racha = const Racha(actual: 0, maxima: 0);
  bool _protector = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    await repo.revisarLogros();
    final datos = await repo.datosLogros();
    final desbloqueados = await repo.logrosDesbloqueados();
    final racha = await repo.rachaConProtector();
    final protector = await repo.protectorDisponible();
    if (!mounted) return;
    setState(() {
      _datos = datos;
      _desbloqueados = desbloqueados;
      _racha = racha;
      _protector = protector;
    });
  }

  void _compartir([Logro? logro]) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PantallaCompartir(logro: logro)));
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final c = context.colores;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: tr('Logros'),
          subtitulo: datos == null ? null : tr('{0} de {1}', [_desbloqueados.length, Logros.todos.length]),
          acciones: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: tr('Compartir mi progreso'),
              onPressed: _compartir,
            ),
          ],
        ),
        body: datos == null
            ? Center(child: CircularProgressIndicator(color: c.icono))
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: TarjetaVidrio(
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 36)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_racha.actual} ${_racha.actual == 1 ? tr('día seguido') : tr('días seguidos')}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                  Text(tr('La más larga: {0}', [_racha.maxima]), style: TextStyle(fontSize: 13, color: c.suave)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _protector
                                        ? tr('🛡️ Protector de racha disponible: si un día no practicas, tu racha sigue. Hay uno por semana.')
                                        : tr('🛡️ Ya usaste el protector de esta semana; vuelve el lunes.'),
                                    style: TextStyle(fontSize: 12, color: c.tenue, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final l = Logros.todos[i];
                          final fecha = _desbloqueados[l.clave];
                          return _TarjetaLogro(
                            logro: l,
                            datos: datos,
                            fecha: fecha,
                            onTap: fecha == null ? null : () => _compartir(l),
                          );
                        },
                        childCount: Logros.todos.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TarjetaLogro extends StatelessWidget {
  const _TarjetaLogro({required this.logro, required this.datos, required this.fecha, this.onTap});

  final Logro logro;
  final DatosLogros datos;

  /// Cuándo lo desbloqueaste (null = aún no).
  final DateTime? fecha;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final logrado = fecha != null;
    final valor = logro.valor(datos).clamp(0, logro.meta);
    return TarjetaVidrio(
      onTap: onTap,
      relleno: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      color: logrado ? null : c.translucido,
      sombra: logrado,
      child: Column(
        children: [
          Opacity(
            opacity: logrado ? 1 : 0.3,
            child: Text(logro.emoji, style: const TextStyle(fontSize: 36)),
          ),
          const SizedBox(height: 6),
          Text(logro.titulo,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: logrado ? c.tinta : c.suave)),
          const SizedBox(height: 2),
          Expanded(
            child: Text(logro.descripcion,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.tenue, height: 1.25)),
          ),
          if (logrado)
            Text(_fecha(fecha!), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.suave))
          else if (logro.meta > 1) ...[
            LinearProgressIndicator(
              value: logro.avance(datos),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: c.separador,
              color: c.tinta.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 3),
            Text('$valor / ${logro.meta}', style: TextStyle(fontSize: 10, color: c.tenue)),
          ] else
            Text(tr('Pendiente'), style: TextStyle(fontSize: 11, color: c.tenue)),
        ],
      ),
    );
  }
}
