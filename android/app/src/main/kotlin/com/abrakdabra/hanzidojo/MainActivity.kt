package com.abrakdabra.hanzidojo

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

/**
 * Actividad principal de Android.
 *
 * Flutter dibuja toda la interfaz dentro de esta actividad; aquí solo hay un
 * ajuste propio: pedirle a Android el modo de pantalla con la tasa de
 * refresco más alta disponible (por ejemplo 120 Hz en el Huawei Pura 70).
 *
 * ¿Por qué? Varios fabricantes dejan a las apps en 60 Hz a menos que la app
 * pida otra cosa. Flutter dibuja al ritmo que marque la pantalla, así que al
 * pedir el modo más rápido la animación se adapta sola a cada teléfono:
 * 60, 90, 120 o 144 Hz.
 *
 * En pantallas LTPO el sistema sigue bajando la frecuencia cuando nada se
 * mueve, así que esto no gasta batería de más.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pedirTasaDeRefrescoMaxima()
    }

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
