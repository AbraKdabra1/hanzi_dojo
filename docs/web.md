# Meizi Hanzi en el navegador (iPhone, iPad, Android o computadora)

La misma app, abierta desde una página web. No hay que descargar nada de una
tienda ni pagar nada: se abre la dirección y se agrega a la pantalla de
inicio, donde queda como una app más (con su ícono, a pantalla completa).
Después de abrirla una vez, **funciona sin internet**.

**Dirección:** https://abrakdabra1.github.io/hanzi_dojo/

Es la forma más fácil en **iPhone y iPad**: no necesita computadora ni Apple
ID, y no caduca a los 7 días como el `.ipa` (ver [ios.md](ios.md)).

## iPhone y iPad

1. Abre la dirección en **Safari**.
2. Toca **Compartir** (el cuadro con la flecha hacia arriba) → **Agregar a
   pantalla de inicio** → **Agregar**.
3. Abre Meizi Hanzi **desde el ícono** de la pantalla de inicio. La primera
   vez descarga el diccionario (15 MB, unos segundos con Wi-Fi).

> Úsala siempre desde el ícono: así Safari guarda tu progreso aparte y no lo
> borra. Si la usas como página normal, Safari puede borrar los datos de los
> sitios que no visitas en 7 días.

## Android

Lo mejor en Android es el APK (pestaña Releases): trae el recordatorio diario
y el widget. Si prefieres la versión web: ábrela en **Chrome** → menú ⋮ →
**Instalar app** (o **Agregar a la pantalla principal**).

## Computadora (Windows, Mac, Linux)

Ábrela en Chrome, Edge o Safari. En Chrome y Edge aparece un botón de
**Instalar** en la barra de direcciones para tenerla en su propia ventana.
Se escribe con el mouse, con una tableta gráfica o con el dedo si la pantalla
es táctil.

## Qué cambia frente a la app

- **Sin recordatorio diario ni widget**: el navegador no puede avisar con la
  página cerrada.
- **Sin el ajuste de batería y 120 Hz** (eso lo decide el navegador).
- Tu progreso vive **en ese navegador** (en esa pantalla de inicio, en
  iPhone). Para pasarlo a otro teléfono, o al APK, usa Ajustes → Tus datos →
  **Exportar progreso** (se descarga un archivo `.meizi`) y luego
  **Importar** en el otro lado. Conviene exportar de vez en cuando.
- Las pronunciaciones son las mismas grabaciones; la voz de "leer en voz
  alta" es la del navegador.

## Actualizaciones

Cada vez que se abre con internet, revisa si hay una versión nueva y la usa
(tu progreso no se toca). Sin internet usa la última que guardó.

## Privacidad

La página la sirve GitHub Pages: como cualquier sitio, GitHub recibe la
dirección IP de quien la abre (ver la política de privacidad de GitHub). El
motor de Flutter descarga de Google Fonts su tipografía base y, si aparece un
carácter poco común que la app no trae (fuera de HSK y de los libros de
«Leer»), la fuente que lo dibuja; Google recibe solo la petición de esa
fuente. La app no tiene cuentas, anuncios ni analítica y no envía tu progreso
a ningún lado: se queda en el navegador. Ver [privacidad.md](privacidad.md).

## Para quien desarrolla

- `lib/plataforma/`: lo que cambia entre el teléfono y el navegador (imports
  condicionales). En la web los archivos de la app y las bases viven en
  IndexedDB, con SQLite compilado a WebAssembly (`sqflite_common_ffi_web`).
- `web/`: `index.html` (pantalla de carga e íconos de iPhone),
  `manifest.json`, `flutter_bootstrap.js` y `sw_hanzi.js` (sin internet).
  Los íconos salen de `herramientas_datos/generar_icono.py`.
- Si el navegador no toca Opus en Ogg (Safari en versiones de iOS
  anteriores), las grabaciones se reempacan a CAF en el momento
  (`lib/helpers/ogg_a_caf.dart`), igual que en la app de iOS.
- `.github/workflows/web.yml` compila, prueba en Chrome y Safari
  (`herramientas/capturas_web.mjs`, registros y capturas en la rama
  `ci-web`) y, desde `v2`, publica en GitHub Pages. Para eso, una sola vez,
  en el repositorio: **Settings → Pages → Source: GitHub Actions**, y en
  **Settings → Environments → github-pages → Deployment branches** agregar
  `v2`.
- Para probarla en tu PC: `dart run sqflite_common_ffi_web:setup` una vez y
  luego `flutter run -d chrome`.
