package com.abrakdabra.hanzidojo

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import java.util.Calendar

/*
 * Carácter del día en la pantalla de bloqueo (Ajustes › Tu hábito).
 *
 * Una notificación al día, a la hora elegida, con el carácter en grande, su
 * pinyin y su significado: el mismo carácter del widget (DatosHanzi.
 * caracterDelDia: uno de los que ya estudiaste, o de HSK 1 si llevas pocos).
 *
 *  · Silenciosa: sin sonido ni vibración, solo para verla de un vistazo.
 *  · Visible completa en la pantalla de bloqueo (VISIBILITY_PUBLIC).
 *  · Cada una reemplaza a la del día anterior (mismo id) y desaparece sola
 *    al día siguiente.
 *
 * Igual que el recordatorio: una alarma inexacta al día con AlarmManager (sin
 * servicios de Google, funciona en Huawei) y se vuelve a programar al
 * reiniciar el teléfono (ReceptorArranque).
 */
object CaracterDiario {
    private const val PREFERENCIAS = "hanzi_dojo_habito"
    private const val CANAL = "caracter_dia"
    private const val ID_AVISO = 7002
    private const val CODIGO_ALARMA = 2

    private fun preferencias(context: Context) =
        context.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE)

    fun programar(context: Context, hora: Int, minuto: Int) {
        preferencias(context).edit()
            .putBoolean("caracter_activo", true)
            .putInt("caracter_hora", hora)
            .putInt("caracter_minuto", minuto)
            .apply()
        reprogramar(context)
    }

    fun cancelar(context: Context) {
        preferencias(context).edit().putBoolean("caracter_activo", false).apply()
        val alarmas = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmas.cancel(pendiente(context))
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ID_AVISO)
    }

    /** Pone la alarma para la próxima vez que toque (hoy o mañana). */
    fun reprogramar(context: Context) {
        val p = preferencias(context)
        if (!p.getBoolean("caracter_activo", false)) return
        val cuando = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.getInt("caracter_hora", 8))
            set(Calendar.MINUTE, p.getInt("caracter_minuto", 0))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 1000) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarmas = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmas.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cuando.timeInMillis, pendiente(context))
        } else {
            alarmas.set(AlarmManager.RTC_WAKEUP, cuando.timeInMillis, pendiente(context))
        }
    }

    private fun pendiente(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        CODIGO_ALARMA,
        Intent(context, ReceptorCaracterDia::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    @Suppress("DEPRECATION")
    private fun constructor(context: Context): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, CANAL)
        else Notification.Builder(context)

    /** Muestra (o reemplaza) la notificación con el carácter de hoy. */
    fun mostrar(context: Context) {
        val c = DatosHanzi.caracterDelDia(context) ?: return
        val avisos = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val en = DatosHanzi.ingles(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(
                CANAL,
                if (en) "Character of the day" else "Carácter del día",
                // DEFAULT y no LOW: algunos teléfonos esconden de la pantalla
                // de bloqueo las notificaciones "silenciosas" (LOW). El canal
                // igual no suena ni vibra.
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            canal.description = if (en) "A character a day to review at a glance, also on the lock screen"
            else "Un carácter al día para repasar de un vistazo, también en la pantalla de bloqueo"
            canal.setSound(null, null)
            canal.enableVibration(false)
            canal.setShowBadge(false)
            canal.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            avisos.createNotificationChannel(canal)
        }
        val titulo = if (en) "Character of the day" else "Carácter del día"
        val abrir = PendingIntent.getActivity(
            context,
            CODIGO_ALARMA,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val aviso = constructor(context)
            .setSmallIcon(R.drawable.ic_notificacion)
            // Lo que se ve donde el sistema no muestra la vista propia.
            .setContentTitle("${c.caracter} · ${c.pinyin}")
            .setContentText(c.significado)
            .setSubText(titulo)
            .setContentIntent(abrir)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_RECOMMENDATION)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) silenciar(aviso)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            aviso.setTimeoutAfter(26L * 60 * 60 * 1000) // se va solo al día siguiente
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // El carácter en grande (como en el widget), con los colores del
            // tema del sistema (claro u oscuro).
            aviso
                .setStyle(Notification.DecoratedCustomViewStyle())
                .setCustomContentView(vista(context, R.layout.notificacion_caracter, c))
                .setCustomBigContentView(vista(context, R.layout.notificacion_caracter_grande, c))
        } else {
            aviso.setStyle(Notification.BigTextStyle().bigText(c.significado))
        }
        try {
            avisos.notify(ID_AVISO, aviso.build())
        } catch (e: SecurityException) {
            // Sin permiso de notificaciones (Android 13+).
        }
    }

    /** Antes de Android 8 el sonido se quita en cada notificación (no hay canales). */
    @Suppress("DEPRECATION")
    private fun silenciar(aviso: Notification.Builder) {
        aviso.setPriority(Notification.PRIORITY_DEFAULT).setSound(null).setVibrate(null)
    }

    private fun vista(context: Context, diseno: Int, c: DatosHanzi.CaracterDia): RemoteViews {
        val v = RemoteViews(context.packageName, diseno)
        v.setTextViewText(R.id.notif_caracter, c.caracter)
        v.setTextViewText(R.id.notif_pinyin, c.pinyin)
        v.setTextViewText(R.id.notif_significado, c.significado)
        return v
    }
}

/** Llega la hora: muestra el carácter de hoy y deja programado el de mañana. */
class ReceptorCaracterDia : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CaracterDiario.reprogramar(context)
        CaracterDiario.mostrar(context)
    }
}
