// ─────────────────────────────────────────────────────────────────────────────
// pantalla_ajustes.dart — Ajustes y acceso a Créditos
//
// · Cuántos caracteres NUEVOS quieres por día. Los repasos no tienen límite
//   (siempre conviene hacer los que tocan).
// · Tu hábito: meta diaria (repasos y ejercicios) y recordatorio diario.
// · Práctica con audio: voz lenta y cuántas palabras nuevas por día.
// · Ajuste caligráfico: si cada trazo correcto se acomoda (con un rebote
//   suave) en la forma exacta del pincel, o se queda como lo dibujaste.
// · Tus datos: exportar e importar el progreso (respaldo.dart) y deshacer la
//   última importación.
// · Apoyar el proyecto (donativo voluntario, widgets/apoyo.dart).
// · Reportar un problema (pantalla_reporte.dart) e Informe de errores
//   (pantalla_errores.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/registro_errores.dart';
import '../datos/repositorio_habito.dart';
import '../datos/repositorio_practica.dart';
import '../datos/respaldo.dart';
import '../helpers/archivos.dart';
import '../helpers/habito.dart';
import '../helpers/sensaciones.dart';
import '../widgets/apoyo.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';
import 'pantalla_bateria.dart';
import 'pantalla_creditos.dart';
import 'pantalla_errores.dart';
import 'pantalla_reporte.dart';
import '../idioma.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  int? _limite;
  bool? _ajuste;
  int? _limitePalabras;
  String? _idioma;
  bool? _vibracion;
  bool? _sonidoPincel;
  bool? _vozLenta;
  int? _metaDiaria;

  /// Hora del recordatorio (null = apagado).
  (int, int)? _recordatorio;

  /// Hora del carácter del día en la pantalla de bloqueo (null = apagado).
  (int, int)? _caracterDia;

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
    final idioma = await repo.idioma();
    final vibracion = await repo.vibracion();
    final sonidoPincel = await repo.sonidoPincel();
    final metaDiaria = await repo.metaDiaria();
    final recordatorio = await repo.recordatorio();
    final caracterDia = await repo.caracterDia();
    final previo = await Respaldo.hayRespaldoPrevio(repo.base);
    if (mounted) {
      setState(() {
        _limite = n;
        _ajuste = ajuste;
        _limitePalabras = limitePalabras;
        _vozLenta = vozLenta;
        _idioma = idioma;
        _vibracion = vibracion;
        _sonidoPincel = sonidoPincel;
        _metaDiaria = metaDiaria;
        _recordatorio = recordatorio;
        _caracterDia = caracterDia;
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
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: Text(tr('Cancelar'))),
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
      _aviso(tr('No se pudo {0}: {1}', [que, e]));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _exportar() => _mientrasOcupado(tr('exportar'), () async {
        final repo = DatosApp.de(context);
        final bytes = await Respaldo.exportar(repo.base.db);
        final nombre = await Archivos.guardar(
          nombre: Respaldo.nombreSugerido(DateTime.now()),
          bytes: bytes,
        );
        if (nombre != null) _aviso(tr('Respaldo guardado: {0}', [nombre]));
      });

  Future<void> _importar() => _mientrasOcupado(tr('importar'), () async {
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
        final creado = datos.creado == null ? '' : tr('\nCreado: {0}', [RegistroErrores.fechaCorta(datos.creado!)]);
        final ok = await _confirmar(
          tr('¿Importar este respaldo?'),
          tr('{0}{1}\nTrae {2} caracteres y {3} repasos.\n\nReemplazará tu progreso actual ({4} caracteres). Antes se guarda una copia, por si quieres deshacerlo.', [archivo.nombre, creado, datos.caracteres, datos.repasos, actuales]),
          tr('Importar'),
        );
        if (!ok) return;
        await Respaldo.importar(repo.base, datos);
        await _cargar();
        _aviso(tr('Progreso importado ✓'));
      });

  Future<void> _deshacer() => _mientrasOcupado(tr('deshacer la importación'), () async {
        final repo = DatosApp.de(context);
        final ok = await _confirmar(
          tr('¿Deshacer la importación?'),
          tr('Tu progreso volverá a como estaba antes de la última importación.'),
          tr('Deshacer'),
        );
        if (!ok) return;
        await Respaldo.deshacerImportacion(repo.base);
        await _cargar();
        _aviso(tr('Listo: volviste a tu progreso anterior.'));
      });

  /// Enciende el recordatorio a [hora] (pide permiso de notificaciones).
  Future<void> _ponerRecordatorio((int, int) hora) async {
    final repo = DatosApp.de(context);
    final ok = await Habito.programarRecordatorio(hora.$1, hora.$2);
    if (!ok) {
      _aviso(tr('Sin permiso de notificaciones no puedo recordarte. Actívalo en los ajustes del teléfono.'));
      return;
    }
    await repo.guardarRecordatorio(hora);
    if (mounted) setState(() => _recordatorio = hora);
  }

  Future<void> _quitarRecordatorio() async {
    await Habito.cancelarRecordatorio();
    if (!mounted) return;
    await DatosApp.de(context).guardarRecordatorio(null);
    if (mounted) setState(() => _recordatorio = null);
  }

  Future<void> _elegirHora() async {
    final actual = _recordatorio ?? (20, 0);
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual.$1, minute: actual.$2),
      helpText: tr('¿A qué hora te recuerdo?'),
    );
    if (elegida != null) await _ponerRecordatorio((elegida.hour, elegida.minute));
  }

  /// Enciende el carácter del día a [hora]; al encenderlo por primera vez
  /// muestra el de hoy para que lo veas enseguida.
  Future<void> _ponerCaracterDia((int, int) hora) async {
    final repo = DatosApp.de(context);
    final primeraVez = _caracterDia == null;
    final ok = await Habito.programarCaracterDia(hora.$1, hora.$2, mostrarAhora: primeraVez);
    if (!ok) {
      _aviso(tr('Sin permiso de notificaciones no puedo mostrarte el carácter del día. Actívalo en los ajustes del teléfono.'));
      return;
    }
    await repo.guardarCaracterDia(hora);
    if (!mounted) return;
    setState(() => _caracterDia = hora);
    if (primeraVez) _aviso(tr('Listo: el carácter de hoy ya está en tus notificaciones.'));
  }

  Future<void> _quitarCaracterDia() async {
    await Habito.cancelarCaracterDia();
    if (!mounted) return;
    await DatosApp.de(context).guardarCaracterDia(null);
    if (mounted) setState(() => _caracterDia = null);
  }

  Future<void> _elegirHoraCaracter() async {
    final actual = _caracterDia ?? (8, 0);
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual.$1, minute: actual.$2),
      helpText: tr('¿A qué hora te muestro el carácter del día?'),
    );
    if (elegida != null) await _ponerCaracterDia((elegida.hour, elegida.minute));
  }

  static String _textoHora((int, int) h) => '${h.$1}:${h.$2.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final limite = _limite;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Ajustes')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Apariencia'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    tr('El modo oscuro «tinta» descansa la vista de noche y, en pantallas OLED, gasta bastante menos batería.'),
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
                        segments: [
                          ButtonSegment(value: ThemeMode.system, label: Text(tr('Automática'))),
                          ButtonSegment(value: ThemeMode.light, label: Text(tr('Clara'))),
                          ButtonSegment(value: ThemeMode.dark, label: Text(tr('Oscura'))),
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
                  // Siempre en los dos idiomas, para encontrarlo aunque no entiendas el actual.
                  const Text('Idioma · Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    tr('Los significados y ejemplos también cambian de idioma.'),
                    style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  if (_idioma != null)
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
                        ),
                        segments: [
                          ButtonSegment(value: 'auto', label: Text(tr('Automático'))),
                          const ButtonSegment(value: 'es', label: Text('Español')),
                          const ButtonSegment(value: 'en', label: Text('English')),
                        ],
                        selected: {_idioma!},
                        onSelectionChanged: (elegido) async {
                          final nuevo = elegido.first;
                          setState(() => _idioma = nuevo);
                          await DatosApp.de(context).guardarIdioma(nuevo);
                          // La app se vuelve a armar en el idioma nuevo (y regresa al inicio).
                          Idioma.actual.value = Idioma.desdeTexto(nuevo);
                        },
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
                  Text(tr('Tu hábito'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    tr('Meta diaria: cuántos repasos y ejercicios quieres hacer al día. La ves como un anillo en el inicio.'),
                    style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  if (_metaDiaria != null)
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
                        ),
                        segments: [
                          for (final (n, nombre) in HabitoRepositorio.opcionesMeta)
                            ButtonSegment(value: n, label: Text('$nombre\n$n', textAlign: TextAlign.center)),
                        ],
                        selected: {
                          HabitoRepositorio.opcionesMeta.any((o) => o.$1 == _metaDiaria)
                              ? _metaDiaria!
                              : HabitoRepositorio.metaPorDefecto,
                        },
                        onSelectionChanged: (elegido) {
                          setState(() => _metaDiaria = elegido.first);
                          DatosApp.de(context).guardarMetaDiaria(elegido.first);
                        },
                      ),
                    ),
                  // En la versión web no hay avisos programados (el navegador
                  // no puede despertar a la app a una hora).
                  if (Habito.hayRecordatorio) ...[
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Recordatorio diario'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _recordatorio == null
                          ? tr('Un aviso al día, solo si aún no cumples tu meta.')
                          : tr('Todos los días a las {0} (si aún no cumples tu meta).', [_textoHora(_recordatorio!)]),
                      style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                    ),
                    value: _recordatorio != null,
                    onChanged: (v) => v ? _elegirHora() : _quitarRecordatorio(),
                  ),
                  if (_recordatorio != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _elegirHora,
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: Text(tr('Cambiar hora ({0})', [_textoHora(_recordatorio!)])),
                      ),
                    ),
                  ],
                  if (Habito.hayCaracterDia) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('Carácter del día'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _caracterDia == null
                            ? tr('Un carácter al día en tu pantalla de bloqueo, para repasarlo de un vistazo. Sin sonido.')
                            : tr('Todos los días a las {0}, en tu pantalla de bloqueo. Sin sonido.', [_textoHora(_caracterDia!)]),
                        style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                      ),
                      value: _caracterDia != null,
                      onChanged: (v) => v ? _ponerCaracterDia(_caracterDia ?? (8, 0)) : _quitarCaracterDia(),
                    ),
                    if (_caracterDia != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _elegirHoraCaracter,
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(tr('Cambiar hora ({0})', [_textoHora(_caracterDia!)])),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Caracteres nuevos por día'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    tr('Al llegar a este número, la sesión te ofrece parar o seguir. Entre 10 y 20 es un buen ritmo para no acumular repasos.'),
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
                  Text(tr('Práctica con audio'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Voz lenta'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      tr('Todas las grabaciones suenan un poco más despacio. Sin activarlo, mantén presionado un botón de sonido para oírlo lento.'),
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
                  Text(tr('Palabras nuevas por día'),
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
                title: Text(tr('Acomodar mis trazos a la caligrafía'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  tr('Cada trazo correcto se transforma, con un rebote suave, en la forma exacta del pincel. Apágalo si prefieres ver tu trazo tal cual.'),
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
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Vibrar al trazar'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      tr('Un toque corto con cada trazo correcto y uno más marcado al equivocarte.'),
                      style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                    ),
                    value: _vibracion ?? true,
                    onChanged: _vibracion == null
                        ? null
                        : (v) {
                            setState(() => _vibracion = v);
                            Sensaciones.vibracion = v;
                            DatosApp.de(context).guardarVibracion(v);
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Sonido de pincel'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      tr('El roce del pincel sobre el papel con cada trazo correcto.'),
                      style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                    ),
                    value: _sonidoPincel ?? false,
                    onChanged: _sonidoPincel == null
                        ? null
                        : (v) {
                            setState(() => _sonidoPincel = v);
                            Sensaciones.sonidoPincel = v;
                            if (v) {
                              Sensaciones.trazoBien(); // para oírlo al activarlo
                            } else {
                              Sensaciones.soltar();
                            }
                            DatosApp.de(context).guardarSonidoPincel(v);
                          },
                  ),
                ],
              ),
            ),
            // Batería y 120 Hz: cosa del teléfono, no del navegador.
            if (!kIsWeb) ...[
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
                        Text(tr('Batería y fluidez'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(tr('120 Hz solo cuando hace falta y cuánto gasta la app'),
                            style: TextStyle(fontSize: 13, color: context.colores.icono)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: context.colores.tenue),
                ],
              ),
            ),
            ],
            const SizedBox(height: 12),
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Tus datos'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    kIsWeb
                        ? tr('Tu progreso vive solo en este navegador. Exporta un respaldo para no perderlo si borras los datos del navegador o cambias de equipo.')
                        : tr('Tu progreso vive solo en este teléfono. Exporta un respaldo para no perderlo si cambias de teléfono o lo reinicias.'),
                    style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  _FilaAccion(
                    icono: Icons.save_alt_rounded,
                    titulo: tr('Exportar progreso'),
                    subtitulo: tr('Guarda un archivo .meizi donde elijas'),
                    onTap: _ocupado ? null : _exportar,
                  ),
                  _FilaAccion(
                    icono: Icons.restore_page_outlined,
                    titulo: tr('Importar progreso'),
                    subtitulo: tr('Reemplaza tu progreso por el de un respaldo'),
                    onTap: _ocupado ? null : _importar,
                  ),
                  if (_hayPrevio)
                    _FilaAccion(
                      icono: Icons.undo_rounded,
                      titulo: tr('Deshacer la última importación'),
                      subtitulo: tr('Vuelve al progreso que tenías antes'),
                      onTap: _ocupado ? null : _deshacer,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (Apoyo.disponible) ...[
              TarjetaVidrio(onTap: () => Apoyo.mostrar(context), child: const FilaApoyo()),
              const SizedBox(height: 12),
            ],
            TarjetaVidrio(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PantallaReporte()),
              ),
              child: Row(
                children: [
                  Icon(Icons.feedback_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text(tr('Reportar un problema o sugerir algo'), style: TextStyle(fontSize: 15))),
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
                  Expanded(child: Text(tr('Informe de errores'), style: TextStyle(fontSize: 15))),
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
                  Expanded(child: Text(tr('Créditos y licencias'), style: TextStyle(fontSize: 15))),
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
