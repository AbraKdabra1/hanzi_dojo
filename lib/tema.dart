// ─────────────────────────────────────────────────────────────────────────────
// tema.dart — Colores de la app: modo claro (papel de arroz) y modo oscuro
// («tinta»)
//
// ¿Por qué un modo oscuro? En pantallas OLED (como la del Huawei Pura 70)
// cada píxel negro está APAGADO: una pantalla oscura gasta bastante menos
// batería que una clara, sobre todo en sesiones largas de práctica.
//
// Las pantallas no usan colores fijos (Colors.black87, grey.shade600…) sino
// los de ColoresTinta, que cambian con el modo:
//     final c = context.colores;   Text('Hola', style: TextStyle(color: c.tinta))
// Los colores con significado propio (niveles HSK, tonos del pinyin, rojo de
// error, verde de acierto) son iguales en los dos modos.
//
// Apariencia (Ajustes): Automática (la del teléfono), Clara u Oscura.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'simbolos_web.dart';

@immutable
class ColoresTinta extends ThemeExtension<ColoresTinta> {
  const ColoresTinta({
    required this.oscuro,
    required this.papelArriba,
    required this.papelAbajo,
    required this.mancha,
    required this.tinta,
    required this.suave,
    required this.tenue,
    required this.icono,
    required this.tarjeta,
    required this.bordeTarjeta,
    required this.sombra,
    required this.translucido,
    required this.separador,
    required this.hoja,
    required this.boton,
    required this.textoBoton,
    required this.lienzo,
    required this.bordeLienzo,
    required this.cuadricula,
    required this.silueta,
    required this.trazo,
  });

  /// true en modo oscuro (para dibujos con variante nocturna: rama, lienzo).
  final bool oscuro;

  /// Degradado del fondo de papel.
  final Color papelArriba, papelAbajo;

  /// Color de las manchas difusas del fondo (sin transparencia; se aplica aparte).
  final Color mancha;

  /// Texto principal, secundario y terciario.
  final Color tinta, suave, tenue;

  /// Íconos neutros.
  final Color icono;

  /// Tarjetas translúcidas (TarjetaVidrio) y su borde y sombra.
  final Color tarjeta, bordeTarjeta, sombra;

  /// Fondos translúcidos pequeños (resumen, buscador, botones claros).
  final Color translucido;

  /// Pistas de barras de avance, divisores suaves.
  final Color separador;

  /// Hojas que suben desde abajo (ficha de carácter) y diálogos propios.
  final Color hoja;

  /// Botón principal ("Estudiar") y su texto.
  final Color boton, textoBoton;

  /// Lienzo de escritura.
  final Color lienzo, bordeLienzo, cuadricula, silueta, trazo;

  static const claro = ColoresTinta(
    oscuro: false,
    papelArriba: Color(0xFFF8F4EE),
    papelAbajo: Color(0xFFF2EDE5),
    mancha: Color(0xFF3C2814),
    tinta: Color(0xDE000000),
    suave: Color(0xFF616161),
    tenue: Color(0xFF757575),
    icono: Color(0x8A000000),
    tarjeta: Color(0xB3FFFFFF),
    bordeTarjeta: Color(0xCCFFFFFF),
    sombra: Color(0x14000000),
    translucido: Color(0x99FFFFFF),
    separador: Color(0x14000000),
    hoja: Color(0xFAFFFFFF),
    boton: Color(0xDE000000),
    textoBoton: Colors.white,
    lienzo: Colors.white,
    bordeLienzo: Color(0xFFE0E0E0),
    cuadricula: Color(0xFFE0E0E0),
    silueta: Color(0x1F9E9E9E),
    trazo: Color(0xFF111111),
  );

  /// Noche de tinta: fondos casi negros y cálidos (en OLED, casi apagados),
  /// texto color papel.
  static const oscuroTinta = ColoresTinta(
    oscuro: true,
    papelArriba: Color(0xFF151311),
    papelAbajo: Color(0xFF0E0D0B),
    mancha: Color(0xFFFFE2BE),
    tinta: Color(0xFFEDE6DB),
    suave: Color(0xFFBDB4A8),
    tenue: Color(0xFF948B80),
    icono: Color(0xFFBDB4A8),
    tarjeta: Color(0xCC1F1C19),
    bordeTarjeta: Color(0x1FFFFFFF),
    sombra: Color(0x66000000),
    translucido: Color(0x26FFFFFF),
    separador: Color(0x1FFFFFFF),
    hoja: Color(0xFA1E1B18),
    boton: Color(0xFFEDE6DB),
    textoBoton: Color(0xFF151311),
    lienzo: Color(0xFF1C1916),
    bordeLienzo: Color(0xFF3A342E),
    cuadricula: Color(0xFF3A342E),
    silueta: Color(0x24FFFFFF),
    trazo: Color(0xFFF2ECE2),
  );

  @override
  ColoresTinta copyWith() => this;

  @override
  ColoresTinta lerp(ThemeExtension<ColoresTinta>? otro, double t) {
    if (otro is! ColoresTinta) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColoresTinta(
      oscuro: t < 0.5 ? oscuro : otro.oscuro,
      papelArriba: c(papelArriba, otro.papelArriba),
      papelAbajo: c(papelAbajo, otro.papelAbajo),
      mancha: c(mancha, otro.mancha),
      tinta: c(tinta, otro.tinta),
      suave: c(suave, otro.suave),
      tenue: c(tenue, otro.tenue),
      icono: c(icono, otro.icono),
      tarjeta: c(tarjeta, otro.tarjeta),
      bordeTarjeta: c(bordeTarjeta, otro.bordeTarjeta),
      sombra: c(sombra, otro.sombra),
      translucido: c(translucido, otro.translucido),
      separador: c(separador, otro.separador),
      hoja: c(hoja, otro.hoja),
      boton: c(boton, otro.boton),
      textoBoton: c(textoBoton, otro.textoBoton),
      lienzo: c(lienzo, otro.lienzo),
      bordeLienzo: c(bordeLienzo, otro.bordeLienzo),
      cuadricula: c(cuadricula, otro.cuadricula),
      silueta: c(silueta, otro.silueta),
      trazo: c(trazo, otro.trazo),
    );
  }
}

extension ColoresDelTema on BuildContext {
  /// Colores del modo actual (claro u oscuro).
  ColoresTinta get colores => Theme.of(this).extension<ColoresTinta>() ?? ColoresTinta.claro;
}

/// Tema visual de toda la app, en claro u oscuro.
ThemeData temaHanziDojo([Brightness brillo = Brightness.light]) {
  final oscuro = brillo == Brightness.dark;
  final c = oscuro ? ColoresTinta.oscuroTinta : ColoresTinta.claro;
  return ThemeData(
    fontFamily: 'NotoSansSC',
    // Versión web: los emoji y símbolos viajan con la app (ver simbolos_web.dart).
    fontFamilyFallback: kIsWeb ? familiasSimbolosWeb : null,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: brillo,
      surface: oscuro ? const Color(0xFF1E1B18) : null,
      onSurface: c.tinta,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: c.tinta,
      // Íconos de la barra de estado legibles sobre el fondo.
      systemOverlayStyle: oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    dividerColor: c.separador,
    // Botones principales en tinta (negro de día, papel de noche), como el
    // botón «Estudiar» del inicio; sin el rosa que daría el color semilla.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.boton,
        foregroundColor: c.textoBoton,
        disabledBackgroundColor: c.separador,
        disabledForegroundColor: c.tenue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.tinta,
        side: BorderSide(color: c.tinta.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.suave)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: c.boton,
        selectedForegroundColor: c.textoBoton,
        foregroundColor: c.tinta,
        side: BorderSide(color: c.bordeLienzo),
      ),
    ),
  );
}

/// Apariencia elegida en Ajustes (la app la escucha para cambiar al momento).
class Apariencia {
  Apariencia._();

  static final modo = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// 'auto' | 'claro' | 'oscuro' (como se guarda en la base).
  static ThemeMode desdeTexto(String? texto) => switch (texto) {
        'claro' => ThemeMode.light,
        'oscuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String aTexto(ThemeMode modo) => switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'oscuro',
        ThemeMode.system => 'auto',
      };
}
