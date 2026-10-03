package com.abrakdabra.hanzidojo

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Actividad principal de Android.
 *
 * Flutter dibuja toda la interfaz dentro de esta actividad; aquí hay dos
 * cosas propias:
 *
 *  1. Archivos (canal "hanzi_dojo/archivos", ver lib/helpers/archivos.dart):
 *     los diálogos "Guardar como…" y "Abrir" del sistema, para exportar e
 *     importar el progreso y agregar libros. Usan el Storage Access
 *     Framework: el usuario elige el archivo y la app no necesita permisos de
 *     almacenamiento. También abre enlaces en el navegador (reportar un
 *     problema en GitHub) sin que la app necesite permiso de internet.
 *
 *  2. Pedirle a Android el modo de pantalla con la tasa de
 *     refresco más alta disponible (por ejemplo 120 Hz en el Huawei Pura 70).
 *
 * ¿Por qué? Varios fabricantes dejan a las apps en 60 Hz a menos que la app
 * pida otra cosa. Flutter dibuja al ritmo que marque la pantalla, así que al
 * pedir el modo más rápido la animación se adapta sola a cada teléfono:
 * 60, 90, 120 o 144 Hz.
 *
 * Costo: mientras la app está en pantalla, el teléfono se queda en ese modo
 * aunque nada se mueva, así que gasta algo más de batería que a 60 Hz. Al
 * salir de la app el sistema vuelve a su frecuencia automática.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pedirTasaDeRefrescoMaxima()
    }

    // ── Archivos ────────────────────────────────────────────────────────────

    private companion object {
        const val CANAL_ARCHIVOS = "hanzi_dojo/archivos"
        const val PEDIR_GUARDAR = 4101
        const val PEDIR_ABRIR = 4102
    }

    /** Respuesta pendiente mientras el diálogo del sistema está abierto. */
    private var pendiente: MethodChannel.Result? = null

    /** Lo que se va a escribir cuando el usuario elija dónde guardar. */
    private var bytesPorGuardar: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_ARCHIVOS)
            .setMethodCallHandler { llamada, resultado -> atenderArchivos(llamada, resultado) }
    }

    private fun atenderArchivos(llamada: MethodCall, resultado: MethodChannel.Result) {
        when (llamada.method) {
            "abrirEnlace" -> {
                val url = llamada.argument<String>("url")
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    resultado.success(true)
                } catch (e: Exception) {
                    resultado.success(false) // no hay navegador
                }
            }
            "info" -> try {
                resultado.success(infoDispositivo())
            } catch (e: Exception) {
                resultado.error("info", e.message, null)
            }
            "guardar", "abrir" -> {
                if (pendiente != null) {
                    resultado.error("ocupado", "Ya hay un diálogo de archivos abierto", null)
                    return
                }
                val intent = if (llamada.method == "guardar") {
                    bytesPorGuardar = llamada.argument<ByteArray>("bytes")
                    Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = llamada.argument<String>("tipo") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, llamada.argument<String>("nombre"))
                    }
                } else {
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        val tipos = llamada.argument<List<String>>("tipos")
                        if (tipos != null && tipos != listOf("*/*")) {
                            putExtra(Intent.EXTRA_MIME_TYPES, tipos.toTypedArray())
                        }
                    }
                }
                pendiente = resultado
                try {
                    startActivityForResult(
                        intent,
                        if (llamada.method == "guardar") PEDIR_GUARDAR else PEDIR_ABRIR,
                    )
                } catch (e: Exception) {
                    // Teléfono sin selector de documentos (muy raro).
                    pendiente = null
                    bytesPorGuardar = null
                    resultado.error("sin_selector", e.message, null)
                }
            }
            else -> resultado.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PEDIR_GUARDAR && requestCode != PEDIR_ABRIR) return
        val resultado = pendiente ?: return
        pendiente = null
        val bytes = bytesPorGuardar
        bytesPorGuardar = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            resultado.success(null) // el usuario canceló
            return
        }
        // Leer o escribir el archivo fuera del hilo de la interfaz.
        Thread {
            try {
                val respuesta: Any? = if (requestCode == PEDIR_GUARDAR) {
                    // "wt" (escribir y truncar) no lo aceptan todos los proveedores; si
                    // falla, "w" sirve igual porque el documento recién se creó vacío.
                    val salida = try {
                        contentResolver.openOutputStream(uri, "wt")
                    } catch (e: Exception) {
                        null
                    } ?: contentResolver.openOutputStream(uri, "w")
                    salida!!.use { it.write(bytes ?: ByteArray(0)) }
                    nombreDe(uri)
                } else {
                    val leidos = contentResolver.openInputStream(uri)!!.use { it.readBytes() }
                    mapOf("nombre" to nombreDe(uri), "bytes" to leidos)
                }
                runOnUiThread { resultado.success(respuesta) }
            } catch (e: Exception) {
                runOnUiThread { resultado.error("archivo", e.message, null) }
            }
        }.start()
    }

    /** Nombre visible del archivo elegido (por ejemplo "hanzi_dojo_2026-09-30.hanzidojo"). */
    private fun nombreDe(uri: Uri): String =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
            ?: (uri.lastPathSegment ?: "archivo")

    /** Versión de la app y modelo del teléfono (para el informe de errores). */
    @Suppress("DEPRECATION")
    private fun infoDispositivo(): Map<String, Any> {
        val paquete = packageManager.getPackageInfo(packageName, 0)
        val compilacion =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) paquete.longVersionCode
            else paquete.versionCode.toLong()
        return mapOf(
            "version" to (paquete.versionName ?: "?"),
            "compilacion" to compilacion.toString(),
            "modelo" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "android" to "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
        )
    }

    // ── Tasa de refresco ────────────────────────────────────────────────────

    /**
     * Busca, entre los modos de pantalla con la MISMA resolución que la
     * actual, el de mayor tasa de refresco y lo marca como preferido para
     * esta ventana. No cambia la resolución (eso haría parpadear la pantalla).
     */
    private fun pedirTasaDeRefrescoMaxima() {
        // Los modos de pantalla existen desde Android 6 (API 23).
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val pantalla: Display = obtenerPantalla() ?: return
        val modoActual = pantalla.mode

        val mejorModo = pantalla.supportedModes
            .filter {
                it.physicalWidth == modoActual.physicalWidth &&
                    it.physicalHeight == modoActual.physicalHeight
            }
            .maxByOrNull { it.refreshRate }
            ?: return

        val atributos = window.attributes
        atributos.preferredDisplayModeId = mejorModo.modeId
        window.attributes = atributos
    }

    /** Pantalla donde está la app (la API cambió en Android 11). */
    @Suppress("DEPRECATION")
    private fun obtenerPantalla(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        }
}
