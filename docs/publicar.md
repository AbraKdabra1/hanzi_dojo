# Publicar Hanzi Dojo

Guía para sacar una versión: firmarla, subirla a GitHub y llevarla a F-Droid
y a Huawei AppGallery.

## 1. La llave de firma (una sola vez)

Android solo instala una versión nueva **encima** de la anterior si las dos
están firmadas con la misma llave. Por eso la llave se crea una vez y se cuida
para siempre.

En tu PC, desde la carpeta del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas\crear_llave_firma.ps1
```

El script:

1. Crea `Documentos\Hanzi Dojo - llave de firma\hanzi_dojo_lanzamiento.jks`
   con la contraseña que elijas (RSA 4096, válida ~27 años). Si ya existe, no
   la toca.
2. Escribe `android\key.properties` (está en `.gitignore`), para que tus
   compilaciones `release` locales salgan firmadas.
3. Guarda la llave en los **secretos** del repositorio de GitHub
   (`LLAVE_BASE64`, `LLAVE_CLAVE`, `LLAVE_ALIAS`) si tienes `gh` con sesión
   iniciada; si no, te dice cómo pegarlos a mano en
   *Settings → Secrets and variables → Actions*.

Después:

- Copia esa carpeta a una **memoria USB** y a tu **nube**.
- Guarda la contraseña en un **gestor de contraseñas**.
- Nunca la subas a GitHub ni la mandes por chat.

> **Ojo con el teléfono:** la app que tienes instalada está firmada con la
> llave de depuración de tu PC. La primera versión firmada con la llave nueva
> no se instala encima: **exporta tu progreso** (Ajustes → Tus datos),
> desinstala, instala la nueva e importa. Desde ahí, las actualizaciones se
> instalan solas encima.

## 2. Sacar una versión

1. Sube el número en `pubspec.yaml`: `version: 2.1.0+3` → la parte después
   del `+` (código de versión) **siempre** debe crecer.
2. Escribe lo nuevo en `CHANGELOG.md`, en una sección `## 2.1.0`.
3. Copia esas notas, en corto, a
   `fastlane/metadata/android/es-MX/changelogs/3.txt` (el número es el código
   de versión; también en `en-US`).
4. Sube los cambios y crea la etiqueta:

   ```bash
   git tag v2.1.0
   git push origin v2.1.0
   ```

El flujo **Lanzamiento** (`.github/workflows/lanzamiento.yml`) compila los APK
firmados y crea la versión en la pestaña *Releases* con:

| Archivo | Para quién |
|---|---|
| `Hanzi_Dojo_2.1.0_arm64.apk` | Casi todos los teléfonos actuales (el más ligero) |
| `Hanzi_Dojo_2.1.0_universal.apk` | Si no sabes cuál: funciona en todos |
| `…_arm32.apk`, `…_x86_64.apk` | Teléfonos viejos y emuladores |
| `SHA256SUMS.txt` | Sumas para comprobar las descargas |

Las notas incluyen la huella SHA-256 del certificado, para que cualquiera
pueda verificar que el APK es el oficial.

## 3. F-Droid

F-Droid compila la app **desde el código** en sus servidores. Requisitos que
Hanzi Dojo ya cumple: licencia libre (GPL-3.0), sin servicios de Google, sin
rastreadores ni anuncios, y todo el contenido con licencias libres
(ver *Créditos* en la app).

La ficha (título, descripción, ícono, capturas y novedades) vive en
`fastlane/metadata/android/` y F-Droid la lee de ahí.

Pasos (una vez):

1. Crea una cuenta en <https://gitlab.com>.
2. Abre un *issue* de «Request For Packaging» en
   <https://gitlab.com/fdroid/rfp/-/issues> con el enlace al repositorio, o
   directamente un *merge request* a
   <https://gitlab.com/fdroid/fdroiddata> agregando
   `metadata/com.abrakdabra.hanzidojo.yml`. Hay un borrador en
   [`docs/fdroid/com.abrakdabra.hanzidojo.yml`](fdroid/com.abrakdabra.hanzidojo.yml).
3. Responde las dudas de los revisores; cuando lo aprueben, cada etiqueta
   `v*` nueva se publica sola en F-Droid en unos días.

> F-Droid firma con **su propia llave**. Quien instale desde F-Droid
> actualiza desde F-Droid; quien instale el APK de GitHub actualiza desde
> GitHub. No se pueden mezclar sin desinstalar (por eso existe exportar e
> importar el progreso).

## 4. Huawei AppGallery

1. Regístrate como desarrollador en <https://developer.huawei.com/consumer/es/>
   (cuenta personal; piden verificar identidad con una identificación oficial).
2. En **AppGallery Connect** → *Mis apps* → *Nueva app*: Android, categoría
   *Educación*, idioma predeterminado español.
3. Sube el APK **universal** firmado de la versión de GitHub (es la misma
   llave: quien la tenga del APK podrá actualizar desde AppGallery).
4. Ficha: usa los textos e imágenes de `fastlane/metadata/android/es-MX/`.
5. Clasificación de contenido: apta para todo público. Sin compras ni
   anuncios.
6. Aviso de privacidad: enlaza
   <https://github.com/AbraKdabra1/hanzi_dojo/blob/main/docs/privacidad.md>.
7. Envía a revisión (tarda de 1 a 5 días hábiles).

## 5. Google Play (opcional)

Cuesta un pago único de 25 USD y, para cuentas personales nuevas, Google pide
una prueba cerrada con un grupo de personas durante unas semanas antes de
publicar (revisa las reglas vigentes en la Play Console, cambian seguido). Play solo permite
enlaces de donativos dentro de la app a organizaciones sin fines de lucro: en
esa versión el botón de «Apoyar el proyecto» se quitaría y el enlace quedaría
solo en la ficha de la tienda.

## Lista rápida antes de cada versión

- [ ] `pubspec.yaml`: versión y código nuevos
- [ ] `CHANGELOG.md` y `fastlane/.../changelogs/<código>.txt`
- [ ] CI en verde (análisis, pruebas, capturas, APK)
- [ ] Probar en el teléfono el APK de perfil de CI
- [ ] `git tag vX.Y.Z && git push origin vX.Y.Z`
