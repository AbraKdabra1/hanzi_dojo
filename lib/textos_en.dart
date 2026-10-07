// ─────────────────────────────────────────────────────────────────────────────
// textos_en.dart — La interfaz en inglés
//
// Clave: el texto en español tal como está en el código (dentro de tr()).
// Valor: el mismo texto en inglés, con los mismos {0}, {1}…
// test/idioma_test.dart revisa que ningún texto de tr() se quede sin traducir.
// ─────────────────────────────────────────────────────────────────────────────

const textosEn = <String, String>{
  'El archivo es demasiado grande (máximo 20 MB).':
      'The file is too large (20 MB maximum).',
  'Los PDF todavía no se pueden abrir. Por ahora: TXT o EPUB.':
      'PDFs can\'t be opened yet. For now: TXT or EPUB.',
  'Mi libro':
      'My book',
  'No encontré texto en chino en este archivo.':
      'I couldn\'t find any Chinese text in this file.',
  'Parte {0}':
      'Part {0}',
  'Texto':
      'Text',
  'El archivo está dañado o no es un EPUB.':
      'The file is damaged or isn\'t an EPUB.',
  'Este archivo no es un EPUB.':
      'This file isn\'t an EPUB.',
  'Este EPUB tiene protección (DRM) y no se puede leer.':
      'This EPUB is DRM-protected and can\'t be read.',
  'Capítulo {0}':
      'Chapter {0}',
  'Fuera de HSK':
      'Not in HSK',
  'Texto que pegaste.':
      'Text you pasted.',
  'Agregado por ti desde «{0}».':
      'Added by you from “{0}”.',
  'Tonos (sílabas)':
      'Tones (syllables)',
  'Tonos (palabras)':
      'Tones (words)',
  'Escucha':
      'Listening',
  'Pinyin':
      'Pinyin',
  'Vocabulario':
      'Vocabulary',
  'alto y plano':
      'high and level',
  'sube':
      'rising',
  'baja y sube':
      'dipping',
  'baja':
      'falling',
  'neutro':
      'neutral',
  'Familia del radical {0}':
      'Radical {0} family',
  'Radicales Kangxi':
      'Kangxi radicals',
  'Práctica libre':
      'Free practice',
  'El archivo es demasiado grande para ser un respaldo.':
      'The file is too large to be a backup.',
  'Este archivo no es un respaldo de Hanzi Dojo.':
      'This file isn\'t a Hanzi Dojo backup.',
  'El respaldo está dañado (versión desconocida).':
      'The backup is damaged (unknown version).',
  'Este respaldo viene de una versión más nueva de Hanzi Dojo. Actualiza la app para importarlo.':
      'This backup comes from a newer version of Hanzi Dojo. Update the app to import it.',
  'El respaldo está dañado (ajustes).':
      'The backup is damaged (settings).',
  'El respaldo está dañado ({0}).':
      'The backup is damaged ({0}).',
  'La primera vez se descarga el diccionario (15 MB). Después funciona sin internet.':
      'The first time, the dictionary is downloaded (15 MB). After that it works offline.',
  'No se pudo abrir la base de datos.\n\n{0}':
      'The database couldn\'t be opened.\n\n{0}',
  'No se pudo {0}: {1}':
      'Couldn\'t {0}: {1}',
  'exportar':
      'export',
  'Respaldo guardado: {0}':
      'Backup saved: {0}',
  'importar':
      'import',
  '\nCreado: {0}':
      '\nCreated: {0}',
  '¿Importar este respaldo?':
      'Import this backup?',
  '{0}{1}\nTrae {2} caracteres y {3} repasos.\n\nReemplazará tu progreso actual ({4} caracteres). Antes se guarda una copia, por si quieres deshacerlo.':
      '{0}{1}\nIt has {2} characters and {3} reviews.\n\nIt will replace your current progress ({4} characters). A copy is saved first, in case you want to undo it.',
  'Importar':
      'Import',
  'Progreso importado ✓':
      'Progress imported ✓',
  'deshacer la importación':
      'undo the import',
  '¿Deshacer la importación?':
      'Undo the import?',
  'Tu progreso volverá a como estaba antes de la última importación.':
      'Your progress will go back to how it was before the last import.',
  'Deshacer':
      'Undo',
  'Listo: volviste a tu progreso anterior.':
      'Done: you\'re back to your previous progress.',
  'Sin permiso de notificaciones no puedo recordarte. Actívalo en los ajustes del teléfono.':
      'Without notification permission I can\'t remind you. Turn it on in your phone\'s settings.',
  '¿A qué hora te recuerdo?':
      'What time should I remind you?',
  'Ajustes':
      'Settings',
  'Apariencia':
      'Appearance',
  'El modo oscuro «tinta» descansa la vista de noche y, en pantallas OLED, gasta bastante menos batería.':
      'The dark “ink” mode is easier on the eyes at night and, on OLED screens, uses much less battery.',
  'Automática':
      'Automatic',
  'Clara':
      'Light',
  'Oscura':
      'Dark',
  'Los significados y ejemplos también cambian de idioma.':
      'Meanings and examples change language too.',
  'Automático':
      'Automatic',
  'Tu hábito':
      'Your habit',
  'Meta diaria: cuántos repasos y ejercicios quieres hacer al día. La ves como un anillo en el inicio.':
      'Daily goal: how many reviews and exercises you want to do each day. It shows as a ring on the home screen.',
  'Recordatorio diario':
      'Daily reminder',
  'Un aviso al día, solo si aún no cumples tu meta.':
      'One reminder a day, only if you haven\'t reached your goal yet.',
  'Todos los días a las {0} (si aún no cumples tu meta).':
      'Every day at {0} (if you haven\'t reached your goal yet).',
  'Cambiar hora ({0})':
      'Change time ({0})',
  'Caracteres nuevos por día':
      'New characters per day',
  'Al llegar a este número, la sesión te ofrece parar o seguir. Entre 10 y 20 es un buen ritmo para no acumular repasos.':
      'When you reach this number, the session offers to stop or continue. 10 to 20 is a good pace to keep reviews from piling up.',
  'Práctica con audio':
      'Audio practice',
  'Voz lenta':
      'Slow voice',
  'Todas las grabaciones suenan un poco más despacio. Sin activarlo, mantén presionado un botón de sonido para oírlo lento.':
      'All recordings play a little slower. Without it, press and hold any sound button to hear it slowly.',
  'Palabras nuevas por día':
      'New words per day',
  'Acomodar mis trazos a la caligrafía':
      'Snap my strokes to calligraphy',
  'Cada trazo correcto se transforma, con un rebote suave, en la forma exacta del pincel. Apágalo si prefieres ver tu trazo tal cual.':
      'Each correct stroke turns, with a gentle bounce, into the exact brush shape. Turn it off if you\'d rather see your stroke as drawn.',
  '120 Hz solo cuando hace falta y cuánto gasta la app':
      '120 Hz only when needed, and how much the app uses',
  'Tus datos':
      'Your data',
  'Tu progreso vive solo en este teléfono. Exporta un respaldo para no perderlo si cambias de teléfono o lo reinicias.':
      'Your progress lives only on this phone. Export a backup so you don\'t lose it if you change or reset your phone.',
  'Tu progreso vive solo en este navegador. Exporta un respaldo para no perderlo si borras los datos del navegador o cambias de equipo.':
      'Your progress lives only in this browser. Export a backup so you don\'t lose it if you clear the browser\'s data or switch devices.',
  'Exportar progreso':
      'Export progress',
  'Guarda un archivo .hanzidojo donde elijas':
      'Save a .hanzidojo file wherever you like',
  'Importar progreso':
      'Import progress',
  'Reemplaza tu progreso por el de un respaldo':
      'Replace your progress with a backup',
  'Deshacer la última importación':
      'Undo the last import',
  'Vuelve al progreso que tenías antes':
      'Go back to the progress you had before',
  'Reportar un problema o sugerir algo':
      'Report a problem or suggest something',
  'Batería y fluidez':
      'Battery and smoothness',
  'Fluidez de la pantalla':
      'Screen smoothness',
  'Una pantalla a 120 Hz se ve más fluida, pero gasta más batería aunque nada se mueva.':
      'A 120 Hz screen looks smoother, but uses more battery even when nothing moves.',
  'Automática (recomendada)':
      'Automatic (recommended)',
  '120 Hz solo mientras tocas o algo se desplaza; al quedarse quieta la pantalla, el teléfono baja la tasa.':
      '120 Hz only while you touch or something scrolls; when the screen is still, the phone lowers the rate.',
  'Siempre al máximo':
      'Always at maximum',
  '120 Hz todo el tiempo. Gasta más.':
      '120 Hz all the time. Uses more battery.',
  '🔋 Tu teléfono tiene activado el ahorro de batería: la app no pide 120 Hz y la rama del inicio no se mueve.':
      '🔋 Your phone\'s battery saver is on: the app doesn\'t ask for 120 Hz and the branch on the home screen stays still.',
  'Qué hace la app para ahorrar':
      'What the app does to save battery',
  '• 120 Hz solo cuando hace falta (modo automático).\n• La rama del inicio se anima a 30 cuadros por segundo, 30 segundos, y se apaga sola.\n• Nada se anima ni corre con otra pantalla encima o con la app en segundo plano.\n• Al escribir, la cuadrícula y la silueta se dibujan una sola vez.\n• El sonido suelta el reproductor al terminar.':
      '• 120 Hz only when needed (automatic mode).\n• The home screen branch animates at 30 frames per second for 30 seconds, then stops on its own.\n• Nothing animates or runs while another screen is on top or the app is in the background.\n• When writing, the grid and the outline are drawn only once.\n• Sound releases the player when it finishes.',
  'Batería':
      'Battery',
  'Corriente':
      'Current',
  '{0} mA':
      '{0} mA',
  'A este ritmo baja':
      'At this rate it drops',
  '{0} % por hora':
      '{0} % per hour',
  'Temperatura':
      'Temperature',
  'Pantalla':
      'Screen',
  '{0} Hz':
      '{0} Hz',
  'Consumo ahora':
      'Usage now',
  'No se pudo leer la batería en este teléfono.':
      'The battery couldn\'t be read on this phone.',
  'Desconecta el cargador para ver cuánto gasta.':
      'Unplug the charger to see how much it uses.',
  'Tu teléfono no informa la corriente; queda el porcentaje.':
      'Your phone doesn\'t report the current; only the percentage is available.',
  'Incluye todo el teléfono (pantalla, señal, otras apps), no solo Hanzi Dojo.':
      'This includes the whole phone (screen, signal, other apps), not just Hanzi Dojo.',
  'Medir mi consumo':
      'Measure my usage',
  'Enciéndelo, desconecta el cargador y usa la app como siempre (por ejemplo, una práctica de 10 minutos). Al volver aquí verás el promedio. Lee la batería cada 15 s solo con la app abierta.':
      'Turn it on, unplug the charger and use the app as usual (for example, a 10-minute practice). When you come back here you\'ll see the average. It reads the battery every 15 s, only while the app is open.',
  'Midiendo desde las {0}. Sigue usando la app y vuelve aquí.':
      'Measuring since {0}. Keep using the app and come back here.',
  'Tiempo medido':
      'Time measured',
  '{0} min':
      '{0} min',
  'Corriente promedio':
      'Average current',
  'Equivale a bajar':
      'Equivalent to dropping',
  'Bajó la batería':
      'Battery dropped',
  '{0} puntos':
      '{0} points',
  '⚠️ El teléfono estuvo cargando: esta medición no sirve. Reiníciala.':
      '⚠️ The phone was charging: this measurement isn\'t valid. Restart it.',
  'Empezar a medir':
      'Start measuring',
  'Reiniciar':
      'Restart',
  'Terminar':
      'Finish',
  'Agregar un libro':
      'Add a book',
  'Abrir un archivo':
      'Open a file',
  'TXT (UTF-8 o GBK) o EPUB sin protección':
      'TXT (UTF-8 or GBK) or DRM-free EPUB',
  'Pegar un texto':
      'Paste a text',
  'Un artículo, un cuento, la letra de una canción…':
      'An article, a story, song lyrics…',
  'Tus libros se quedan solo en este teléfono. La app calcula el pinyin y estima su nivel HSK.':
      'Your books stay only on this phone. The app works out the pinyin and estimates the HSK level.',
  'No se pudo abrir el selector de archivos: {0}':
      'The file picker couldn\'t be opened: {0}',
  'Título (opcional)':
      'Title (optional)',
  'Texto en chino':
      'Chinese text',
  'Cancelar':
      'Cancel',
  'Agregar':
      'Add',
  'Preparando tu libro…':
      'Preparing your book…',
  'más difícil que HSK 7-9':
      'harder than HSK 7-9',
  'nivel estimado {0}':
      'estimated level {0}',
  'Agregado: {0} · {1} capítulos · {2}':
      'Added: {0} · {1} chapters · {2}',
  'No se pudo agregar el libro: {0}':
      'The book couldn\'t be added: {0}',
  '¿Borrar este libro?':
      'Delete this book?',
  '«{0}» se borrará del teléfono, con lo que llevas leído. Tu archivo original no se toca.':
      '“{0}” will be deleted from the phone, along with your reading progress. Your original file isn\'t touched.',
  'Borrar':
      'Delete',
  'Leer':
      'Read',
  'Libros graduados por nivel HSK':
      'Graded books by HSK level',
  'Toca cualquier carácter para ver su significado y practicarlo. Los nombres propios van subrayados.':
      'Tap any character to see its meaning and practice it. Proper names are underlined.',
  'MIS LIBROS':
      'MY BOOKS',
  'Agrega tus propios textos en chino: archivos TXT o EPUB sin protección, o un texto que pegues. Se quedan solo en tu teléfono.':
      'Add your own Chinese texts: TXT files, DRM-free EPUBs, or text you paste. They stay only on your phone.',
  ' · más difícil que HSK 7-9':
      ' · harder than HSK 7-9',
  ' · {0} aprox.':
      ' · about {0}',
  'Opciones':
      'Options',
  'No se pudo preparar la imagen: {0}':
      'The image couldn\'t be prepared: {0}',
  'Aprendo chino con Hanzi Dojo · 汉字道场':
      'I\'m learning Chinese with Hanzi Dojo · 汉字道场',
  'No se pudo abrir el menú para compartir.':
      'The share menu couldn\'t be opened.',
  'Imagen guardada: {0}':
      'Image saved: {0}',
  'Guardar':
      'Save',
  'Compartir':
      'Share',
  'Logro desbloqueado':
      'Achievement unlocked',
  'día seguido practicando':
      'day in a row practicing',
  'días seguidos practicando':
      'days in a row practicing',
  '{0} de {1} de {2}':
      '{1} {0}, {2}',
  'Aprende a escribir chino · gratis y de código abierto':
      'Learn to write Chinese · free and open source',
  'Código de Hanzi Dojo':
      'Hanzi Dojo code',
  'Software libre: puedes usarlo, estudiarlo, modificarlo y compartirlo. Las versiones modificadas que se distribuyan deben seguir siendo libres y publicar su código. Código fuente: github.com/AbraKdabra1/hanzi_dojo.':
      'Free software: you can use, study, modify and share it. Modified versions that are distributed must remain free and publish their code. Source code: github.com/AbraKdabra1/hanzi_dojo.',
  'Niveles HSK 3.0':
      'HSK 3.0 levels',
  'Lista oficial de caracteres del estándar GF 0025-2021 (Ministerio de Educación de China), tomada de github.com/ivankra/hsk30.':
      'Official character list of the GF 0025-2021 standard (Ministry of Education of China), taken from github.com/ivankra/hsk30.',
  'Trazos y orden de trazos':
      'Strokes and stroke order',
  'Make Me a Hanzi (github.com/skishore/makemeahanzi), derivado de las fuentes Arphic PL KaitiM GB y UKai.':
      'Make Me a Hanzi (github.com/skishore/makemeahanzi), derived from the Arphic PL KaitiM GB and UKai fonts.',
  'Arphic Public License':
      'Arphic Public License',
  'Lecturas':
      'Readings',
  'Lista HSK 3.0 y Make Me a Hanzi (dictionary.txt, basado en Unihan y CJKlib).':
      'HSK 3.0 list and Make Me a Hanzi (dictionary.txt, based on Unihan and CJKlib).',
  'Significados':
      'Meanings',
  'CC-CEDICT (cc-cedict.org). Los significados en español son una traducción de esos datos, generada con ayuda de IA y revisable.':
      'CC-CEDICT (cc-cedict.org). The Spanish meanings are a translation of that data, made with AI help and open to review.',
  'Radicales':
      'Radicals',
  'Unihan (Unicode), campo kRSUnicode: radical Kangxi de cada carácter.':
      'Unihan (Unicode), kRSUnicode field: the Kangxi radical of each character.',
  'Unicode License v3':
      'Unicode License v3',
  'Oraciones de ejemplo':
      'Example sentences',
  'Tatoeba (tatoeba.org), vía github.com/krmanik/chinese-example-sentences. Traducción al español generada con ayuda de IA a partir del chino.':
      'Tatoeba (tatoeba.org), via github.com/krmanik/chinese-example-sentences. English translations from Tatoeba; Spanish translations made from the Chinese with AI help.',
  'Libros de «Leer»':
      '“Read” books',
  'Historias clásicas chinas de dominio público, contadas de nuevo para Hanzi Dojo (HSK 1 a 5). Textos originales del Zengguang Xianwen y poemas Tang tomados de github.com/chinese-poetry/chinese-poetry. Traducciones al español escritas para la app.':
      'Public-domain classic Chinese stories, retold for Hanzi Dojo (HSK 1 to 5). Original texts of the Zengguang Xianwen and Tang poems taken from github.com/chinese-poetry/chinese-poetry. Spanish translations written for the app.',
  'MIT (textos clásicos)':
      'MIT (classic texts)',
  'Tradicional → simplificado':
      'Traditional → simplified',
  'OpenCC (github.com/BYVoid/OpenCC): para consultar los caracteres de libros propios escritos en caracteres tradicionales.':
      'OpenCC (github.com/BYVoid/OpenCC): to look up characters in your own books written in traditional characters.',
  'Apache 2.0':
      'Apache 2.0',
  'Pronunciación (audio)':
      'Pronunciation (audio)',
  'Grabaciones de hablantes nativos del proyecto audio-cmn (github.com/hugolpz/audio-cmn): sílabas con la voz de Chen Wang y palabras HSK con la voz de Yue Tan (Shtooka). Recortadas, con volumen igualado y convertidas a Opus para la app.':
      'Native-speaker recordings from the audio-cmn project (github.com/hugolpz/audio-cmn): syllables voiced by Chen Wang and HSK words voiced by Yue Tan (Shtooka). Trimmed, volume-matched and converted to Opus for the app.',
  'Tipografía':
      'Typeface',
  'Noto Sans SC (Google), recortada a los caracteres de la app.':
      'Noto Sans SC (Google), subset to the app\'s characters.',
  'SIL Open Font License 1.1':
      'SIL Open Font License 1.1',
  'Rama de ciruelo (梅花)':
      'Plum branch (梅花)',
  'Ilustración original al estilo de la pintura china a tinta, dibujada por código para Hanzi Dojo (lib/painters/rama_ciruelo.dart).':
      'Original illustration in the style of Chinese ink painting, drawn in code for Hanzi Dojo (lib/painters/rama_ciruelo.dart).',
  'Créditos y licencias':
      'Credits and licenses',
  'Código: GPL-3.0 o posterior.\nDatos: CC-CEDICT, Make Me a Hanzi, Unihan, HSK 3.0, Tatoeba.':
      'Code: GPL-3.0 or later.\nData: CC-CEDICT, Make Me a Hanzi, Unihan, HSK 3.0, Tatoeba.',
  'Ver licencias completas':
      'View full licenses',
  'Informe copiado. Pégalo en tu reporte.':
      'Log copied. Paste it into your report.',
  '¿Borrar el informe?':
      'Clear the log?',
  'Se borrarán todos los errores guardados.':
      'All saved errors will be deleted.',
  'Informe de errores':
      'Error log',
  'Reportar un problema':
      'Report a problem',
  'Copiar informe':
      'Copy log',
  'Si algo falla, la app guarda aquí los detalles. Nada se envía solo: si quieres reportarlo, cópialo y pégalo en tu reporte.':
      'If something fails, the app saves the details here. Nothing is sent automatically: if you want to report it, copy it and paste it into your report.',
  'Sin errores registrados':
      'No errors logged',
  'Todo ha funcionado bien hasta ahora.':
      'Everything has worked fine so far.',
  'Carácter':
      'Character',
  'Significado':
      'Meaning',
  'No encontré grabaciones para este nivel':
      'I couldn\'t find recordings for this level',
  '¿Qué significa?':
      'What does it mean?',
  '¿Cuál escuchaste?':
      'Which one did you hear?',
  'Mi progreso':
      'My progress',
  'caracteres estudiados':
      'characters studied',
  'repasos para hoy':
      'reviews for today',
  'día seguido':
      'day in a row',
  'días seguidos':
      'days in a row',
  'racha más larga':
      'longest streak',
  'minutos esta semana':
      'minutes this week',
  'Cuando practiques, aquí verás tu calendario, tu racha y los caracteres y trazos que más te cuestan.':
      'Once you practice, you\'ll see your calendar, your streak and the characters and strokes you find hardest here.',
  'Tu calendario':
      'Your calendar',
  'Últimos 7 días':
      'Last 7 days',
  'Precisión (últimos 30 días)':
      'Accuracy (last 30 days)',
  'Los que más te cuestan':
      'The ones you find hardest',
  'Los trazos que más fallas':
      'The strokes you miss most',
  'Práctica con audio (últimos 30 días)':
      'Audio practice (last 30 days)',
  '{0} % de {1}':
      '{0} % of {1}',
  'Tonos que confundes':
      'Tones you mix up',
  'Oyes el {0}.º y eliges el {1}.º ({2} veces)':
      'You hear tone {0} and choose tone {1} ({2} times)',
  '{0} · {1} · {2} min':
      '{0} · {1} · {2} min',
  '1 repaso':
      '1 review',
  '{0} repasos':
      '{0} reviews',
  'Menos ':
      'Less ',
  '  Más':
      '  More',
  '{0} · {1} repasos · {2} min':
      '{0} · {1} reviews · {2} min',
  'Hoy aún no practicas.':
      'You haven\'t practiced today yet.',
  'Hoy: {0} repasos en {1} min.':
      'Today: {0} reviews in {1} min.',
  '{0} de tus repasos sin ningún trazo fallado':
      '{0} of your reviews with no missed strokes',
  'Novato: {0}':
      'Beginner: {0}',
  'Experto: {0}':
      'Expert: {0}',
  '{0} trazos fallados en promedio · {1}':
      '{0} missed strokes on average · {1}',
  '{0} · trazo {1}{2}':
      '{0} · stroke {1}{2}',
  ' de {0}':
      ' of {0}',
  'Fallado {0} veces{1}':
      'Missed {0} times{1}',
  ' ({0} al revés)':
      ' ({0} backwards)',
  '🐣 Novato':
      '🐣 Beginner',
  '🥋 Experto':
      '🥋 Expert',
  'Reportar un error en este carácter':
      'Report an error in this character',
  'Carácter {0} ({1}) · {2}':
      'Character {0} ({1}) · {2}',
  'Reiniciar trazos':
      'Clear strokes',
  'Ejemplos':
      'Examples',
  'Radical {0} {1}':
      'Radical {0} {1}',
  '✍ escritura oficial':
      '✍ official writing list',
  '· {0} trazos':
      '· {0} strokes',
  'Escribe el carácter trazo por trazo':
      'Write the character stroke by stroke',
  'Sin errores ✨':
      'No mistakes ✨',
  '1 error de trazo':
      '1 stroke mistake',
  '{0} errores de trazo':
      '{0} stroke mistakes',
  'Nuevos: {0} · Repasados: {1}':
      'New: {0} · Reviewed: {1}',
  'Volver':
      'Back',
  'Cumpliste tu meta de caracteres nuevos por hoy':
      'You reached your new-character goal for today',
  '{0}\n\nPuedes seguir con más nuevos o volver mañana para tus repasos.':
      '{0}\n\nYou can keep going with more new ones or come back tomorrow for your reviews.',
  'Estudiar más':
      'Study more',
  'Práctica terminada':
      'Practice finished',
  'No hay nada pendiente aquí':
      'Nothing pending here',
  '{0}\n\nTerminaste los nuevos y los repasos de este grupo por ahora.':
      '{0}\n\nYou\'ve finished the new ones and the reviews in this group for now.',
  'Aún no hay ejemplos para este carácter.':
      'No examples for this character yet.',
  'EN  {0}':
      'ES  {0}',
  'Radical {0}':
      'Radical {0}',
  '1 trazo':
      '1 stroke',
  '{0} trazos':
      '{0} strokes',
  'caracteres HSK de la familia que ya estudiaste':
      'HSK characters in this family you\'ve studied',
  'Practicar radical':
      'Practice radical',
  'Estudiar familia':
      'Study family',
  'Ningún carácter HSK usa este radical.':
      'No HSK character uses this radical.',
  'Mostrar caracteres fuera de HSK ({0})':
      'Show characters outside HSK ({0})',
  'Poco comunes; útiles para leer, no para el examen':
      'Uncommon; useful for reading, not for the exam',
  'El viaje de mil millas comienza con un solo paso.':
      'A journey of a thousand miles begins with a single step.',
  'Aprender es un tesoro que seguirá a su dueño a todas partes.':
      'Learning is a treasure that will follow its owner everywhere.',
  'No temas ir despacio, teme solo a detenerte.':
      'Do not fear going slowly; fear only standing still.',
  'Con suficiente constancia, una barra de hierro se vuelve aguja.':
      'With enough persistence, an iron rod can be ground into a needle.',
  '🛡️ Tu protector de racha cubrió el día que no practicaste. Hay uno por semana.':
      '🛡️ Your streak shield covered the day you didn\'t practice. You get one per week.',
  '🛡️ Tus protectores de racha cubrieron {0} días.':
      '🛡️ Your streak shields covered {0} days.',
  '🎯 ¡Meta del día cumplida! {0} de {1}':
      '🎯 Daily goal reached! {0} of {1}',
  'Ajustes y créditos':
      'Settings and credits',
  'Practicar':
      'Practice',
  'Ver mis estadísticas':
      'See my statistics',
  'Hoy llevas {0} de {1}. {2} repasos pendientes. Racha de {3} días.':
      'Today: {0} of {1}. {2} reviews pending. {3}-day streak.',
  'Meta de hoy cumplida':
      'Today\'s goal reached',
  'Hoy: {0} de {1}':
      'Today: {0} of {1}',
  'Libro «{0}», capítulo {1} · párrafo «{2}»':
      'Book “{0}”, chapter {1} · paragraph “{2}”',
  'Capítulo {0} leído ✓':
      'Chapter {0} read ✓',
  'Capítulo leído':
      'Chapter read',
  'Terminé este capítulo':
      'I finished this chapter',
  'Siguiente: {0}':
      'Next: {0}',
  'Capítulo {0} de {1}':
      'Chapter {0} of {1}',
  'Traducción':
      'Translation',
  'Tamaño de letra':
      'Text size',
  'Palabras de este capítulo':
      'Words in this chapter',
  'Mis libros':
      'My books',
  'Empezar a leer':
      'Start reading',
  'Leer otra vez':
      'Read again',
  'Seguir: capítulo {0}':
      'Continue: chapter {0}',
  'Adaptado':
      'Adapted',
  'Texto original':
      'Original text',
  'Texto pegado':
      'Pasted text',
  'Si dominas {0}, ya conoces el {1} % de sus {2} caracteres (contando las palabras que se explican en cada capítulo).':
      'If you master {0}, you already know {1} % of its {2} characters (counting the words explained in each chapter).',
  'Nivel estimado: más difícil que HSK 7-9. Aun dominando todo el HSK conocerías el {0} % de sus {1} caracteres. El pinyin es automático y puede fallar en caracteres con varias lecturas.':
      'Estimated level: harder than HSK 7-9. Even mastering all of HSK you\'d know {0} % of its {1} characters. The pinyin is automatic and may be wrong for characters with several readings.',
  'Nivel estimado: {0}. Si lo dominas, conoces el {1} % de sus {2} caracteres. El pinyin es automático y puede fallar en caracteres con varias lecturas.':
      'Estimated level: {0}. If you master it, you know {1} % of its {2} characters. The pinyin is automatic and may be wrong for characters with several readings.',
  'Logros':
      'Achievements',
  '{0} de {1}':
      '{0} of {1}',
  'Compartir mi progreso':
      'Share my progress',
  'La más larga: {0}':
      'Longest: {0}',
  '🛡️ Protector de racha disponible: si un día no practicas, tu racha sigue. Hay uno por semana.':
      '🛡️ Streak shield available: if you skip a day, your streak survives. You get one per week.',
  '🛡️ Ya usaste el protector de esta semana; vuelve el lunes.':
      '🛡️ You\'ve used this week\'s shield; it comes back on Monday.',
  'Pendiente':
      'Locked',
  'Primero elige tu nivel de experiencia':
      'First choose your experience level',
  '¿Cómo quieres estudiar?':
      'How do you want to study?',
  'Tu nivel de experiencia':
      'Your experience level',
  'Soy novato':
      'I\'m a beginner',
  'Silueta y guía de trazos':
      'Outline and stroke guide',
  'Tengo experiencia':
      'I\'m experienced',
  'De memoria, sin silueta':
      'From memory, no outline',
  '¿Qué quieres estudiar?':
      'What do you want to study?',
  'Los 3,000 caracteres de la lista oficial HSK 3.0':
      'The 3,000 characters of the official HSK 3.0 list',
  'Los 214 radicales y la familia de caracteres de cada uno':
      'The 214 radicals and each one\'s family of characters',
  'Radical → familia':
      'Radical → family',
  'Modo novato: verás la silueta del carácter y una animación del trazo correcto cuando te equivoques.':
      'Beginner mode: you\'ll see the character\'s outline and an animation of the correct stroke when you make a mistake.',
  'Modo experto: sin silueta. Escribes de memoria; solo al equivocarte ves en rojo el trazo que tocaba.':
      'Expert mode: no outline. You write from memory; only when you make a mistake do you see the right stroke in red.',
  'No hay palabras en este nivel':
      'There are no words at this level',
  'p. ej. ni3hao3 o nǐhǎo':
      'e.g. ni3hao3 or nǐhǎo',
  'No sé':
      'I don\'t know',
  'Comprobar':
      'Check',
  'Siguiente':
      'Next',
  'Ver resultado':
      'See result',
  '¡Correcto!':
      'Correct!',
  'Casi: las sílabas están bien, revisa los tonos':
      'Almost: the syllables are right, check the tones',
  'Se lee así:':
      'It\'s read like this:',
  'Escribiste: {0}':
      'You wrote: {0}',
  'Practicar con audio':
      'Practice with audio',
  'Grabaciones de hablantes nativos':
      'Native-speaker recordings',
  'Nivel':
      'Level',
  'Tonos':
      'Tones',
  'Oye una sílaba y elige su tono. Con palabras de dos sílabas, los dos.':
      'Hear a syllable and choose its tone. With two-syllable words, both.',
  'Oye una palabra y elige cuál es: por su carácter o por su significado.':
      'Hear a word and pick which one it is: by its characters or by its meaning.',
  'Repaso espaciado de palabras HSK. Hoy tienes {0} por repasar.':
      'Spaced review of HSK words. You have {0} to review today.',
  'Repaso espaciado de las palabras HSK, como con los caracteres.':
      'Spaced review of HSK words, just like characters.',
  'Ve una palabra y escribe cómo se lee, con sus tonos.':
      'See a word and type how it\'s read, with its tones.',
  'Consejo: mantén presionado cualquier botón de sonido para oírlo más lento. En Ajustes puedes hacer que todas las grabaciones suenen lentas.':
      'Tip: press and hold any sound button to hear it more slowly. In Settings you can make every recording play slowly.',
  '{0} de 214 practicados':
      '{0} of 214 practiced',
  'Buscar: 水, 85, agua, shui…':
      'Search: 水, 85, water, shui…',
  'Estudiar':
      'Study',
  'No se pudo abrir el navegador. ':
      'The browser couldn\'t be opened. ',
  '{0}Reporte copiado: pégalo donde quieras enviarlo.':
      '{0}Report copied: paste it wherever you want to send it.',
  '¿Qué quieres contarnos?':
      'What would you like to tell us?',
  '¿Dónde?':
      'Where?',
  'El carácter, o el libro y capítulo':
      'The character, or the book and chapter',
  '¿Qué está mal?':
      'What\'s wrong?',
  '¿Qué pasó? ¿Qué esperabas?':
      'What happened? What did you expect?',
  '¿Qué dice ahora y por qué está mal?':
      'What does it say now and why is it wrong?',
  '¿Qué te gustaría?':
      'What would you like?',
  '¿Cómo debería decir? (opcional)':
      'What should it say? (optional)',
  'Adjuntar versión de la app y modelo del teléfono':
      'Attach app version and phone model',
  'Adjuntar el informe de errores':
      'Attach the error log',
  'No hay errores registrados':
      'No errors logged',
  'Los {0} más recientes':
      'The {0} most recent',
  'Esto es lo que se enviará':
      'This is what will be sent',
  'Escribe una descripción para ver el reporte.':
      'Write a description to see the report.',
  'Abrir en GitHub':
      'Open on GitHub',
  'Copiar el reporte':
      'Copy the report',
  'GitHub abre el formulario del proyecto ya lleno; para enviarlo necesitas una cuenta (es gratis). Si no tienes, copia el reporte y mándalo como prefieras.':
      'GitHub opens the project\'s form already filled in; to send it you need an account (it\'s free). If you don\'t have one, copy the report and send it however you like.',
  'Niveles HSK':
      'HSK levels',
  '🐣 Modo novato':
      '🐣 Beginner mode',
  '🥋 Modo experto':
      '🥋 Expert mode',
  'Buscar: 好, hao, bueno…':
      'Search: 好, hao, good…',
  '{0} dominados':
      '{0} mastered',
  '{0} caracteres oficiales':
      '{0} official characters',
  'Sin resultados':
      'No results',
  'Lo que más confundiste: el {0}.º tono ({1}) con el {2}.º ({3}), {4} veces.':
      'What you mixed up most: tone {0} ({1}) with tone {2} ({3}), {4} times.',
  'Sílabas':
      'Syllables',
  'Palabras':
      'Words',
  'Prueba con otro nivel o con el otro modo.':
      'Try another level or the other mode.',
  '¿Qué tono escuchaste?':
      'Which tone did you hear?',
  '¿Qué tono tiene cada sílaba?':
      'Which tone does each syllable have?',
  'Era el {0}.º tono':
      'It was tone {0}',
  'Era {0}':
      'It was {0}',
  '{0}.º tono':
      'Tone {0}',
  '{0}.º':
      '{0}',
  '1.ª sílaba':
      '1st syllable',
  '2.ª sílaba':
      '2nd syllable',
  'otra vez hoy':
      'again today',
  'mañana':
      'tomorrow',
  'en {0} días':
      'in {0} days',
  'en un mes':
      'in a month',
  'en {0} meses':
      'in {0} months',
  '{0} repasadas · {1} nuevas':
      '{0} reviewed · {1} new',
  'Listas las palabras nuevas de hoy':
      'Today\'s new words are done',
  'Repasaste {0} y aprendiste {1}. Puedes seguir con más o volver mañana (el límite se cambia en Ajustes).':
      'You reviewed {0} and learned {1}. You can keep going or come back tomorrow (the limit can be changed in Settings).',
  '¡Vocabulario al día!':
      'Vocabulary up to date!',
  'No hay palabras por repasar ni nuevas en {0}.':
      'There are no words to review or new ones in {0}.',
  'Repasaste {0} y aprendiste {1} palabras.':
      'You reviewed {0} and learned {1} words.',
  '¿Cómo se lee y qué significa?':
      'How is it read and what does it mean?',
  'Mostrar':
      'Show',
  'En la lista oficial: {0}':
      'In the official list: {0}',
  'No hay grabación de esto y tu teléfono no tiene voz en chino. Puedes instalar una en Ajustes del teléfono › Texto a voz.':
      'There\'s no recording of this and your phone has no Chinese voice. You can install one in your phone\'s Settings › Text-to-speech.',
  'Escuchar pronunciación (mantén presionado para oírla lento)':
      'Listen to the pronunciation (press and hold to hear it slowly)',
  'Regresar':
      'Back',
  '   también {0}':
      '   also {0}',
  'Escuchar otra vez':
      'Listen again',
  'Escuchar más lento':
      'Listen more slowly',
  '¡Excelente oído!':
      'Excellent ear!',
  '¡Muy bien!':
      'Very good!',
  'Vas por buen camino':
      'You\'re on the right track',
  'Cada ronda entrena el oído':
      'Every round trains your ear',
  '{0}\n{1} de {2}':
      '{0}\n{1} of {2}',
  'Otra ronda':
      'Another round',
  '↺  Al revés: empieza donde inicia la flecha':
      '↺  Backwards: start where the arrow begins',
  '¡Logro desbloqueado!':
      'Achievement unlocked!',
  '¡{0} logros nuevos!':
      '{0} new achievements!',
  '¡Seguir!':
      'Keep going!',
  'Ocultar traducción':
      'Hide translation',
  'Ver traducción':
      'Show translation',
  'aquí; en el diccionario: {0}':
      'here; in the dictionary: {0}',
  'Nuevo para ti':
      'New to you',
  'Ya lo estudias':
      'You\'re studying it',
  'Este carácter no está en la base de la app.':
      'This character isn\'t in the app\'s database.',
  'Practicar su escritura':
      'Practice writing it',
  'Reportar un error':
      'Report an error',
  '{0} · carácter {1}':
      '{0} · character {1}',
  'Texto o traducción de un libro':
      'A book\'s text or translation',
  'Difícil':
      'Hard',
  'Medio':
      'Good',
  'Fácil':
      'Easy',
  'Un error de la app':
      'An app bug',
  'Un error en el contenido':
      'A content error',
  'Una sugerencia':
      'A suggestion',
  'Ejemplo':
      'Example',
  'Orden o forma de los trazos':
      'Stroke order or shape',
  'Otro':
      'Other',
  '{0} completo':
      '{0} complete',
  'Estudia todos los caracteres de {0}':
      'Study every character in {0}',
  'Primer trazo':
      'First stroke',
  'Estudia tu primer carácter':
      'Study your first character',
  'Una semana':
      'One week',
  'Practica 7 días seguidos':
      'Practice 7 days in a row',
  'Un mes':
      'One month',
  'Practica 30 días seguidos':
      'Practice 30 days in a row',
  'Cien días':
      'A hundred days',
  'Practica 100 días seguidos':
      'Practice 100 days in a row',
  'Constancia':
      'Consistency',
  'Cumple tu meta diaria 7 días':
      'Reach your daily goal on 7 days',
  'Cien caracteres':
      'A hundred characters',
  'Estudia 100 caracteres':
      'Study 100 characters',
  'Quinientos caracteres':
      'Five hundred characters',
  'Estudia 500 caracteres':
      'Study 500 characters',
  'Mil caracteres':
      'A thousand characters',
  'Estudia 1,000 caracteres':
      'Study 1,000 characters',
  'Los 3,000':
      'All 3,000',
  'Estudia los 3,000 caracteres HSK':
      'Study all 3,000 HSK characters',
  'Cien palabras':
      'A hundred words',
  'Aprende 100 palabras del vocabulario':
      'Learn 100 vocabulary words',
  'Mil palabras':
      'A thousand words',
  'Aprende 1,000 palabras del vocabulario':
      'Learn 1,000 vocabulary words',
  'Oído fino':
      'Sharp ear',
  'Acierta 10 tonos seguidos':
      'Get 10 tones right in a row',
  'Primer libro':
      'First book',
  'Termina un libro de «Leer»':
      'Finish a “Read” book',
  'Biblioteca completa':
      'Whole library',
  'Termina los libros de «Leer»':
      'Finish all the “Read” books',
  'Mil repasos':
      'A thousand reviews',
  'Haz 1,000 repasos y ejercicios':
      'Do 1,000 reviews and exercises',
  'Hanzi Dojo (código de la app)':
      'Hanzi Dojo (app code)',
  'CC-CEDICT (significados)':
      'CC-CEDICT (meanings)',
  'Make Me a Hanzi – graphics.txt (trazos)':
      'Make Me a Hanzi – graphics.txt (strokes)',
  'Make Me a Hanzi – dictionary.txt (lecturas)':
      'Make Me a Hanzi – dictionary.txt (readings)',
  'Unihan (radicales)':
      'Unihan (radicals)',
  'Lista HSK 3.0 (ivankra/hsk30)':
      'HSK 3.0 list (ivankra/hsk30)',
  'Tatoeba (oraciones de ejemplo)':
      'Tatoeba (example sentences)',
  'Noto Color Emoji y Noto Sans Math (símbolos de la versión web)':
      'Noto Color Emoji and Noto Sans Math (web version symbols)',
  'Noto Sans SC (tipografía)':
      'Noto Sans SC (typeface)',
  'OpenCC (tradicional → simplificado)':
      'OpenCC (traditional → simplified)',
  'chinese-poetry (textos clásicos de «Leer»)':
      'chinese-poetry (classic texts in “Read”)',
  'audio-cmn (grabaciones de pronunciación)':
      'audio-cmn (pronunciation recordings)',
  'progreso':
      'progress',
  'historial':
      'history',
  'lectura':
      'reading',
  'ejercicios':
      'exercises',
  'logros':
      'achievements',
  'protecciones':
      'streak shields',
  'vocabulario':
      'vocabulary',
  'Vibrar al trazar':
      'Vibrate when writing',
  'Un toque corto con cada trazo correcto y uno más marcado al equivocarte.':
      'A short tap with each correct stroke and a firmer one when you make a mistake.',
  'Sonido de pincel':
      'Brush sound',
  'El roce del pincel sobre el papel con cada trazo correcto.':
      'The brush brushing the paper with each correct stroke.',
  'Orden de trazos':
      'Stroke order',
  'Trazo {0} de {1}':
      'Stroke {0} of {1}',
  'Repetir':
      'Replay',
  'Buscar dibujando':
      'Search by drawing',
  'Deshacer trazo':
      'Undo stroke',
  'Preparando los caracteres…':
      'Preparing the characters…',
  'Dibuja un carácter en el cuadro, de preferencia en su orden de trazos. Con cada trazo verás aquí los más parecidos.':
      'Draw a character in the box, ideally in its stroke order. With each stroke you\'ll see the closest matches here.',
  'protegido 🛡️':
      'shielded 🛡️',
  'sin repasos':
      'no reviews',
  ' · cargando':
      ' · charging',
  'capítulo':
      'chapter',
  'capítulos':
      'chapters',
  'Lectura':
      'Reading',
  'Caracteres':
      'Characters',
  'Examen de ubicación':
      'Placement test',
  'Simulacro {0}':
      '{0} mock exam',
  'No lo sé':
      'I don\'t know',
  '¿Qué significa lo que escuchas?':
      'What does what you hear mean?',
  '¿Cómo se escribe?':
      'How is it written?',
  '¡Aprobado! (se aprueba con {0})':
      'Passed! (passing score: {0})',
  'Aún no: se aprueba con {0}':
      'Not yet: the passing score is {0}',
  '{0} de {1} correctas · {2}:{3}':
      '{0} of {1} correct · {2}:{3}',
  'Tu mejor calificación anterior: {0}':
      'Your previous best score: {0}',
  'Para repasar':
      'To review',
  'No respondiste':
      'You didn\'t answer',
  'Elegiste: {0}':
      'You chose: {0}',
  'Otro simulacro':
      'Another mock exam',
  'Tu nivel para empezar':
      'Your starting level',
  'Quedó elegido para la práctica con audio. Para escribir, elige este nivel en Estudiar › Niveles HSK.':
      'It\'s now selected for audio practice. For writing, choose this level in Study › HSK levels.',
  'Listo':
      'Done',
  'Simulacro HSK':
      'HSK mock exam',
  '30 preguntas en 12 minutos: escucha, lectura y caracteres. Se aprueba con 60.':
      '30 questions in 12 minutes: listening, reading and characters. Passing score: 60.',
  '30 preguntas en 12 minutos. Tu mejor calificación en este nivel: {0}.':
      '30 questions in 12 minutes. Your best score at this level: {0}.',
  'Unas preguntas por nivel para saber por dónde empezar.':
      'A few questions per level to find out where to start.',
  'Detener la lectura':
      'Stop reading',
  'Carácter del día':
      'Character of the day',
  'Un carácter al día en tu pantalla de bloqueo, para repasarlo de un vistazo. Sin sonido.':
      'One character a day on your lock screen, to review at a glance. Silent.',
  'Todos los días a las {0}, en tu pantalla de bloqueo. Sin sonido.':
      'Every day at {0}, on your lock screen. Silent.',
  'Sin permiso de notificaciones no puedo mostrarte el carácter del día. Actívalo en los ajustes del teléfono.':
      'Without notification permission I can\'t show you the character of the day. Turn it on in your phone settings.',
  'Listo: el carácter de hoy ya está en tus notificaciones.':
      'Done: today\'s character is already in your notifications.',
  '¿A qué hora te muestro el carácter del día?':
      'What time should I show you the character of the day?',
  'Seguir leyendo':
      'Keep reading',
  'Pausa':
      'Pause',
  'Párrafo {0} de {1}':
      'Paragraph {0} of {1}',
  'Velocidad {0}':
      'Speed {0}',
  'Escuchar este párrafo':
      'Listen to this paragraph',
  'Escuchar el capítulo':
      'Listen to the chapter',
  'Ya está en tu vocabulario':
      'Already in your vocabulary',
  'Al repaso':
      'Add to review',
  'Comprensión':
      'Comprehension',
  '{0} preguntas sobre lo que leíste':
      '{0} questions about what you read',
  '{0} de {1} correctas · ¡entendiste todo!':
      '{0} of {1} correct · you understood it all!',
  '{0} de {1} correctas':
      '{0} of {1} correct',
  '¿Qué entendiste?':
      'How much did you understand?',
  '¿Te está sirviendo Hanzi Dojo? Es gratis y sin anuncios; si quieres, puedes apoyarlo.':
      'Is Hanzi Dojo helping you? It\'s free and ad-free; if you\'d like, you can support it.',
  'Ver cómo':
      'See how',
  'Apoyar el proyecto':
      'Support the project',
  'Voluntario: la app es gratis y completa para todos':
      'Optional: the app is free and complete for everyone',
  'No se pudo abrir el navegador.':
      'Couldn\'t open the browser.',
  'Apoyar Hanzi Dojo':
      'Support Hanzi Dojo',
  'Hanzi Dojo es gratis, sin anuncios ni cuentas, y de código abierto. Así va a seguir.':
      'Hanzi Dojo is free, with no ads or accounts, and open source. It will stay that way.',
  'Si te está ayudando a aprender y quieres apoyar su desarrollo (más libros, grabaciones y ejercicios), puedes dejar un donativo voluntario. No desbloquea nada: la app es igual para todos.':
      'If it\'s helping you learn and you\'d like to support its development (more books, recordings and exercises), you can leave an optional donation. It doesn\'t unlock anything: the app is the same for everyone.',
  'Donar con PayPal':
      'Donate with PayPal',
  'Se abre en el navegador. Tú eliges la cantidad.':
      'Opens in your browser. You choose the amount.',
  'Otras formas de ayudar':
      'Other ways to help',
  'Recomiéndala a alguien que estudie chino, cuéntanos qué mejorar (Ajustes → Reportar un problema) o corrige una traducción en GitHub.':
      'Recommend it to someone learning Chinese, tell us what to improve (Settings → Report a problem) or fix a translation on GitHub.',
  'Ahora no':
      'Not now',
};
