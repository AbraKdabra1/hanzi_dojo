// Arranque de la versión web. flutter build web cambia las dos líneas de
// abajo por el cargador de Flutter y la configuración de la compilación.
// Se usa este archivo propio en lugar del de Flutter para no registrar su
// service worker (la app trae el suyo, sw_hanzi.js) y para quitar la
// pantalla de carga de index.html cuando la app ya se dibujó.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (motor) {
    const app = await motor.initializeEngine();
    await app.runApp();
    const arranque = document.getElementById('arranque');
    if (arranque) {
      arranque.classList.add('listo');
      setTimeout(function () { arranque.remove(); }, 400);
    }
  },
});
