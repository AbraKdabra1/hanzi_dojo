import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de lanzamiento: android/key.properties (NO se sube al repo; lo crea
// herramientas/crear_llave_firma.ps1, y en GitHub lo arma el flujo
// .github/workflows/lanzamiento.yml con los secretos). Ver docs/publicar.md.
// Sin ese archivo el APK "release" se firma con la llave de depuración: sirve
// para probar en tu teléfono, no para publicar.
val propiedadesLlave = Properties()
val archivoLlave = rootProject.file("key.properties")
if (archivoLlave.exists()) {
    FileInputStream(archivoLlave).use { propiedadesLlave.load(it) }
}

android {
    namespace = "com.abrakdabra.hanzidojo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.abrakdabra.hanzidojo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (archivoLlave.exists()) {
            create("lanzamiento") {
                storeFile = file(propiedadesLlave.getProperty("storeFile"))
                storePassword = propiedadesLlave.getProperty("storePassword")
                keyAlias = propiedadesLlave.getProperty("keyAlias")
                keyPassword = propiedadesLlave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // SIN_FIRMA=1: APK sin firmar (F-Droid firma con su propia llave).
            signingConfig = when {
                archivoLlave.exists() -> signingConfigs.getByName("lanzamiento")
                System.getenv("SIN_FIRMA") != null -> null
                else -> signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
