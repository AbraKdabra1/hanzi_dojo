# Hanzi Dojo · 汉字道场

App (Flutter) para **aprender a escribir caracteres chinos** trazo por
trazo, en Android, iPhone/iPad y el navegador. Revisa cada trazo mientras escribes, programa los repasos con repetición
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
| Buscar dibujando | Botón del lápiz junto a la búsqueda. Dibuja un carácter que no sabes leer y la app sugiere los más parecidos de los 3,000 HSK con cada trazo (compara la forma y el orden de tus trazos, sin internet). |
| Orden de trazos | En el estudio, «Orden de trazos» anima el carácter trazo por trazo, con el número de cada trazo; se puede repetir. |
| Modo novato / experto | Novato: silueta gris y pista del trazo. Experto: cuadrícula vacía. |
| Revisión de trazos | Compara tu trazo con el correcto (DTW) y revisa el sentido: si va al revés te lo dice y muestra por dónde empieza. Si fallas, el trazo se pinta de rojo y se borra. |
| Ajuste caligráfico | Cada trazo correcto se transforma, con un rebote de resorte, en la forma exacta del pincel (kaishu). Se puede apagar en Ajustes. |
| Repetición espaciada | SM-2. Calificas "Difícil / Medio / Fácil"; la app sugiere una según tus errores. Lo "Difícil" vuelve a salir a las 3 tarjetas. |
| Límite diario | Nuevos por día configurable (5 a 50, 15 por defecto) en Ajustes. |
| Ejemplos | 1 o 2 oraciones por carácter con pinyin y traducción al español. |
| Leer | Libros graduados por nivel HSK con pinyin encima de cada carácter (se puede ocultar), traducción por párrafo, voz y nombres propios subrayados. Toca un carácter para ver su ficha, practicar su escritura o mandar la palabra completa al repaso de vocabulario. 🎧 lee el capítulo entero en voz alta resaltando la palabra que suena. Al final de cada capítulo, tres preguntas de comprensión. Marca los capítulos que terminas. |
| Mis libros | Agrega tus propios textos: TXT (UTF-8, UTF-16 o GBK), EPUB sin DRM o texto pegado. La app los parte en capítulos, calcula el pinyin y estima su nivel HSK. Se quedan solo en el teléfono (no van en el respaldo). Los caracteres tradicionales se consultan como simplificados. |
| Voz | Grabaciones de hablantes nativos incluidas en la app (sílabas y ~8,500 palabras HSK): suenan en cualquier teléfono, sin internet. En oraciones largas usa la voz del teléfono si la tiene. |
| Practicar con audio | Inicio → Practicar. **Tonos**: oye una sílaba y elige su tono entre cuatro botones que dibujan su curva (o los dos tonos de una palabra). **Escucha**: oye una palabra y elige su carácter o su significado. **Vocabulario**: repaso espaciado de las ~10,900 palabras HSK (no solo caracteres), empezando por las que usan caracteres que ya estudiaste. **Pinyin**: escribe cómo se lee una palabra (`ni3hao3` o `nǐhǎo`). Mantén presionado un botón de sonido para oírlo lento, o activa «Voz lenta» en Ajustes. |
| Simulacro HSK | Practicar → Simulacro HSK. Como el examen: 30 preguntas en 12 minutos en tres secciones (escucha, lectura y caracteres), sin saber si acertaste hasta el final. Se aprueba con 60; la app recuerda tu mejor calificación por nivel. |
| Examen de ubicación | Practicar → Examen de ubicación. Cinco preguntas por nivel, de HSK 1 hacia arriba, hasta encontrar el nivel por el que te conviene empezar. |
| Meta diaria | Ajustes → Tu hábito: 10, 20, 40 o 60 repasos y ejercicios al día. En el inicio se ve como un anillo que se llena; al cumplirla, la app lo celebra. |
| Recordatorio | Ajustes → Tu hábito: un aviso al día a la hora que elijas, solo si todavía no cumples tu meta. Lo programa Android (sin servicios de Google: funciona en Huawei) y sobrevive a reinicios. |
| Racha y protector | Los días seguidos practicando (escritura o audio). Un protector por semana cubre un día sin práctica para que la racha no se rompa (🛡️ en el inicio y en el calendario). |
| Logros | Inicio → 🏆. Rachas de 7, 30 y 100 días, cada nivel HSK completo, 100 a 3,000 caracteres, palabras, «Oído fino» (10 tonos seguidos), libros terminados… Se desbloquean solos y se pueden compartir. |
| Tarjeta para compartir | Una imagen 1080 × 1350 con tu racha o un logro, tus cifras y el avance por nivel, para enviarla por WhatsApp, Instagram, etc. o guardarla. |
| Widget | En la pantalla de inicio del teléfono: carácter del día (de los que ya estudiaste), repasos pendientes y avance de hoy. Se actualiza al salir de la app y cada 3 horas. |
| Estadísticas | Caracteres estudiados, dominados, repasos para hoy, avance por nivel (caracteres y vocabulario), aciertos de cada ejercicio con audio y los tonos que más confundes. |
| Historial | Cada repaso queda registrado: cuánto tardaste, qué trazos fallaste (y si fue al revés), en qué modo y con qué calificación. Es la base de las estadísticas que vienen. |
| Apoyar el proyecto | Ajustes → Apoyar el proyecto (también al final de Créditos): un donativo voluntario con PayPal. No desbloquea nada; la app es igual para todos. Se sugiere una sola vez, después de un logro, y no vuelve a aparecer. La versión para Google Play se compila sin este botón. |
| Exportar / importar | Ajustes → Tus datos. Guarda tu progreso en un archivo `.hanzidojo` y recupéralo en otro teléfono. Antes de importar se guarda una copia para poder deshacerlo. |
| Informe de errores | Ajustes → Informe de errores. Si algo falla, los detalles se guardan en el teléfono (los últimos 50) para copiarlos al reportar un problema. No se envía nada solo. |
| Modo oscuro «tinta» | Ajustes → Apariencia: Automática (la del teléfono), Clara u Oscura. En pantallas OLED la oscura gasta bastante menos batería. La rama del inicio se vuelve «ciruelo bajo la luna». |
| Idioma | Ajustes → Idioma · Language: español, inglés o el del teléfono. En inglés, los significados vienen de CC-CEDICT y los ejemplos de Tatoeba en inglés; el recordatorio y el widget también cambian. |
| Tabletas y horizontal | En pantallas anchas el contenido se centra a una columna cómoda; en horizontal el estudio pone el lienzo junto a la información del carácter. |
| Vibración y sonido | Una vibración suave con cada trazo correcto (otra al fallar) y, si quieres, un sonido de pincel. Se eligen en Ajustes, junto al ajuste caligráfico. |
| Batería y fluidez | Ajustes → Batería y fluidez. La pantalla va a 120 Hz solo mientras tocas o algo se desplaza (o siempre, si lo eliges). Con el ahorro de batería del teléfono la app no anima nada. Muestra el consumo del momento y puede medir el promedio de una sesión. |

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
| Vocabulario | Las palabras de la lista oficial HSK 3.0 (hsk30), con su pinyin partido por carácter y significado en español (traducido de CC-CEDICT, todos los niveles) | Cada palabra tiene una sílaba válida por carácter y su significado en español |
| Preguntas de comprensión | Escritas para Hanzi Dojo en español e inglés (`herramientas_datos/fuentes/libros/preguntas.json`); las opciones se barajan de forma fija al construir la base | 3 por capítulo, con 4 opciones distintas en cada idioma |
| Pronunciación (audio) | [audio-cmn](https://github.com/hugolpz/audio-cmn): 1,707 sílabas (voz de Chen Wang) y 8,569 palabras HSK (voz de Yue Tan), en `assets/audio/` (Opus, ~23 MB) | `test/audio_test.dart`: cada palabra de la lista tiene su archivo |

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

Las preguntas de comprensión de cada capítulo están en `preguntas.json`, en la
misma carpeta: la pregunta y sus cuatro opciones en español y en inglés, y cuál
es la correcta.

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

# 5. (Opcional) volver a preparar las grabaciones. Requiere ffmpeg y numpy
git clone --filter=blob:none --sparse https://github.com/hugolpz/audio-cmn /tmp/audio-cmn
(cd /tmp/audio-cmn && git sparse-checkout set 64k)
python herramientas_datos/preparar_audio.py /tmp/audio-cmn/64k
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

### Descargar la app

Las versiones firmadas están en la pestaña **Releases** del repositorio
(`Hanzi_Dojo_X.Y.Z_arm64.apk` para casi todos los teléfonos; `universal` si no
sabes cuál). Cómo se publican (llave de firma, F-Droid, AppGallery):
[`docs/publicar.md`](docs/publicar.md). Novedades: [`CHANGELOG.md`](CHANGELOG.md).
Privacidad: [`docs/privacidad.md`](docs/privacidad.md) — la app no tiene
permiso de internet.

- **iPhone y iPad**, sin computadora: la versión web,
  https://abrakdabra1.github.io/hanzi_dojo/ → Safari → Compartir →
  *Agregar a pantalla de inicio* ([`docs/web.md`](docs/web.md)). También
  sirve en Android y en la computadora.
- **iPhone y iPad**, como app: el `.ipa` de Releases, instalado con tu
  propio Apple ID (gratis, se renueva cada 7 días): [`docs/ios.md`](docs/ios.md).

### Instalar el APK que genera GitHub

Cada push corre la integración continua (pestaña **Actions** del repo). Al
terminar, en la sección **Artifacts** está `hanzi-dojo-profile-apk`: descárgalo,
descomprímelo y abre el `.apk` en el teléfono.

---

## Estructura del código

```
lib/
├── main.dart                     Arranque: abre la base, idioma, apariencia, energía y licencias
├── idioma.dart                   Español / inglés: tr('texto') y fechas
├── textos_en.dart                Los textos de la interfaz en inglés (español → inglés)
├── tema.dart                     Colores claro/oscuro (ColoresTinta) y Apariencia
├── datos/
│   ├── base_datos.dart           Abre progreso.db y adjunta contenido.db (ATTACH)
│   ├── repositorio.dart          Todas las consultas: siguiente tarjeta, búsqueda, radicales…
│   ├── repositorio_practica.dart Consultas de la práctica con audio (vocabulario, ejercicios)
│   ├── repositorio_habito.dart   Meta diaria, protector de racha, logros y recordatorio
│   ├── logros.dart               Los logros y cuánto llevas de cada uno
│   ├── practica.dart             Palabra, preguntas, entrenador de tonos y sesión de vocabulario
│   ├── examen.dart               Simulacros HSK y examen de ubicación (armar y calificar)
│   ├── sesion_estudio.dart       Orden de las tarjetas en una sesión (repasos, nuevos, "Difícil")
│   ├── srs.dart                  Algoritmo SM-2
│   ├── respaldo.dart             Exportar / importar el progreso (.hanzidojo)
│   ├── registro_errores.dart     Errores guardados en el teléfono (informe)
│   ├── importar_libro.dart       Mis libros: TXT/EPUB → capítulos, pinyin y nivel
│   ├── reporte.dart              Reporte de problema (formulario de GitHub prellenado)
│   ├── audio.dart                Qué grabaciones tocar para un texto (sílabas y palabras)
│   ├── modelos.dart              Caracter, Radical, Ejemplo, Progreso, DetallePractica…
│   ├── datos_app.dart            Da acceso al repositorio desde cualquier pantalla
│   └── version_contenido.dart    (generado) versión de contenido.db
├── helpers/
│   ├── dtw_helper.dart           Compara tu trazo con el correcto
│   ├── cache_trazos.dart         Convierte los contornos SVG a Path una sola vez
│   ├── archivos.dart             Diálogos "Guardar como" / "Abrir" de Android
│   ├── energia.dart              Batería: 120 Hz bajo demanda, ahorro de batería, medir consumo
│   ├── zip_simple.dart           Lector mínimo de ZIP (para EPUB)
│   ├── pinyin_entrada.dart       Lee el pinyin que escribes (números, acentos, sin tono)
│   ├── habito.dart               Recordatorio, widget y compartir (canal con Android)
│   ├── reconocedor.dart          Buscar dibujando: qué caracteres se parecen a lo que dibujaste
│   ├── sensaciones.dart          Vibración y sonido de pincel
│   └── pinyin_helper.dart        Colores por tono
├── painters/                     Dibujo del lienzo (cuadrícula, silueta, tinta, pistas)
│   ├── rama_ciruelo.dart         Rama de ciruelo en flor del fondo (viento y pétalos)
│   └── capa_fija.dart            Dibuja una vez en imagen lo que no cambia (cuadrícula, silueta)
├── widgets/
│   ├── lienzo_escritura.dart     El lienzo donde escribes (eventos táctiles crudos)
│   ├── texto_lectura.dart        Párrafo con pinyin encima y ficha del carácter tocado
│   ├── boton_voz.dart            Pronunciación: grabaciones (just_audio) o voz del teléfono
│   ├── fondo_tinta.dart          Fondo de papel; en el inicio la rama se mece ~30 s y se apaga
│   ├── ejercicio.dart            Piezas de los ejercicios (opciones, curva de cada tono, resumen)
│   ├── animacion_trazos.dart     Orden de trazos animado
│   ├── preguntas_comprension.dart Preguntas al final de cada capítulo de «Leer»
│   ├── apoyo.dart                Apoyar el proyecto (donativo voluntario; oculto en Google Play)
│   └── comunes.dart, …           Piezas de interfaz reutilizables
└── screens/                      Inicio, modo, selección, radicales, familia,
                                  estudio, estadísticas, ajustes, errores, créditos,
                                  biblioteca, libro y lectura («Leer»), práctica,
                                  tonos, escucha, vocabulario y pinyin, simulacros y
                                  ubicación, buscar dibujando, logros y compartir
android/app/src/main/kotlin/…/MainActivity.kt   Archivos (guardar/abrir), energía (tasa de refresco, batería) y hábito
android/app/src/main/kotlin/…/Habito.kt         Recordatorio diario, widget de inicio y compartir imagen
herramientas_datos/               Scripts de Python que arman la base (ver arriba) y el ícono
herramientas/crear_llave_firma.ps1  Crea la llave de firma de lanzamiento (Windows)
fastlane/metadata/android/        Ficha de tienda (F-Droid, AppGallery): textos, ícono, capturas
docs/                             Publicar, privacidad y receta de F-Droid
test/                             Pruebas: SM-2, sesión, trazos, caligrafía, base de datos real,
                                  historial, respaldo, informe de errores, lector, práctica,
                                  exámenes, reconocedor e idioma (que no falte ningún texto en inglés)
```

### Fluidez

- El lienzo usa eventos táctiles crudos (`Listener`) y solo repinta la tinta, no
  la pantalla completa (`ControladorTrazos` + capas con `RepaintBoundary`).
- Los contornos de cada carácter se convierten a `Path` una sola vez (caché).
- Sin desenfoque (`BackdropFilter`) en listas: era lo que más frenaba el scroll.
- `MainActivity` pide a Android el modo de pantalla con más Hz disponible.

---

## Reportar problemas y colaborar

En la app: Ajustes → **Reportar un problema**. Se abre el formulario del
repositorio en GitHub ya lleno (versión, teléfono e informe de errores, si lo
quieres adjuntar); también se puede copiar el reporte y mandarlo por otro medio.
Hay formularios para *errores de la app*, *errores en el contenido* y
*sugerencias* (`.github/ISSUE_TEMPLATE/`). Cómo corregir traducciones, libros o
código: [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Integración continua

`.github/workflows/ci.yml` hace en cada push: construir y validar la base,
`flutter analyze`, `flutter test`, capturas de las pantallas principales en claro
y oscuro (`test/capturas_test.dart`, con la base y las fuentes reales) y compilar
el APK de perfil. En ramas de trabajo, los resultados y las capturas
(`capturas/*.png`) se publican además en la rama `ci-registros`.

`ios.yml` compila el `.ipa` en una Mac y prueba la app en el simulador de
iPhone (rama `ci-ios`); `web.yml` compila la versión web, la prueba en Chrome
y Safari (rama `ci-web`) y, desde `v2`, la publica en GitHub Pages.

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
| audio-cmn (grabaciones de pronunciación) | CC BY-SA |

Las traducciones al español de significados y ejemplos derivan de CC-CEDICT y
Tatoeba, por lo que se comparten bajo sus mismas licencias. Igual las grabaciones
de `assets/audio/` (recortadas, con volumen igualado y en Opus): CC BY-SA, como
el original.
