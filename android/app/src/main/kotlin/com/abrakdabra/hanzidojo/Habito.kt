package com.abrakdabra.hanzidojo

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.widget.RemoteViews
import java.io.File
import java.io.FileNotFoundException
import java.util.Calendar
import java.util.TimeZone

/*
 * Hábito (fase 6): lo que Android hace por su cuenta, sin abrir Flutter.
 *
 *  · DatosHanzi: lee progreso.db y contenido.db (solo lectura) para saber
 *    cuánto llevas hoy, tu meta y el carácter del día.
 *  · Recordatorios + ReceptorRecordatorio + ReceptorArranque: un aviso al día
 *    a la hora elegida, con AlarmManager (no necesita servicios de Google, así
 *    que funciona en Huawei). Si ese día ya cumpliste tu meta, no avisa.
 *  · WidgetHanzi: widget de la pantalla de inicio (carácter del día, repasos
 *    pendientes y avance de hoy). El mismo carácter sale en la notificación
 *    diaria de la pantalla de bloqueo (CaracterDiario.kt).
 *  · ProveedorArchivos: entrega a otra app (WhatsApp, etc.) la imagen que se
 *    comparte, sin pedir permisos de almacenamiento.
 *
 * Batería: nada corre en segundo plano salvo una alarma inexacta al día y la
 * actualización del widget cada 3 horas (o al salir de la app).
 */

/** Lectura de las bases de la app desde Android. */
object DatosHanzi {

    data class Resumen(val hoy: Int, val meta: Int, val pendientes: Int)

    data class CaracterDia(val caracter: String, val pinyin: String, val significado: String)

    private fun abrir(context: Context, nombre: String): SQLiteDatabase? {
        val archivo = context.getDatabasePath(nombre)
        if (!archivo.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(archivo.path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (e: Exception) {
            null
        }
    }

    /** Medianoche de hoy (hora local), en segundos Unix. */
    private fun inicioDelDia(): Long {
        val c = Calendar.getInstance()
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis / 1000
    }

    /** Un número de una consulta; 0 si la tabla aún no existe (app sin actualizar). */
    private fun numero(db: SQLiteDatabase, sql: String, vararg args: String): Int = try {
        db.rawQuery(sql, arrayOf(*args)).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }
    } catch (e: Exception) {
        0
    }

    private fun ajuste(db: SQLiteDatabase, clave: String): String? = try {
        db.rawQuery("SELECT valor FROM ajustes WHERE clave = ?", arrayOf(clave))
            .use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    /**
     * ¿La app está en inglés? (Ajustes › Idioma: 'en', 'es' o 'auto' = el
     * idioma del teléfono: español si está en español, si no, inglés.)
     */
    fun ingles(context: Context): Boolean {
        val elegido = abrir(context, "progreso.db")?.use { ajuste(it, "idioma") }
        return when (elegido) {
            "en" -> true
            "es" -> false
            else -> java.util.Locale.getDefault().language != "es"
        }
    }

    /** Cuánto llevas hoy, tu meta y lo que toca repasar. */
    fun resumen(context: Context): Resumen? {
        val db = abrir(context, "progreso.db") ?: return null
        return db.use {
            val inicio = inicioDelDia().toString()
            val ahora = (System.currentTimeMillis() / 1000).toString()
            val hoy = numero(it, "SELECT count(*) FROM historial WHERE momento >= ?", inicio) +
                numero(it, "SELECT count(*) FROM ejercicios WHERE momento >= ?", inicio)
            val pendientes = numero(it, "SELECT count(*) FROM progreso WHERE proximo_repaso <= ?", ahora) +
                numero(it, "SELECT count(*) FROM progreso_palabras WHERE proximo_repaso <= ?", ahora)
            val meta = ajuste(it, "meta_diaria")?.toIntOrNull() ?: 20
            Resumen(hoy, meta, pendientes)
        }
    }

    /**
     * Carácter del día: uno de los que ya estudiaste (para repasarlo de un
     * vistazo) o, si llevas pocos, uno de HSK 1. Cambia cada día y es el
     * mismo todo el día.
     */
    fun caracterDelDia(context: Context): CaracterDia? {
        val estudiados: List<String> = abrir(context, "progreso.db")?.use { db ->
            try {
                db.rawQuery("SELECT caracter FROM progreso ORDER BY caracter", null).use { c ->
                    val lista = mutableListOf<String>()
                    while (c.moveToNext()) lista.add(c.getString(0))
                    lista
                }
            } catch (e: Exception) {
                emptyList()
            }
        } ?: emptyList()
        val contenido = abrir(context, "contenido.db") ?: return null
        return contenido.use { db ->
            val ahora = System.currentTimeMillis()
            val dia = (ahora + TimeZone.getDefault().getOffset(ahora)) / 86_400_000L
            val significado = if (ingles(context)) "significado_en" else "coalesce(significado_es, significado_en)"
            val consulta = "SELECT caracter, pinyin, $significado FROM caracteres"
            if (estudiados.size >= 10) {
                val elegido = estudiados[((dia * 7919L) % estudiados.size).toInt()]
                db.rawQuery("$consulta WHERE caracter = ?", arrayOf(elegido)).use { c ->
                    if (c.moveToFirst()) return CaracterDia(c.getString(0), c.getString(1), c.getString(2) ?: "")
                }
            }
            val total = numero(db, "SELECT count(*) FROM caracteres WHERE nivel_hsk = 1")
            if (total == 0) return null
            val desde = (dia * 7919L) % total
            db.rawQuery("$consulta WHERE nivel_hsk = 1 ORDER BY id LIMIT 1 OFFSET $desde", null).use { c ->
                if (c.moveToFirst()) CaracterDia(c.getString(0), c.getString(1), c.getString(2) ?: "") else null
            }
        }
    }
}

/** El aviso diario. La hora elegida se guarda aquí (para reprogramarlo sin Flutter). */
object Recordatorios {
    private const val PREFERENCIAS = "hanzi_dojo_habito"
    private const val CANAL = "recordatorio"
    private const val ID_AVISO = 7001

    private fun preferencias(context: Context) =
        context.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE)

    fun programar(context: Context, hora: Int, minuto: Int) {
        preferencias(context).edit()
            .putBoolean("activo", true)
            .putInt("hora", hora)
            .putInt("minuto", minuto)
            .apply()
        reprogramar(context)
    }

    fun cancelar(context: Context) {
        preferencias(context).edit().putBoolean("activo", false).apply()
        val alarmas = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmas.cancel(pendiente(context))
    }

    /** Pone la alarma para la próxima vez que toque (hoy o mañana). */
    fun reprogramar(context: Context) {
        val p = preferencias(context)
        if (!p.getBoolean("activo", false)) return
        val cuando = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.getInt("hora", 20))
            set(Calendar.MINUTE, p.getInt("minuto", 0))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 1000) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarmas = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Inexacta: el sistema la junta con otras para gastar menos batería
        // (puede llegar unos minutos tarde) y no requiere permisos especiales.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmas.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cuando.timeInMillis, pendiente(context))
        } else {
            alarmas.set(AlarmManager.RTC_WAKEUP, cuando.timeInMillis, pendiente(context))
        }
    }

    private fun pendiente(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, ReceptorRecordatorio::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    @Suppress("DEPRECATION")
    private fun constructor(context: Context): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, CANAL)
        else Notification.Builder(context)

    /** Muestra el aviso, salvo que ya hayas cumplido tu meta de hoy. */
    fun avisar(context: Context) {
        val r = DatosHanzi.resumen(context)
        if (r != null && r.hoy >= r.meta) return
        val avisos = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val en = DatosHanzi.ingles(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(
                CANAL,
                if (en) "Daily reminder" else "Recordatorio diario",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            canal.description = if (en) "One reminder a day to practice (only if you haven't reached your goal)"
            else "Un aviso al día para practicar (solo si aún no cumples tu meta)"
            avisos.createNotificationChannel(canal)
        }
        val texto = if (en) {
            when {
                r == null -> "A few minutes of practice today 🌸"
                r.pendientes > 0 -> "You have ${r.pendientes} reviews waiting. A few minutes is enough 🌸"
                r.hoy > 0 -> "${r.hoy} of ${r.meta} done today. Almost there! 🎯"
                else -> "Today's practice is waiting for you 🖌️"
            }
        } else {
            when {
                r == null -> "Unos minutos de práctica hoy 🌸"
                r.pendientes > 0 -> "Tienes ${r.pendientes} repasos esperando. Unos minutos bastan 🌸"
                r.hoy > 0 -> "Llevas ${r.hoy} de ${r.meta} hoy. ¡Ya casi! 🎯"
                else -> "Tu práctica de hoy te espera 🖌️"
            }
        }
        val abrir = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val aviso = constructor(context)
            .setSmallIcon(R.drawable.ic_notificacion)
            .setContentTitle("Meizi Hanzi · 梅字")
            .setContentText(texto)
            .setStyle(Notification.BigTextStyle().bigText(texto))
            .setContentIntent(abrir)
            .setAutoCancel(true)
            .build()
        try {
            avisos.notify(ID_AVISO, aviso)
        } catch (e: SecurityException) {
            // Sin permiso de notificaciones (Android 13+): no se avisa.
        }
    }
}

/** Llega la hora del recordatorio: avisa y deja programado el de mañana. */
class ReceptorRecordatorio : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Recordatorios.reprogramar(context)
        Recordatorios.avisar(context)
        WidgetHanzi.actualizar(context)
    }
}

/** Al reiniciar el teléfono (o actualizar la app) Android borra las alarmas. */
class ReceptorArranque : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Recordatorios.reprogramar(context)
        CaracterDiario.reprogramar(context)
    }
}

/** Widget de la pantalla de inicio. */
class WidgetHanzi : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val vista = vista(context)
        for (id in ids) manager.updateAppWidget(id, vista)
    }

    companion object {
        /** Redibuja los widgets que haya (si no hay ninguno, no hace nada). */
        fun actualizar(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, WidgetHanzi::class.java))
            if (ids.isEmpty()) return
            val vista = vista(context)
            for (id in ids) manager.updateAppWidget(id, vista)
        }

        private fun vista(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_hanzi)
            val en = DatosHanzi.ingles(context)
            v.setTextViewText(R.id.widget_titulo, if (en) "Character of the day" else "Carácter del día")
            val c = DatosHanzi.caracterDelDia(context)
            v.setTextViewText(R.id.widget_caracter, c?.caracter ?: "汉")
            v.setTextViewText(R.id.widget_pinyin, c?.pinyin ?: "hàn")
            v.setTextViewText(R.id.widget_significado, c?.significado ?: if (en) "Open the app to begin" else "Abre la app para empezar")
            val r = DatosHanzi.resumen(context)
            v.setTextViewText(
                R.id.widget_estado,
                when {
                    r == null -> "Meizi Hanzi"
                    en -> "${r.pendientes} reviews · ${minOf(r.hoy, 999)}/${r.meta} today"
                    else -> "${r.pendientes} repasos · ${minOf(r.hoy, 999)}/${r.meta} hoy"
                },
            )
            val abrir = PendingIntent.getActivity(
                context,
                1,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            v.setOnClickPendingIntent(R.id.widget_raiz, abrir)
            return v
        }
    }
}

/**
 * Entrega a otras apps los archivos de cache/compartir (la imagen de
 * progreso). Solo lectura y solo para quien recibió el permiso al compartir.
 */
class ProveedorArchivos : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun archivo(uri: Uri): File? {
        val nombre = uri.lastPathSegment ?: return null
        if (nombre.contains('/') || nombre.contains("..")) return null
        val contexto = context ?: return null
        val f = File(File(contexto.cacheDir, "compartir"), nombre)
        return if (f.exists()) f else null
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val f = archivo(uri) ?: throw FileNotFoundException(uri.toString())
        return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?,
    ): Cursor? {
        val f = archivo(uri) ?: return null
        val columnas = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columnas)
        cursor.addRow(
            columnas.map {
                when (it) {
                    OpenableColumns.DISPLAY_NAME -> f.name
                    OpenableColumns.SIZE -> f.length()
                    else -> null
                }
            },
        )
        return cursor
    }

    override fun getType(uri: Uri): String =
        if (uri.lastPathSegment?.endsWith(".png") == true) "image/png" else "application/octet-stream"

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?): Int = 0
}
