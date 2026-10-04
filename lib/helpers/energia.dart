// ─────────────────────────────────────────────────────────────────────────────
// energia.dart — Gastar poca batería
//
// Habla con MainActivity.kt por el canal "hanzi_dojo/energia".
//
// 1. Tasa de refresco bajo demanda. Una pantalla a 120 Hz gasta más aunque
//    nada se mueva. Antes la app pedía 120 Hz todo el tiempo; ahora:
//      · Automática (por defecto): 120 Hz solo mientras tocas la pantalla o
//        algo se desplaza, y 1.5-3 s después se suelta (el sistema baja a
//        60 Hz o menos mientras lees o piensas).
//      · Siempre máxima: como antes (para quien prefiera la fluidez total).
//    DetectorActividad (abajo) avisa de cada toque y scroll de toda la app.
// 2. Ahorro de batería del teléfono: si está activado, nunca se piden
//    120 Hz y la rama del inicio no se anima.
// 3. Lectura de la batería (nivel, corriente, temperatura) para la pantalla
//    "Batería y fluidez": así se puede medir cuánto gasta la app de verdad.
//    La medición es opcional: solo lee la batería (cada 15 s, con la app
//    abierta) mientras está encendida.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ModoFluidez {
  /// 120 Hz solo al tocar o desplazar (ahorra batería).
  automatica,

  /// 120 Hz todo el tiempo.
  maxima,
}

/// Una lectura de la batería.
class LecturaBateria {
  const LecturaBateria({
    required this.nivel,
    required this.miliamperios,
    required this.cargando,
    required this.capacidadMah,
    required this.temperatura,
    required this.tasaPantalla,
  });

  /// Porcentaje de carga (0-100).
  final int nivel;

  /// Corriente que sale de la batería, en mA (null si el teléfono no la da o
  /// si está cargando).
  final double? miliamperios;
  final bool cargando;

  /// Capacidad total estimada de la batería (null si no se puede calcular).
  final double? capacidadMah;

  /// °C
  final double temperatura;

  /// Hz a los que va la pantalla en este momento.
  final double tasaPantalla;

  /// Cuánto bajaría la batería en una hora a este ritmo (null si no se sabe).
  double? get porcentajePorHora {
    final ma = miliamperios, capacidad = capacidadMah;
    if (ma == null || capacidad == null || capacidad <= 0) return null;
    return ma / capacidad * 100;
  }

  /// La corriente que da Android viene en microamperios en casi todos los
  /// teléfonos, pero algunos la dan en miliamperios y el signo varía según el
  /// fabricante. Con la pantalla encendida un teléfono nunca gasta menos de
  /// ~10 mA, así que: |valor| ≥ 10,000 → µA; menor → mA.
  static double? interpretarCorriente(int? cruda) {
    if (cruda == null || cruda == 0) return null;
    final valor = cruda.abs().toDouble();
    return valor >= 10000 ? valor / 1000 : valor;
  }

  /// Capacidad total a partir de lo que queda (µAh) y el porcentaje.
  static double? capacidad(int? contadorMicroAh, int nivel) {
    if (contadorMicroAh == null || nivel <= 0) return null;
    final mah = contadorMicroAh / 1000 / (nivel / 100);
    // Fuera de lo razonable para un teléfono: mejor no inventar.
    return (mah > 500 && mah < 20000) ? mah : null;
  }

  factory LecturaBateria.desdeMapa(Map<Object?, Object?> m) {
    final nivel = (m['nivel'] as int?) ?? 0;
    final cargando = m['cargando'] == true;
    return LecturaBateria(
      nivel: nivel,
      miliamperios: cargando ? null : interpretarCorriente(m['corriente'] as int?),
      cargando: cargando,
      capacidadMah: capacidad(m['contador'] as int?, nivel),
      temperatura: ((m['temperatura'] as int?) ?? 0) / 10,
      tasaPantalla: (m['tasa'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Resumen de una medición de consumo (desde que se encendió en
/// "Batería y fluidez" hasta ahora, mientras la app estuvo abierta).
class MedicionConsumo {
  const MedicionConsumo({
    required this.inicio,
    required this.segundosEnPantalla,
    required this.muestras,
    required this.sumaMa,
    required this.nivelInicial,
    required this.ultima,
    required this.huboCarga,
  });

  factory MedicionConsumo.nueva() => MedicionConsumo(
        inicio: DateTime.now(),
        segundosEnPantalla: 0,
        muestras: 0,
        sumaMa: 0,
        nivelInicial: null,
        ultima: null,
        huboCarga: false,
      );

  final DateTime inicio;

  /// Tiempo medido (solo cuenta con la app abierta).
  final int segundosEnPantalla;
  final int muestras;
  final double sumaMa;
  final int? nivelInicial;
  final LecturaBateria? ultima;

  /// Si el teléfono estuvo cargando en algún momento (la medición no vale).
  final bool huboCarga;

  double? get promedioMa => muestras == 0 ? null : sumaMa / muestras;

  /// %/hora según la corriente promedio.
  double? get porcentajePorHora {
    final ma = promedioMa, capacidad = ultima?.capacidadMah;
    if (ma == null || capacidad == null) return null;
    return ma / capacidad * 100;
  }

  /// Puntos de batería que bajó durante la medición.
  int? get bajo {
    final inicial = nivelInicial, actual = ultima?.nivel;
    if (inicial == null || actual == null) return null;
    return inicial - actual;
  }

  MedicionConsumo con(LecturaBateria l, int segundos) => MedicionConsumo(
        inicio: inicio,
        segundosEnPantalla: segundosEnPantalla + segundos,
        muestras: muestras + (l.miliamperios == null ? 0 : 1),
        sumaMa: sumaMa + (l.miliamperios ?? 0),
        nivelInicial: nivelInicial ?? l.nivel,
        ultima: l,
        huboCarga: huboCarga || l.cargando,
      );
}

class Energia {
  Energia._();

  static const _canal = MethodChannel('hanzi_dojo/energia');

  /// Tiempo sin tocar ni desplazar antes de soltar los 120 Hz (entre 1 y 2
  /// veces este tiempo).
  static const espera = Duration(milliseconds: 1500);

  /// true si el teléfono tiene activado el ahorro de batería.
  static final ahorro = ValueNotifier<bool>(false);

  static ModoFluidez _modo = ModoFluidez.automatica;
  static ModoFluidez get modo => _modo;

  static bool _alta = false;
  static Timer? _revision;

  /// Cuenta toques y desplazamientos; si no cambió entre dos revisiones, la
  /// pantalla estuvo quieta (sin pedir la hora en cada evento del dedo).
  static int _actividades = 0;
  static int _actividadesAlRevisar = 0;

  /// Para las pruebas: si ahora mismo se están pidiendo 120 Hz.
  static bool get pidiendoTasaAlta => _alta;

  /// Al arrancar la app, con el modo guardado en Ajustes.
  static Future<void> iniciar(ModoFluidez modo) async {
    _modo = modo;
    await revisarAhorro();
    await _aplicarModo();
  }

  /// Vuelve a consultar el ahorro de batería (al volver a la app).
  static Future<void> revisarAhorro() async {
    try {
      ahorro.value = await _canal.invokeMethod<bool>('ahorro') ?? false;
    } on MissingPluginException {
      // Pruebas o plataforma sin el canal.
    } on PlatformException {
      // Si falla, se queda como estaba.
    }
  }

  static Future<void> cambiarModo(ModoFluidez nuevo) async {
    _modo = nuevo;
    await _aplicarModo();
  }

  static Future<void> _aplicarModo() async {
    _revision?.cancel();
    _revision = null;
    _alta = _modo == ModoFluidez.maxima && !ahorro.value;
    await _pedir(_alta);
  }

  /// Se llama en cada toque o desplazamiento (DetectorActividad).
  /// Barata: solo habla con Android al subir o bajar la tasa.
  static void actividad() {
    if (_modo == ModoFluidez.maxima || ahorro.value) return;
    _actividades++;
    if (!_alta) {
      _alta = true;
      _pedir(true);
      _programarRevision();
    }
  }

  static void _programarRevision() {
    _actividadesAlRevisar = _actividades;
    _revision = Timer(espera, _revisar);
  }

  /// Se suelta entre 1.5 y 3 s después del último toque.
  static void _revisar() {
    if (_actividades == _actividadesAlRevisar) {
      _alta = false;
      _revision = null;
      _pedir(false);
    } else {
      _programarRevision();
    }
  }

  /// La app pasa a segundo plano: suelta todo.
  static void enPausa() {
    _revision?.cancel();
    _revision = null;
    if (_alta) {
      _alta = false;
      _pedir(false);
    }
    _muestreo?.cancel();
    _muestreo = null;
  }

  /// La app vuelve: revisa el ahorro y aplica el modo.
  static Future<void> alVolver() async {
    await revisarAhorro();
    await _aplicarModo();
    if (medicion.value != null && _muestreo == null) _empezarMuestreo();
  }

  // ── Medición de consumo (opcional; apagada por defecto) ──────────────────

  /// Cada cuánto se lee la batería mientras se mide.
  static const intervaloMuestreo = Duration(seconds: 15);

  /// Medición en curso (null = no se está midiendo).
  static final medicion = ValueNotifier<MedicionConsumo?>(null);
  static Timer? _muestreo;

  static void iniciarMedicion() {
    medicion.value = MedicionConsumo.nueva();
    _empezarMuestreo();
  }

  static void detenerMedicion() {
    _muestreo?.cancel();
    _muestreo = null;
    medicion.value = null;
  }

  static void _empezarMuestreo() {
    _muestreo?.cancel();
    _muestrear(0);
    _muestreo = Timer.periodic(intervaloMuestreo, (_) => _muestrear(intervaloMuestreo.inSeconds));
  }

  static Future<void> _muestrear(int segundos) async {
    final lectura = await leerBateria();
    final actual = medicion.value;
    if (lectura == null || actual == null) return;
    medicion.value = actual.con(lectura, segundos);
  }

  static Future<void> _pedir(bool alta) async {
    try {
      await _canal.invokeMethod<void>('fluidez', {'alta': alta});
    } on MissingPluginException {
      // Pruebas.
    } on PlatformException {
      // Teléfono que no deja elegir el modo de pantalla: no pasa nada.
    }
  }

  /// Estado de la batería, o null si no se puede leer.
  static Future<LecturaBateria?> leerBateria() async {
    try {
      final m = await _canal.invokeMethod<Map<Object?, Object?>>('bateria');
      return m == null ? null : LecturaBateria.desdeMapa(m);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Avisa a [Energia] de cada toque y desplazamiento en toda la app.
/// Va en el builder de MaterialApp (main.dart).
class DetectorActividad extends StatelessWidget {
  const DetectorActividad({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => Energia.actividad(),
      onPointerMove: (_) => Energia.actividad(),
      onPointerSignal: (_) => Energia.actividad(),
      child: NotificationListener<ScrollUpdateNotification>(
        // Incluye el desplazamiento que sigue solo después de soltar el dedo.
        onNotification: (_) {
          Energia.actividad();
          return false;
        },
        child: child,
      ),
    );
  }
}
