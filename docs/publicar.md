# Publicar Meizi Hanzi

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
4. Sube los cambios a la rama `v2` (directo o juntando el PR). **Con eso se
   publica**: al ver una versión nueva en `pubspec.yaml` que aún no está en
   *Releases*, el flujo crea la etiqueta `v2.1.0` y la versión. Si prefieres,
   también se puede publicar subiendo la etiqueta a mano:

   ```bash
   git tag v2.1.0
   git push origin v2.1.0
   ```

El flujo **Lanzamiento** (`.github/workflows/lanzamiento.yml`) compila los APK
firmados y crea la versión en la pestaña *Releases* con:

| Archivo | Para quién |
|---|---|
| `Meizi_Hanzi_2.1.0_arm64.apk` | Casi todos los teléfonos actuales (el más ligero) |
| `Meizi_Hanzi_2.1.0_universal.apk` | Si no sabes cuál: funciona en todos |
| `…_arm32.apk`, `…_x86_64.apk` | Teléfonos viejos y emuladores |
| `SHA256SUMS.txt` | Sumas para comprobar las descargas |

Las notas incluyen la huella SHA-256 del certificado, para que cualquiera
pueda verificar que el APK es el oficial.

## 3. F-Droid

F-Droid compila la app **desde el código** en sus servidores. Requisitos que
Meizi Hanzi ya cumple: licencia libre (GPL-3.0), sin servicios de Google, sin
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

Para los teléfonos Huawei y Honor sin servicios de Google. Se publica en la
tienda **global** (todos los países menos China continental: allá piden
empresa china, registro ICP y certificado de software).

**Lo que hace el autor (una sola vez):**

1. Crea la cuenta de desarrollador en <https://developer.huawei.com/consumer/es/>
   → *Registrarse* → **desarrollador individual**. Es gratis; pide verificar
   la identidad (identificación oficial y, según el país, tarjeta bancaria).
   La revisión tarda de 1 a 3 días hábiles.
2. En **AppGallery Connect** → *Mis apps* → **Nueva app**: tipo *Android*,
   nombre *Meizi Hanzi*, categoría **Educación**, idioma predeterminado
   **español (Latinoamérica)**. El paquete es `com.abrakdabra.hanzidojo`.

**Cada versión:**

1. Descarga el APK de AppGallery: en GitHub → *Actions* → *Lanzamiento* → la
   corrida de la etiqueta (o una corrida a mano) → artefacto
   `meizi-hanzi-X.Y.Z-appgallery` (`Meizi_Hanzi_X.Y.Z_appgallery.apk`). Es el
   APK universal firmado con **la misma llave** que el de GitHub, compilado con
   `--dart-define=TIENDA=appgallery`: sin el aviso de versión nueva de GitHub
   (la regla 3.9 de AppGallery pide que las actualizaciones lleguen solo por
   la tienda). Quien lo instale desde AppGallery puede pasar al de GitHub y al
   revés sin desinstalar.
2. *Versión* → **Paquete de software** → sube ese APK.
3. Ficha (*Información de la app*), en español y en inglés:
   - Nombre: `title.txt`; descripción breve: `short_description.txt`;
     descripción: `full_description.txt` (en `fastlane/metadata/android/es-MX/`
     y `en-US/`).
   - Ícono: `docs/tiendas/icono_216.png` (216 × 216).
   - Capturas: `fastlane/metadata/android/<idioma>/images/phoneScreenshots/`
     (1080 × 1920; salen de `test/capturas_test.dart` y
     `herramientas/capturas_tienda.py`).
4. Aviso de privacidad: **https://abrakdabra1.github.io/hanzi_dojo/privacidad/**
   (se genera de `docs/privacidad.md` en cada publicación de la web).
5. Clasificación de edad: **3+** (sin violencia, compras ni anuncios). Precio:
   gratis. Países: todos menos China continental.
6. *Enviar a revisión* (de 1 a 5 días hábiles).

## 5. Google Play (opcional)

Cuesta un pago único de 25 USD y, para cuentas personales nuevas, Google pide
una prueba cerrada con un grupo de personas durante unas semanas antes de
publicar (revisa las reglas vigentes en la Play Console, cambian seguido). Play solo permite
enlaces de donativos dentro de la app a organizaciones sin fines de lucro, así
que esa versión se compila sin el botón de «Apoyar el proyecto» (el enlace queda
solo en la ficha de la tienda) y sin el aviso de versión nueva de GitHub (las
actualizaciones las da Play). Al configurar la firma en la Play Console, elige
**usar tu propia llave** (la de la sección 1): así el APK de GitHub y el de
Play son intercambiables y nadie tiene que desinstalar para cambiar de uno a
otro.

```bash
flutter build appbundle --release --dart-define=TIENDA=play
```

El enlace de donativos está en `lib/widgets/apoyo.dart` (`Apoyo.enlace`); para
cambiar de plataforma basta con cambiar esa línea.

## Lista rápida antes de cada versión

- [ ] `pubspec.yaml`: versión y código nuevos
- [ ] `CHANGELOG.md` y `fastlane/.../changelogs/<código>.txt`
- [ ] CI en verde (análisis, pruebas, capturas, APK)
- [ ] Probar en el teléfono el APK de perfil de CI
- [ ] Juntar a `v2` (se publica solo) o `git tag vX.Y.Z && git push origin vX.Y.Z`
