# Hanzi Dojo en iPhone y iPad

Hanzi Dojo no está en la App Store: Apple cobra 99 USD al año por publicar,
aunque la app sea gratis, y este proyecto no cobra ni paga por existir. Por
eso se instala como **app propia**: con tu Apple ID normal y gratuito, desde
una computadora (Windows o Mac). Nadie paga nada.

> **Lo único incómodo:** Apple hace que las apps instaladas así duren **7
> días**. Después hay que renovarlas (un clic, o automático con AltStore). Tu
> progreso **no se pierde** al renovar.

## Qué descargar

En la pestaña **Releases** del repositorio, junto a los APK de Android:
`Hanzi_Dojo_X.Y.Z_iOS_sin_firmar.ipa`. ("Sin firmar" quiere decir que la
firma se la pone tu propio Apple ID al instalarla.)

Las versiones de prueba también están en **Actions → iOS → Artifacts**
(`hanzi-dojo-ios-sin-firmar`, viene en un .zip).

## Opción 1: Sideloadly (la más sencilla)

1. En la computadora instala **Sideloadly** (sideloadly.io). En Windows pide
   también **iTunes** e **iCloud** descargados de la página de Apple (no los de
   la Microsoft Store).
2. Conecta el iPhone por cable, desbloquéalo y toca **Confiar** en esta
   computadora.
3. Abre Sideloadly, arrastra el archivo `.ipa`, escribe tu Apple ID y toca
   **Start**. Puede pedirte el código de verificación de Apple.
4. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos** → toca
   tu Apple ID → **Confiar**.
5. En iOS 16 o más nuevo: **Ajustes → Privacidad y seguridad → Modo de
   desarrollador** → actívalo y reinicia el iPhone (solo la primera vez).

**Cada 7 días:** repite el paso 3 con el mismo `.ipa` (o uno más nuevo). Se
instala encima y conserva tu progreso.

## Opción 2: AltStore (se renueva sola)

AltStore (altstore.io) pone en el iPhone una app que renueva Hanzi Dojo por
Wi-Fi, siempre que **AltServer** esté abierto en tu computadora y ambos estén
en la misma red. Se instala una vez con cable; luego, para agregar Hanzi
Dojo, abre AltStore en el iPhone → **Mis apps → +** → elige el `.ipa`.

## Bueno saber

- Con un Apple ID gratuito caben **3 apps** instaladas así a la vez.
- Sideloadly y AltStore no son de Apple ni de este proyecto. Le piden tu Apple
  ID a Apple para firmar la app; si prefieres, usa un Apple ID secundario.
- Si dejas pasar los 7 días, la app no abre hasta que la renueves; tus datos
  siguen ahí. Igual conviene exportar el progreso de vez en cuando (Ajustes →
  Tus datos → Exportar progreso, se guarda en la app Archivos).

## Qué funciona en iPhone

Todo lo de Android, salvo el **widget** de la pantalla de inicio (vendrá
después). El recordatorio diario usa las notificaciones de iOS: se programan
los avisos de las próximas dos semanas y se rehacen cada vez que sales de la
app (si ese día ya cumpliste tu meta, no avisa). Las pronunciaciones suenan
aunque el iPhone esté en silencio.

## Para quien desarrolla

`.github/workflows/ios.yml` compila en una Mac de GitHub (gratis en
repositorios públicos) y prueba la app en el simulador de iPhone
(`integration_test/ios_test.dart`): que arranque, que las grabaciones suenen
y capturas de pantalla, publicadas en la rama `ci-ios`. Las funciones de iOS
están en `ios/Runner/AppDelegate.swift` (los mismos canales que
`MainActivity.kt` en Android).
