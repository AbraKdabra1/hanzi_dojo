# hanzi_what

lib/
├── main.dart                 # Punto de entrada, inicializa DB y lanza app
├── screens/                  # Pantallas completas (UI + lógica de navegación)
│   ├── pantalla_inicio.dart
│   ├── pantalla_seleccion.dart
│   ├── pantalla_estudio.dart
│   └── pantalla_estadisticas.dart
├── painters/                 # Painters personalizados para lienzo y grids
│   ├── pincel_painter.dart
│   ├── grid_painter.dart
│   ├── svg_fondo_painter.dart   # (recreado)
│   └── pista_roja_painter.dart  # (recreado)
├── helpers/                  # Utilidades
│   └── pinyin_helper.dart
├── widgets/                  # Componentes reutilizables
│   ├── fondo_tinta.dart      # Fondo decorativo
│   ├── glass_speaker_button.dart # Botón con efecto glassmorphism para TTS
│   └── lienzo_hanzi.dart     # (actualizado con correcciones)
└── database/                 # Acceso a datos
    └── db_helper.dart        # SQLite + lógica de progreso SRS

## 🚀 Últimas Actualizaciones (Novedades de la Versión)

### 🏗️ Arquitectura y Refactorización
* **Diseño Modular:** Separación estricta de responsabilidades en archivos independientes (`main.dart` para UI, `db_helper.dart` para el backend local y `lienzo_hanzi.dart` para el motor gráfico), siguiendo principios de Clean Architecture.
* **Navegación Indexada:** Implementación de *Banners de Sección* estandarizados en el código fuente para colapsar bloques y facilitar la mantenibilidad.

### 🎨 UI/UX y Diseño Visual (Minimalismo)
* **Efecto Liquid Glass (Glassmorphism):** Rediseño de los botones principales utilizando filtros de desenfoque (`BackdropFilter`) para lograr un acabado esmerilado, translúcido y premium.
* **Prisma Motivacional:** Integración de una animación 3D rotativa (`AnimatedSwitcher`) en el menú principal que alterna frases inspiradoras, optimizada para evitar saltos en el layout.
* **Transiciones Fluidas:** Uso de `AnimatedCrossFade` en la pantalla de selección para transicionar de manera orgánica entre el catálogo HSK y los resultados de búsqueda.
* **Estadísticas Dinámicas:** Gráficas de dona (`CircularProgressIndicator`) con animaciones de llenado temporalizadas (`AnimationController`) para mostrar el progreso global e individual.

### ⚙️ Nuevas Funcionalidades Core
* **Búsqueda Dinámica SQLite:** Motor de búsqueda en tiempo real capaz de filtrar caracteres por Hanzi, Pinyin o significado en fracciones de segundo.
* **Módulo de Estadísticas Independiente:** Nueva pantalla dedicada exclusivamente a auditar el progreso de estudio, segregando el aprendizaje por cada nivel del HSK.
* **Feedback Geométrico Inmediato:** El lienzo de dibujo ahora castiga visualmente los errores, pintando los trazos incorrectos de color rojo por 400ms antes de borrarlos.
* **Contexto de Vocabulario:** Nuevo panel modal interactivo ("Ver ejemplos") que extrae de la base de datos palabras compuestas que utilizan el carácter que se está estudiando.

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
