// ─────────────────────────────────────────────────────────────────────────────
// sw_hanzi.js — Meizi Hanzi sin internet (versión web)
//
// Después de abrirla una vez con internet, la app funciona sin conexión:
//   · La app (index.html, main.dart.js, el motor de dibujo…): primero la red,
//     para recibir las versiones nuevas; sin red o si tarda, la copia
//     guardada.
//   · Grabaciones y tipografías: primero la copia guardada (no cambian), y se
//     guardan la primera vez que suenan o se usan.
//   · La base de contenido no pasa por aquí: la app la guarda en IndexedDB.
// ─────────────────────────────────────────────────────────────────────────────

const CACHE_APP = 'hanzi-dojo-app';
const CACHE_FIJO = 'hanzi-dojo-grabaciones-v1';
const FIJO = /\/assets\/assets\/(audio|sonidos|fonts)\//;
const NUNCA = /\/assets\/assets\/db\//;
const ESPERA_RED_MS = 5000;

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (evento) => {
  evento.waitUntil((async () => {
    for (const nombre of await caches.keys()) {
      if (nombre !== CACHE_APP && nombre !== CACHE_FIJO) await caches.delete(nombre);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (evento) => {
  const pedido = evento.request;
  if (pedido.method !== 'GET') return;
  const url = new URL(pedido.url);
  if (url.origin !== self.location.origin || NUNCA.test(url.pathname)) return;
  evento.respondWith(FIJO.test(url.pathname) ? primeroGuardado(pedido, url) : primeroRed(pedido));
});

async function primeroRed(pedido) {
  const cache = await caches.open(CACHE_APP);
  const guardada = cache.match(pedido, { ignoreSearch: true });
  const red = fetch(pedido).then((respuesta) => {
    if (respuesta.ok && respuesta.status === 200 && respuesta.type === 'basic') {
      cache.put(pedido, respuesta.clone()).catch(() => {});
    }
    return respuesta;
  });
  red.catch(() => {}); // si gana la copia y luego falla la red, no es error
  try {
    // Si la red tarda demasiado y hay copia, se usa la copia.
    const copia = await guardada;
    if (!copia) return await red;
    return await Promise.race([red, new Promise((listo) => setTimeout(() => listo(copia), ESPERA_RED_MS))]);
  } catch (error) {
    const copia = (await guardada) || (pedido.mode === 'navigate' ? await cache.match('./') : undefined);
    if (copia) return copia;
    throw error;
  }
}

async function primeroGuardado(pedido, url) {
  const cache = await caches.open(CACHE_FIJO);
  let respuesta = await cache.match(url.href);
  if (!respuesta) {
    // Se pide el archivo completo (sin "Range"), para poder guardarlo.
    respuesta = await fetch(url.href);
    if (respuesta.ok && respuesta.status === 200) cache.put(url.href, respuesta.clone()).catch(() => {});
  }
  return conRango(pedido, respuesta);
}

// El reproductor de audio a veces pide solo un tramo ("Range: bytes=0-"):
// se recorta del archivo completo.
async function conRango(pedido, respuesta) {
  const rango = pedido.headers.get('range');
  const m = rango && /bytes=(\d*)-(\d*)/.exec(rango);
  if (!m || respuesta.status !== 200) return respuesta;
  const datos = await respuesta.arrayBuffer();
  const total = datos.byteLength;
  const inicio = m[1] ? Number(m[1]) : Math.max(0, total - Number(m[2] || 0));
  const fin = m[1] && m[2] ? Math.min(Number(m[2]), total - 1) : total - 1;
  return new Response(datos.slice(inicio, fin + 1), {
    status: 206,
    headers: {
      'Content-Type': respuesta.headers.get('Content-Type') || 'audio/ogg',
      'Content-Range': `bytes ${inicio}-${fin}/${total}`,
      'Content-Length': String(fin - inicio + 1),
      'Accept-Ranges': 'bytes',
    },
  });
}
