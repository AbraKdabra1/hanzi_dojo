package com.abrakdabra.hanzidojo

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.provider.OpenableColumns
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
 *  2. Energía (canal "hanzi_dojo/energia", ver lib/helpers/energia.dart):
 *     · "fluidez": pide el modo de pantalla con la tasa de refresco más alta
 *       (p. ej. 120 Hz en el Huawei Pura 70) o la suelta para que el sistema
 *       decida. Varios fabricantes dejan a las apps en 60 Hz si no piden
 *       otra cosa; pero 120 Hz todo el tiempo gasta batería aunque nada se
 *       mueva. Por eso la app la pide SOLO mientras tocas o se desplaza algo,
 *       y la suelta en cuanto la pantalla se queda quieta.
 *     · "ahorro": si el teléfono tiene activado el ahorro de batería.
 *     · "bateria": nivel, corriente y temperatura (pantalla "Consumo de
 *       batería" en Ajustes, para medir cuánto gasta la app).
 *
 *  3. Hábito (canal "hanzi_dojo/habito", ver lib/helpers/habito.dart y
 *     Habito.kt): programar o quitar el recordatorio diario (pide el permiso
 *     de notificaciones en Android 13+), actualizar el widget y compartir la
 *     imagen de progreso.
 */
class MainActivity : FlutterActivity() {

    // ── Archivos ────────────────────────────────────────────────────────────

    private companion object {
        const val CANAL_ARCHIVOS = "hanzi_dojo/archivos"
        const val CANAL_ENERGIA = "hanzi_dojo/energia"
        const val CANAL_HABITO = "hanzi_dojo/habito"
        const val PEDIR_NOTIFICACIONES = 4103
        const val PEDIR_GUARDAR = 4101
        const val PEDIR_ABRIR = 4102
    }

    /** Respuesta pendiente mientras el diálogo del sistema está abierto. */
    private var pendiente: MethodChannel.Result? = null

    /** Lo que se va a escribir cuando el usuario elija dónde guardar. */
    private var bytesPorGuardar: ByteArray? = null

    /** Respuesta y hora pendientes mientras se pide el permiso de notificaciones. */
    private var pendientePermiso: MethodChannel.Result? = null
    private var horaPendiente: Pair<Int, Int> = Pair(20, 0)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_ARCHIVOS)
            .setMethodCallHandler { llamada, resultado -> atenderArchivos(llamada, resultado) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_ENERGIA)
            .setMethodCallHandler { llamada, resultado -> atenderEnergia(llamada, resultado) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_HABITO)
            .setMethodCallHandler { llamada, resultado -> atenderHabito(llamada, resultado) }
    }

    // ── Hábito ──────────────────────────────────────────────────────────────

    private fun atenderHabito(llamada: MethodCall, resultado: MethodChannel.Result) {
        try {
            when (llamada.method) {
                "programarRecordatorio" -> {
                    val hora = llamada.argument<Int>("hora") ?: 20
                    val minuto = llamada.argument<Int>("minuto") ?: 0
                    val faltaPermiso = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    if (!faltaPermiso) {
                        Recordatorios.programar(this, hora, minuto)
                        resultado.success(true)
                    } else if (pendientePermiso != null) {
                        resultado.success(false)
                    } else {
                        pendientePermiso = resultado
                        horaPendiente = Pair(hora, minuto)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PEDIR_NOTIFICACIONES)
                        }
                    }
                }
                "cancelarRecordatorio" -> {
                    Recordatorios.cancelar(this)
                    resultado.success(null)
                }
                "actualizarWidget" -> {
                    WidgetHanzi.actualizar(this)
                    resultado.success(null)
                }
                "compartirImagen" -> compartirImagen(llamada, resultado)
                else -> resultado.notImplemented()
            }
        } catch (e: Exception) {
            resultado.error("habito", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PEDIR_NOTIFICACIONES) return
        val resultado = pendientePermiso ?: return
        pendientePermiso = null
        val concedido = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (concedido) Recordatorios.programar(this, horaPendiente.first, horaPendiente.second)
        resultado.success(concedido)
    }

    /** Guarda la imagen en la caché y abre el menú "Compartir" de Android. */
    private fun compartirImagen(llamada: MethodCall, resultado: MethodChannel.Result) {
        val png = llamada.argument<ByteArray>("png")
        if (png == null) {
            resultado.success(false)
            return
        }
        val carpeta = File(cacheDir, "compartir")
        carpeta.mkdirs()
        val archivo = File(carpeta, "hanzi_dojo_progreso.png")
        archivo.writeBytes(png)
        val uri = Uri.parse("content://$packageName.archivos/${archivo.name}")
        val envio = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            val texto = llamada.argument<String>("texto")
            if (!texto.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, texto)
            clipData = ClipData.newRawUri("", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(envio, if (DatosHanzi.ingles(this)) "Share my progress" else "Compartir mi progreso"))
        resultado.success(true)
    }

    // ── Energía ─────────────────────────────────────────────────────────────

    private fun atenderEnergia(llamada: MethodCall, resultado: MethodChannel.Result) {
        try {
            when (llamada.method) {
                "fluidez" -> {
                    if (llamada.argument<Boolean>("alta") == true) pedirTasaDeRefrescoMaxima()
                    else soltarTasaDeRefresco()
                    resultado.success(null)
                }
                "ahorro" -> {
                    val energia = getSystemService(Context.POWER_SERVICE) as PowerManager
                    resultado.success(energia.isPowerSaveMode)
                }
                "bateria" -> resultado.success(estadoBateria())
                else -> resultado.notImplemented()
            }
        } catch (e: Exception) {
            resultado.error("energia", e.message, null)
        }
    }

    /**
     * Estado de la batería. "corriente" es la que reporta el teléfono tal cual
     * (casi siempre en microamperios; el signo cambia según el fabricante):
     * lib/helpers/energia.dart la interpreta.
     */
    private fun estadoBateria(): Map<String, Any?> {
        val bateria = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        // Aviso "pegajoso" del sistema: se lee sin registrar ningún receptor.
        val filtro = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val aviso = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(null, filtro, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(null, filtro)
        }
        val corriente = bateria.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val contador = bateria.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val cargando = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) bateria.isCharging
            else (aviso?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
        return mapOf(
            "nivel" to bateria.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            // Integer.MIN_VALUE = el teléfono no lo informa.
            "corriente" to if (corriente == Int.MIN_VALUE) null else corriente,
            "contador" to if (contador == Int.MIN_VALUE || contador <= 0) null else contador,
            "cargando" to cargando,
            "voltaje" to aviso?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0),
            "temperatura" to aviso?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0),
            "tasa" to (obtenerPantalla()?.refreshRate ?: 0f).toDouble(),
        )
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
        if (atributos.preferredDisplayModeId == mejorModo.modeId) return
        atributos.preferredDisplayModeId = mejorModo.modeId
        window.attributes = atributos
    }

    /** Quita la preferencia: el sistema vuelve a decidir (suele bajar a 60 Hz o menos). */
    private fun soltarTasaDeRefresco() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val atributos = window.attributes
        if (atributos.preferredDisplayModeId == 0) return
        atributos.preferredDisplayModeId = 0
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
