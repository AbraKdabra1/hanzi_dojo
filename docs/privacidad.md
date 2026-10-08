# Aviso de privacidad de Meizi Hanzi

*Vigente desde octubre de 2026.*

Meizi Hanzi es una app gratuita y de código abierto (GPL-3.0) para aprender a
escribir caracteres chinos. **No recopila, no envía y no vende ningún dato.**

## Qué guarda y dónde

Todo se guarda **solo en tu teléfono**, en la carpeta privada de la app:

- tu avance (qué caracteres y palabras estudiaste, cuándo te toca repasarlos);
- tu historial de práctica (para las estadísticas, la racha y los logros);
- tus ajustes y los libros que agregues;
- un registro de errores de la app (los últimos 50), para que puedas copiarlo
  si quieres reportar un problema.

Nadie más tiene acceso a esa información, ni siquiera quien hizo la app.

## Internet

La app **funciona sin internet** y no usa cuentas, anuncios, analítica ni
servicios de terceros. Las grabaciones de pronunciación y todo el contenido
vienen dentro de la app.

Tiene permiso de internet **solo para el aviso de versión nueva**, y solo si
tú lo aceptas (se pregunta una vez; se cambia en Ajustes → Versiones nuevas).
Si lo aceptas, una vez al día pide a GitHub la lista pública de versiones de
la app, la misma página que cualquiera puede abrir, para saber si hay una
más nueva. Esa consulta no lleva nada tuyo: ni tu progreso, ni tus ajustes,
ni un identificador. Como cualquier conexión, GitHub ve la dirección IP del
teléfono. Las versiones de tienda (Google Play, F-Droid) no hacen esta
consulta: ahí la tienda se encarga de actualizar.

«Enviar mi opinión» arma en el teléfono un resumen de cómo usas la app
(días de uso, repasos, secciones, trazos que reportaste como mal marcados,
errores de la app). Lo ves completo y solo sale si tú lo compartes, con la app
que tú elijas.

Cuando tocas «Reportar un problema», la app abre tu navegador con un
formulario de GitHub ya lleno; tú decides si lo envías y ves exactamente qué
contiene.

«Apoyar el proyecto» abre en tu navegador la página de PayPal del autor. La
app no envía nada: si donas o no, y cuánto, solo lo sabe PayPal.

## Permisos

| Permiso | Para qué |
|---|---|
| Notificaciones | Solo si activas el recordatorio diario o el carácter del día. |
| Ejecutar al iniciar el teléfono | Volver a programar el recordatorio después de reiniciar. |
| Internet | Solo el aviso de versión nueva, si lo aceptas (ver arriba). |

Para exportar tu progreso, abrir un libro o guardar una imagen, la app usa el
selector de archivos del sistema: solo accede al archivo que tú elijas.

## Compartir

La tarjeta de progreso solo sale del teléfono si tú la compartes, con la app
que tú elijas.

## Borrar tus datos

Desinstalar la app borra todo. Si quieres conservarlo, antes usa
Ajustes → Tus datos → Exportar progreso.

## Versión web

La versión que se abre en el navegador ([web.md](web.md)) guarda lo mismo,
pero dentro del navegador (IndexedDB) en lugar de la carpeta de la app; borrar
los datos del sitio, o quitar el ícono de la pantalla de inicio en iPhone, lo
borra. Como es una página web, la sirve GitHub Pages, que recibe la dirección
IP de quien la abre, y el motor de Flutter descarga de Google Fonts su
tipografía base y las letras poco comunes que la app no trae. Tu progreso
nunca sale del navegador.

## Contacto

Dudas o sugerencias: <https://github.com/AbraKdabra1/hanzi_dojo/issues>
