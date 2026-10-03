# Hanzi Dojo · 汉字道场

App de Android (Flutter) para **aprender a escribir caracteres chinos** trazo por
trazo. Revisa cada trazo mientras escribes, programa los repasos con repetición
espaciada (SM-2) y permite estudiar **por nivel HSK** o **por radical**.

Es **software libre** (GPL-3.0): gratis, sin anuncios, sin cuentas y sin
rastreo. La app no pide permiso de internet.

- Identificador de la app: `com.abrakdabra.hanzidojo`
- Versión: 2.0.0

---

## Qué hace

| Función | Detalle |
|---|---|
| Estudio por nivel | HSK 1 a 6 y 7-9 (lista oficial HSK 3.0). |
| Estudio por radical | Los 214 radicales Kangxi; cada uno muestra su familia de caracteres agrupada por nivel. |
| Búsqueda | Por carácter, pinyin sin tonos (`hao`, `nv`) o significado en español/inglés. |
| Modo novato / experto | Novato: silueta gris y pista del trazo. Experto: cuadrícula vacía. |
| Revisión de trazos | Compara tu trazo con el correcto (DTW) y revisa el sentido: si va al revés te lo dice y muestra por dónde empieza. Si fallas, el trazo se pinta de rojo y se borra. |
| Ajuste caligráfico | Cada trazo correcto se transforma, con un rebote de resorte, en la forma exacta del pincel (kaishu). Se puede apagar en Ajustes. |
| Repetición espaciada | SM-2. Calificas "Difícil / Medio / Fácil"; la app sugiere una según tus errores. Lo "Difícil" vuelve a salir a las 3 tarjetas. |
| Límite diario | Nuevos por día configurable (5 a 50, 15 por defecto) en Ajustes. |
| Ejemplos | 1 o 2 oraciones por carácter con pinyin y traducción al español. |
| Leer | Libros graduados por nivel HSK con pinyin encima de cada carácter (se puede ocultar), traducción por párrafo, voz y nombres propios subrayados. Toca un carácter para ver su ficha y practicar su escritura. Marca los capítulos que terminas. |
| Mis libros | Agrega tus propios textos: TXT (UTF-8, UTF-16 o GBK), EPUB sin DRM o texto pegado. La app los parte en capítulos, calcula el pinyin y estima su nivel HSK. Se quedan solo en el teléfono (no van en el respaldo). Los caracteres tradicionales se consultan como simplificados. |
| Voz | Pronunciación con el motor de voz del teléfono (chino mandarín). |
| Estadísticas | Caracteres estudiados, dominados, repasos para hoy y avance por nivel. |
| Historial | Cada repaso queda registrado: cuánto tardaste, qué trazos fallaste (y si fue al revés), en qué modo y con qué calificación. Es la base de las estadísticas que vienen. |
| Exportar / importar | Ajustes → Tus datos. Guarda tu progreso en un archivo `.hanzidojo` y recupéralo en otro teléfono. Antes de importar se guarda una copia para poder deshacerlo. |
| Informe de errores | Ajustes → Informe de errores. Si algo falla, los detalles se guardan en el teléfono (los últimos 50) para copiarlos al reportar un problema. No se envía nada solo. |

El progreso se guarda **solo en el teléfono** (`progreso.db`). Las actualizaciones
del contenido no lo borran. En teléfonos sin servicios de Google (por ejemplo,
Huawei) no existe el respaldo automático de Android: usa **Exportar progreso**.

### El archivo `.hanzidojo`

Es un JSON comprimido con gzip (se puede abrir con cualquier descompresor):

```json
{
  "formato": "hanzi-dojo-respaldo",
  "version": 1,
  "creado": "2026-09-30T21:40:00.000",
  "progreso":  [{"caracter": "好", "intervalo": 6, "factor": 2.5, "...": "..."}],
  "historial": [{"caracter": "好", "momento": 1790000000, "fallos": "0,3r", "...": "..."}],
  "ajustes":   {"nuevos_por_dia": "15"}
}
```

Todo va por carácter, así que un respaldo sirve aunque cambie el contenido de la app.

---

## Los datos

Todo el contenido está en una base SQLite prearmada, `assets/db/contenido.db`,
que se copia al teléfono la primera vez (por eso la app abre rápido).

| Dato | Fuente | Verificación (`validar_db.py`) |
|---|---|---|
| Niveles HSK | Lista oficial HSK 3.0 (GF 0025-2021, Ministerio de Educación de China) vía [ivankra/hsk30](https://github.com/ivankra/hsk30) | 300 caracteres por nivel del 1 al 6 y 1,200 en 7-9 = **3,000** |
| Lista de escritura | Misma norma (手写字表): 300 / 400 / 500 caracteres | Coincide con la lista oficial |
| Radical de cada carácter | Unicode Unihan (`kRSUnicode`) | Los 214 radicales tienen su carácter y su familia |
| Trazos y medianas | [Make Me a Hanzi](https://github.com/skishore/makemeahanzi) | Cada carácter tiene tantos contornos como medianas |
| Pinyin | Lista oficial HSK (palabras) + CC-CEDICT | Lecturas de polífonos según las palabras oficiales (好 hǎo / hào) |
| Significado en español | Traducido de CC-CEDICT para los 3,000 HSK | 3,000 de 3,000 |
| Ejemplos | Oraciones de [Tatoeba](https://tatoeba.org) (vía krmanik/chinese-example-sentences), traducidas al español | 4,518 ejemplos para 2,755 caracteres; cada ejemplo contiene su carácter |
| Tradicional → simplificado | [OpenCC](https://github.com/BYVoid/OpenCC) `TSCharacters.txt` (para consultar libros propios) | — |
| Libros de «Leer» | Historias clásicas chinas de dominio público, contadas de nuevo para la app (`herramientas_datos/fuentes/libros/`) | Pinyin al día; cada carácter tiene una sílaba válida; los adaptados cumplen la cobertura mínima de su nivel |

### Los libros de «Leer»

Lo que es de dominio público en chino es casi todo chino clásico, y solo se lee
con comodidad en HSK 7-9 (medido: el *Clásico de tres caracteres* o las
*Analectas* tienen apenas un 53 % de caracteres de HSK 1-2). Por eso:

- **HSK 1 a 5: historias adaptadas.** Las historias son clásicas y de dominio
  público (mitos, fábulas, leyendas, anécdotas históricas); el texto en chino
  moderno está escrito para Hanzi Dojo con el vocabulario de cada nivel.
- **HSK 6 y 7-9: textos originales** con su traducción.

| Nivel | Libro | Tipo | Capítulos |
|---|---|---|---|
| HSK 1 | 中国小故事 · Cuentos chinos para niños (孔融让梨, 司马光砸缸, 曹冲称象…) | Adaptado | 5 |
| HSK 2 | 中国神话 · Mitos chinos (盘古, 女娲, 后羿, 嫦娥, 精卫) | Adaptado | 5 |
| HSK 3 | 成语故事 · Historias de chengyu (守株待兔, 画蛇添足, 狐假虎威…) | Adaptado | 6 |
| HSK 4 | 中国民间传说 · Leyendas populares (牛郎织女, 白蛇传, 梁祝, 花木兰) | Adaptado | 4 |
| HSK 5 | 西游记 · Viaje al Oeste | Adaptado | 6 |
| HSK 6 | 增广贤文 · Proverbios del Zengguang Xianwen (41 refranes) | Original | 4 |
| HSK 7-9 | 唐诗选 · Poemas de la dinastía Tang (22 poemas) | Original | 5 |

Los textos originales vienen de [chinese-poetry](https://github.com/chinese-poetry/chinese-poetry)
(MIT), convertidos a simplificados. Todas las traducciones al español y las
versiones graduadas están escritas para Hanzi Dojo.

Cada libro es un archivo de texto fácil de editar (el formato está explicado en
`herramientas_datos/libros.py`). `preparar_libros.py` le agrega el pinyin y
dice qué tan difícil es: qué porcentaje de sus caracteres ya conoce alguien de
ese nivel (sin contar nombres propios y contando las palabras que se explican
al inicio de cada capítulo). Los adaptados deben llegar al 90 %.

Los caracteres que no son HSK (unos 6,500) también están, con significado en
inglés, para que las familias de radicales estén completas.

### Cómo se construye (solo si cambias los datos)

Necesitas Python 3.

```bash
# 1. (Opcional) volver a elegir ejemplos. Requiere: pip install pypinyin
python herramientas_datos/seleccionar_ejemplos.py

# 1b. (Si editaste un libro de «Leer») pinyin y dificultad. Requiere pypinyin
python herramientas_datos/preparar_libros.py

# 2. Construir la base y el archivo de versión
python herramientas_datos/construir_db.py

# 3. Revisar que todo cumpla
python herramientas_datos/validar_db.py

# 4. (Opcional) recortar la fuente si aparecieron caracteres nuevos.
#    Requiere: pip install fonttools  y la fuente variable NotoSansSC-VF.ttf
python herramientas_datos/recortar_fuente.py ruta/a/NotoSansSC-VF.ttf
```

Para **corregir una traducción**, edita la línea en
`herramientas_datos/fuentes/traducciones/significados_es.tsv` (significados) o
`ejemplos_es.tsv` (oraciones) y vuelve a correr `construir_db.py`.
Para **quitar una oración** que no te guste, agrega su número a
`ejemplos_excluidos.tsv` y corre los pasos 1 y 2.

Cada vez que cambian las fuentes cambia `lib/datos/version_contenido.dart`, y la
app sabe que tiene que copiar el contenido nuevo (sin tocar tu progreso).

---

## Cómo correr la app

Requisitos: Flutter 3.44 (Dart 3.12) y Android SDK. La base ya viene en el repo,
así que **no necesitas Python** para compilar.

```bash
flutter pub get
flutter run --profile     # para probar la fluidez real
flutter run               # modo debug (más lento, para programar)
flutter test              # pruebas automáticas
```

> El modo **debug** siempre se siente más lento. Para juzgar la fluidez
> (120 Hz en el Pura 70) usa `--profile` o `--release`.

### Instalar el APK que genera GitHub

Cada push corre la integración continua (pestaña **Actions** del repo). Al
terminar, en la sección **Artifacts** está `hanzi-dojo-profile-apk`: descárgalo,
descomprímelo y abre el `.apk` en el teléfono.

---

## Estructura del código

```
lib/
├── main.dart                     Arranque: abre la base, tema (Noto Sans SC) y licencias
├── datos/
│   ├── base_datos.dart           Abre progreso.db y adjunta contenido.db (ATTACH)
│   ├── repositorio.dart          Todas las consultas: siguiente tarjeta, búsqueda, radicales…
│   ├── sesion_estudio.dart       Orden de las tarjetas en una sesión (repasos, nuevos, "Difícil")
│   ├── srs.dart                  Algoritmo SM-2
│   ├── respaldo.dart             Exportar / importar el progreso (.hanzidojo)
│   ├── registro_errores.dart     Errores guardados en el teléfono (informe)
│   ├── importar_libro.dart       Mis libros: TXT/EPUB → capítulos, pinyin y nivel
│   ├── modelos.dart              Caracter, Radical, Ejemplo, Progreso, DetallePractica…
│   ├── datos_app.dart            Da acceso al repositorio desde cualquier pantalla
│   └── version_contenido.dart    (generado) versión de contenido.db
├── helpers/
│   ├── dtw_helper.dart           Compara tu trazo con el correcto
│   ├── cache_trazos.dart         Convierte los contornos SVG a Path una sola vez
│   ├── archivos.dart             Diálogos "Guardar como" / "Abrir" de Android
│   ├── zip_simple.dart           Lector mínimo de ZIP (para EPUB)
│   └── pinyin_helper.dart        Colores por tono
├── painters/                     Dibujo del lienzo (cuadrícula, silueta, tinta, pistas)
├── widgets/
│   ├── lienzo_escritura.dart     El lienzo donde escribes (eventos táctiles crudos)
│   ├── texto_lectura.dart        Párrafo con pinyin encima y ficha del carácter tocado
│   ├── boton_voz.dart            Pronunciación (flutter_tts)
│   └── comunes.dart, …           Piezas de interfaz reutilizables
└── screens/                      Inicio, modo, selección, radicales, familia,
                                  estudio, estadísticas, ajustes, errores, créditos,
                                  biblioteca, libro y lectura («Leer»)
android/app/src/main/kotlin/…/MainActivity.kt   Archivos (guardar/abrir) y tasa de refresco más alta
herramientas_datos/               Scripts de Python que arman la base (ver arriba)
herramientas_arte/                Dibuja la ilustración del Templo del Cielo del inicio
test/                             Pruebas: SM-2, sesión, trazos, caligrafía, base de datos real,
                                  historial, respaldo, informe de errores y lector
```

### Fluidez

- El lienzo usa eventos táctiles crudos (`Listener`) y solo repinta la tinta, no
  la pantalla completa (`ControladorTrazos` + capas con `RepaintBoundary`).
- Los contornos de cada carácter se convierten a `Path` una sola vez (caché).
- Sin desenfoque (`BackdropFilter`) en listas: era lo que más frenaba el scroll.
- `MainActivity` pide a Android el modo de pantalla con más Hz disponible.

---

## Integración continua

`.github/workflows/ci.yml` hace en cada push: construir y validar la base,
`flutter analyze`, `flutter test` y compilar el APK de perfil. En ramas de trabajo,
los resultados se publican además en la rama `ci-registros`.

---

## Licencias

El **código** de Hanzi Dojo es software libre bajo la
[GNU GPL versión 3 o posterior](LICENSE) (GPL-3.0-or-later): puedes usarlo,
estudiarlo, modificarlo y compartirlo, siempre que las versiones que distribuyas
también sean libres y publiquen su código.

Los datos y la fuente tienen sus propias licencias (el texto completo está en
`assets/licencias/` y dentro de la app, en **Créditos**):

| Recurso | Licencia |
|---|---|
| CC-CEDICT | CC BY-SA 4.0 |
| Make Me a Hanzi — gráficos | Arphic Public License |
| Make Me a Hanzi — diccionario | LGPL |
| Unicode Unihan | Unicode License |
| hsk30 (ivankra) | MIT |
| Tatoeba (oraciones) | CC BY 2.0 FR |
| Noto Sans SC | SIL Open Font License 1.1 |
| OpenCC | Apache 2.0 |
| chinese-poetry (textos clásicos de «Leer») | MIT |

Las traducciones al español de significados y ejemplos derivan de CC-CEDICT y
Tatoeba, por lo que se comparten bajo sus mismas licencias.
