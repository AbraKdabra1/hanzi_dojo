// ─────────────────────────────────────────────────────────────────────────────
// pantalla_ajustes.dart — Ajustes y acceso a Créditos
//
// · Cuántos caracteres NUEVOS quieres por día. Los repasos no tienen límite
//   (siempre conviene hacer los que tocan).
// · Práctica con audio: voz lenta y cuántas palabras nuevas por día.
// · Ajuste caligráfico: si cada trazo correcto se acomoda (con un rebote
//   suave) en la forma exacta del pincel, o se queda como lo dibujaste.
// · Tus datos: exportar e importar el progreso (respaldo.dart) y deshacer la
//   última importación.
// · Reportar un problema (pantalla_reporte.dart) e Informe de errores
//   (pantalla_errores.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/registro_errores.dart';
import '../datos/repositorio_practica.dart';
import '../datos/respaldo.dart';
import '../helpers/archivos.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';
import 'pantalla_bateria.dart';
import 'pantalla_creditos.dart';
import 'pantalla_errores.dart';
import 'pantalla_reporte.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  int? _limite;
  bool? _ajuste;
  int? _limitePalabras;
  bool? _vozLenta;

  /// ¿Hay una importación que se pueda deshacer?
  bool _hayPrevio = false;

  /// true mientras se exporta o importa (evita tocar dos veces).
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final n = await repo.limiteNuevosPorDia();
    final ajuste = await repo.ajusteCaligrafico();
    final limitePalabras = await repo.limitePalabrasPorDia();
    final vozLenta = await repo.vozLenta();
    final previo = await Respaldo.hayRespaldoPrevio(repo.base);
    if (mounted) {
      setState(() {
        _limite = n;
        _ajuste = ajuste;
        _limitePalabras = limitePalabras;
        _vozLenta = vozLenta;
        _hayPrevio = previo;
      });
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: Text(accion)),
        ],
      ),
    );
    return ok == true;
  }

  /// Corre [accion] marcando la pantalla como ocupada; si falla, se registra
  /// en el informe de errores y se avisa.
  Future<void> _mientrasOcupado(String que, Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
    } catch (e, pila) {
      RegistroErrores.registrar('Respaldo', e, pila);
      _aviso('No se pudo $que: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _exportar() => _mientrasOcupado('exportar', () async {
        final repo = DatosApp.de(context);
        final bytes = await Respaldo.exportar(repo.base.db);
        final nombre = await Archivos.guardar(
          nombre: Respaldo.nombreSugerido(DateTime.now()),
          bytes: bytes,
        );
        if (nombre != null) _aviso('Respaldo guardado: $nombre');
      });

  Future<void> _importar() => _mientrasOcupado('importar', () async {
        final repo = DatosApp.de(context);
        final archivo = await Archivos.abrir();
        if (archivo == null) return;
        final DatosRespaldo datos;
        try {
          datos = Respaldo.leer(archivo.bytes);
        } on RespaldoInvalido catch (e) {
          _aviso(e.mensaje);
          return;
        }
        final actuales = await repo.totalEstudiados();
        if (!mounted) return;
        final creado = datos.creado == null ? '' : '\nCreado: ${RegistroErrores.fechaCorta(datos.creado!)}';
        final ok = await _confirmar(
          '¿Importar este respaldo?',
          '${archivo.nombre}$creado\n'
              'Trae ${datos.caracteres} caracteres y ${datos.repasos} repasos.\n\n'
              'Reemplazará tu progreso actual ($actuales caracteres). Antes se guarda '
              'una copia, por si quieres deshacerlo.',
          'Importar',
        );
        if (!ok) return;
        await Respaldo.importar(repo.base, datos);
        await _cargar();
        _aviso('Progreso importado ✓');
      });

  Future<void> _deshacer() => _mientrasOcupado('deshacer la importación', () async {
        final repo = DatosApp.de(context);
        final ok = await _confirmar(
          '¿Deshacer la importación?',
          'Tu progreso volverá a como estaba antes de la última importación.',
          'Deshacer',
        );
        if (!ok) return;
        await Respaldo.deshacerImportacion(repo.base);
        await _cargar();
        _aviso('Listo: volviste a tu progreso anterior.');
      });

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
                  const Text('Apariencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'El modo oscuro «tinta» descansa la vista de noche y, en pantallas OLED, '
                    'gasta bastante menos batería.',
                    style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: Apariencia.modo,
                    builder: (context, modo, _) => SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        // Poco relleno: "Automática" cabe en una línea en teléfonos angostos.
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          // Con la tipografía de la app (un TextStyle suelto perdería la fuente).
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
                        ),
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('Automática')),
                          ButtonSegment(value: ThemeMode.light, label: Text('Clara')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Oscura')),
                        ],
                        selected: {modo},
                        onSelectionChanged: (elegido) {
                          final nuevo = elegido.first;
                          Apariencia.modo.value = nuevo;
                          DatosApp.de(context).guardarApariencia(Apariencia.aTexto(nuevo));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                    style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Práctica con audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voz lenta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Todas las grabaciones suenan un poco más despacio. Sin activarlo, '
                      'mantén presionado un botón de sonido para oírlo lento.',
                      style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                    ),
                    value: _vozLenta ?? false,
                    onChanged: _vozLenta == null
                        ? null
                        : (v) {
                            setState(() => _vozLenta = v);
                            Voz.velocidad = v ? 0.75 : 1.0;
                            DatosApp.de(context).guardarVozLenta(v);
                          },
                  ),
                  Text('Palabras nuevas por día',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colores.tinta)),
                  if (_limitePalabras != null)
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _limitePalabras!.toDouble(),
                            min: 5,
                            max: 30,
                            divisions: 5,
                            label: '$_limitePalabras',
                            onChanged: (v) => setState(() => _limitePalabras = v.round()),
                            onChangeEnd: (v) => DatosApp.de(context).guardarLimitePalabrasPorDia(v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('$_limitePalabras',
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
                  style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
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
                MaterialPageRoute<void>(builder: (_) => const PantallaBateria()),
              ),
              child: Row(
                children: [
                  Icon(Icons.battery_saver_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Batería y fluidez', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('120 Hz solo cuando hace falta y cuánto gasta la app',
                            style: TextStyle(fontSize: 13, color: context.colores.icono)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: context.colores.tenue),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tus datos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Tu progreso vive solo en este teléfono. Exporta un respaldo para no '
                    'perderlo si cambias de teléfono o lo reinicias.',
                    style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  _FilaAccion(
                    icono: Icons.save_alt_rounded,
                    titulo: 'Exportar progreso',
                    subtitulo: 'Guarda un archivo .hanzidojo donde elijas',
                    onTap: _ocupado ? null : _exportar,
                  ),
                  _FilaAccion(
                    icono: Icons.restore_page_outlined,
                    titulo: 'Importar progreso',
                    subtitulo: 'Reemplaza tu progreso por el de un respaldo',
                    onTap: _ocupado ? null : _importar,
                  ),
                  if (_hayPrevio)
                    _FilaAccion(
                      icono: Icons.undo_rounded,
                      titulo: 'Deshacer la última importación',
                      subtitulo: 'Vuelve al progreso que tenías antes',
                      onTap: _ocupado ? null : _deshacer,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PantallaReporte()),
              ),
              child: Row(
                children: [
                  Icon(Icons.feedback_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Reportar un problema o sugerir algo', style: TextStyle(fontSize: 15))),
                  Icon(Icons.arrow_forward_ios, size: 14, color: context.colores.tenue),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PantallaErrores()),
              ),
              child: Row(
                children: [
                  Icon(Icons.bug_report_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Informe de errores', style: TextStyle(fontSize: 15))),
                  Icon(Icons.arrow_forward_ios, size: 14, color: context.colores.tenue),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PantallaCreditos()),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(child: Text('Créditos y licencias', style: TextStyle(fontSize: 15))),
                  Icon(Icons.arrow_forward_ios, size: 14, color: context.colores.tenue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renglón tocable con ícono, título y explicación (sección "Tus datos").
class _FilaAccion extends StatelessWidget {
  const _FilaAccion({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;

  /// null = desactivado (mientras otra acción está en curso).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      leading: Icon(icono, color: context.colores.tinta),
      title: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitulo, style: TextStyle(fontSize: 12, color: context.colores.tenue)),
      onTap: onTap,
    );
  }
}
