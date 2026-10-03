# Hanzi Dojo · 汉字道场

App de Android (Flutter) para **aprender a escribir caracteres chinos** trazo por
trazo. Revisa cada trazo mientras escribes, programa los repasos con repetición
espaciada (SM-2) y permite estudiar **por nivel HSK** o **por radical**.

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
| Voz | Pronunciación con el motor de voz del teléfono (chino mandarín). |
| Estadísticas | Caracteres estudiados, dominados, repasos para hoy y avance por nivel. |

El progreso se guarda **solo en el teléfono** (`progreso.db`). Las actualizaciones
del contenido no lo borran.

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

Los caracteres que no son HSK (unos 6,500) también están, con significado en
inglés, para que las familias de radicales estén completas.

### Cómo se construye (solo si cambias los datos)

Necesitas Python 3.

```bash
# 1. (Opcional) volver a elegir ejemplos. Requiere: pip install pypinyin
python herramientas_datos/seleccionar_ejemplos.py

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
│   ├── modelos.dart              Caracter, Radical, Ejemplo, Progreso…
│   ├── datos_app.dart            Da acceso al repositorio desde cualquier pantalla
│   └── version_contenido.dart    (generado) versión de contenido.db
├── helpers/
│   ├── dtw_helper.dart           Compara tu trazo con el correcto
│   ├── cache_trazos.dart         Convierte los contornos SVG a Path una sola vez
│   └── pinyin_helper.dart        Colores por tono
├── painters/                     Dibujo del lienzo (cuadrícula, silueta, tinta, pistas)
├── widgets/
│   ├── lienzo_escritura.dart     El lienzo donde escribes (eventos táctiles crudos)
│   ├── boton_voz.dart            Pronunciación (flutter_tts)
│   └── comunes.dart, …           Piezas de interfaz reutilizables
└── screens/                      Inicio, modo, selección, radicales, familia,
                                  estudio, estadísticas, ajustes, créditos
android/app/src/main/kotlin/…/MainActivity.kt   Pide la tasa de refresco más alta de la pantalla
herramientas_datos/               Scripts de Python que arman la base (ver arriba)
herramientas_arte/                Dibuja la ilustración del Templo del Cielo del inicio
test/                             Pruebas: SM-2, sesión, trazos, caligrafía, base de datos real
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

El código de la app es del autor. Los datos y la fuente tienen sus propias
licencias (el texto completo está en `assets/licencias/` y dentro de la app, en
**Créditos**):

| Recurso | Licencia |
|---|---|
| CC-CEDICT | CC BY-SA 4.0 |
| Make Me a Hanzi — gráficos | Arphic Public License |
| Make Me a Hanzi — diccionario | LGPL |
| Unicode Unihan | Unicode License |
| hsk30 (ivankra) | MIT |
| Tatoeba (oraciones) | CC BY 2.0 FR |
| Noto Sans SC | SIL Open Font License 1.1 |

Las traducciones al español de significados y ejemplos derivan de CC-CEDICT y
Tatoeba, por lo que se comparten bajo sus mismas licencias.
