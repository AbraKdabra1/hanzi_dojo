// ─────────────────────────────────────────────────────────────────────────────
// capturas_web.mjs — La versión web en Chrome (Android) y en Safari (iPhone)
//
// Lo corre .github/workflows/web.yml con Playwright, sobre la app ya
// compilada y servida en http://localhost:8000/hanzi_dojo/. En cada
// navegador:
//   1. Primera vez: descarga y guarda la base; espera el botón "Estudiar".
//   2. Capturas del inicio, la elección de modo y los niveles.
//   3. Que el audio se pueda tocar (Ogg en Chrome; en Safari, CAF).
//   4. Segunda vez: abre desde lo guardado (IndexedDB), sin descargar.
//   5. Sin internet: abre igual (sw_hanzi.js).
//
// Uso: node herramientas/capturas_web.mjs <dirección> <carpeta de salida>
// ─────────────────────────────────────────────────────────────────────────────

import { mkdirSync, writeFileSync } from 'node:fs';
import { chromium, devices, webkit } from 'playwright';

const [, , direccion, salida] = process.argv;
const url = new URL(direccion);
url.searchParams.set('semantica', '1'); // ver main.dart: para encontrar los botones
mkdirSync(salida, { recursive: true });

// [nombre, motor, dispositivo, opciones del contexto]
const navegadores = [
  ['chrome_android', chromium, devices['Pixel 7'], {}],
  ['safari_iphone', webkit, devices['iPhone 15'], {}],
  // Para comparar: Chrome sin service worker (¿algo de sw_hanzi.js estorba?).
  ['chrome_sin_sw', chromium, devices['Pixel 7'], { serviceWorkers: 'block' }],
];

const resumen = [];
for (const [nombre, tipo, dispositivo, extra] of navegadores) {
  const registro = [];
  const anotar = (texto) => {
    const linea = `${new Date().toISOString().slice(11, 19)} ${texto}`;
    registro.push(linea);
    console.log(`[${nombre}] ${linea}`);
  };
  const navegador = await tipo.launch();
  const contexto = await navegador.newContext({
    ...dispositivo,
    locale: 'es-MX',
    timezoneId: 'America/Mexico_City',
    ...extra,
  });
  // Pedidos en curso (para saber cuál se queda colgado) y a otros servidores
  // (la versión web solo debería pedir a Google Fonts letras que no trae).
  const enCurso = new Map();
  let pagina;
  const nuevaPagina = async () => {
    if (pagina) await pagina.close();
    enCurso.clear();
    pagina = await contexto.newPage();
    pagina.on('console', (m) => {
      if (!m.text().includes('GL Driver Message')) anotar(`[consola ${m.type()}] ${m.text()}`);
    });
    pagina.on('pageerror', (e) => anotar(`[error de página] ${e.message}`));
    pagina.on('request', (r) => {
      enCurso.set(r, Date.now());
      if (!r.url().startsWith(url.origin) && !r.url().startsWith('blob:') && !r.url().startsWith('data:')) {
        anotar(`[fuera del sitio] ${r.method()} ${r.url()}`);
      }
    });
    pagina.on('requestfinished', (r) => enCurso.delete(r));
    pagina.on('requestfailed', (r) => {
      enCurso.delete(r);
      anotar(`[falló] ${r.url()} ${r.failure()?.errorText ?? ''}`);
    });
  };
  await nuevaPagina();
  const diagnostico = async () => {
    for (const [r, desde] of enCurso) {
      anotar(`[sin terminar] ${r.method()} ${r.url()} (desde hace ${((Date.now() - desde) / 1000).toFixed(0)} s)`);
    }
    const estado = await pagina
      .evaluate(async () => ({
        sw: navigator.serviceWorker?.controller?.scriptURL ?? 'ninguno',
        bases: (await indexedDB.databases?.())?.map((b) => `${b.name} v${b.version}`).join(', ') ?? '?',
        // Lo que ve la accesibilidad (así se encuentran los botones).
        semantica: [...document.querySelectorAll('flt-semantics')]
          .map((e) => `${e.getAttribute('role') ?? ''}:${e.getAttribute('aria-label') ?? e.textContent ?? ''}`)
          .filter((t) => t.length > 1)
          .slice(0, 40),
      }))
      .catch((e) => ({ error: e.message }));
    anotar(`[estado] ${JSON.stringify(estado)}`);
  };
  // Cuánto tarda en quedar guardada la base en IndexedDB: una lectura espera a
  // que termine la escritura en curso.
  const esperarGuardado = async () => {
    const r = await pagina.evaluate(
      () =>
        new Promise((listo) => {
          const t0 = performance.now();
          const abierta = indexedDB.open('sqflite_databases');
          abierta.onerror = () => listo({ error: String(abierta.error) });
          abierta.onsuccess = () => {
            const db = abierta.result;
            const cuenta = db.transaction(['blocks'], 'readonly').objectStore('blocks').count();
            cuenta.onsuccess = () => {
              listo({ bloques: cuenta.result, ms: Math.round(performance.now() - t0) });
              db.close();
            };
            cuenta.onerror = () => listo({ error: String(cuenta.error) });
          };
        }),
    );
    anotar(`guardado en IndexedDB: ${JSON.stringify(r)}`);
    resumen.push(`${nombre} · base guardada: ${r.bloques} bloques, ${(r.ms / 1000).toFixed(1)} s después de abrir`);
  };

  const captura = async (archivo) => {
    await pagina.screenshot({ path: `${salida}/${nombre}_${archivo}.png` });
    anotar(`captura ${archivo}`);
  };
  const tocar = async (texto) => {
    // El botón puede tener el texto tal cual o, en las tarjetas, junto con el
    // subtítulo (en el texto o en aria-label): basta con que empiece con él.
    const inicio = new RegExp(`^\\s*${texto}`);
    const opciones = [
      pagina.getByText(texto, { exact: true }),
      pagina.getByRole('button', { name: inicio }),
      pagina.locator(`flt-semantics[aria-label^="${texto}"]`),
      pagina.getByText(inicio),
    ];
    for (const opcion of opciones) {
      if ((await opcion.count()) > 0) {
        await opcion.first().click({ timeout: 15000 });
        await pagina.waitForTimeout(2500);
        return;
      }
    }
    throw new Error(`No encontré "${texto}"`);
  };
  const abrir = async (paso, limite) => {
    const inicio = Date.now();
    await pagina.goto(url.href, { waitUntil: 'load' });
    await pagina.getByText('Estudiar', { exact: true }).first().waitFor({ timeout: limite });
    const segundos = ((Date.now() - inicio) / 1000).toFixed(1);
    anotar(`${paso}: "Estudiar" a los ${segundos} s`);
    resumen.push(`${nombre} · ${paso}: ${segundos} s`);
    await pagina.waitForTimeout(3000); // la rama del ciruelo termina de crecer
  };

  let pasos = 0;
  const paso = async (titulo, hacer) => {
    try {
      await hacer();
      pasos++;
    } catch (e) {
      anotar(`✗ ${titulo}: ${e.message.split('\n')[0]}`);
      resumen.push(`${nombre} · ✗ ${titulo}`);
      await diagnostico();
      await captura(`error_${titulo.replace(/\W+/g, '_')}`).catch(() => {});
    }
  };

  await paso('primera vez', async () => {
    await abrir('primera vez', 240000);
    await captura('01_inicio');
    await esperarGuardado();
  });
  const completo = nombre !== 'chrome_sin_sw';
  if (!completo) {
    // Experimento: leer la base guardada directo con JavaScript (sin la app),
    // para saber si IndexedDB es lento en Chrome o si el atasco está en la app.
    await nuevaPagina();
    await pagina.goto(new URL('manifest.json', url).href);
    const lectura = await pagina.evaluate(
      () =>
        new Promise((listo) => {
          const t0 = performance.now();
          const abierta = indexedDB.open('sqflite_databases');
          abierta.onsuccess = () => {
            const tx = abierta.result.transaction(['files', 'blocks'], 'readonly');
            let n = 0;
            const cursor = tx.objectStore('blocks').openCursor();
            cursor.onsuccess = () => {
              const c = cursor.result;
              if (c) {
                n++;
                c.continue();
              } else {
                listo({ bloques: n, ms: Math.round(performance.now() - t0) });
              }
            };
            cursor.onerror = () => listo({ error: String(cursor.error) });
          };
          abierta.onerror = () => listo({ error: String(abierta.error) });
        }),
    );
    anotar(`lectura directa de IndexedDB: ${JSON.stringify(lectura)}`);
    resumen.push(`${nombre} · lectura directa: ${lectura.bloques} bloques en ${lectura.ms} ms`);
  }
  if (completo) await paso('estudiar', async () => {
    await tocar('Estudiar');
    await captura('02_modo');
    await tocar('Soy novato');
    await captura('03_niveles');
    await tocar('Niveles HSK');
    await captura('04_hsk');
  });
  if (completo) await paso('audio', async () => {
    const audio = await pagina.evaluate(async () => {
      const a = document.createElement('audio');
      const r = await fetch('assets/assets/audio/silabas/ma1.opus');
      return {
        ogg: a.canPlayType('audio/ogg; codecs=opus'),
        caf: a.canPlayType('audio/x-caf; codecs=opus'),
        ma1: `${r.status} ${(await r.arrayBuffer()).byteLength} bytes`,
      };
    });
    anotar(`audio: Ogg Opus "${audio.ogg}", CAF Opus "${audio.caf}", ma1 ${audio.ma1}`);
    resumen.push(`${nombre} · audio: ogg="${audio.ogg}" caf="${audio.caf}"`);
  });
  await paso('segunda vez', async () => {
    // Como al cerrar la app y volver a abrirla: otra pestaña.
    await nuevaPagina();
    await abrir('segunda vez', completo ? 90000 : 300000);
    await captura('05_segunda_vez');
  });
  if (completo) await paso('sin internet', async () => {
    // Dar tiempo a que el service worker termine de guardar.
    await pagina.waitForTimeout(3000);
    await contexto.setOffline(true);
    await nuevaPagina();
    await abrir('sin internet', 90000);
    await captura('06_sin_internet');
    await contexto.setOffline(false);
  });

  const total = completo ? 5 : 2;
  anotar(`pasos completos: ${pasos} de ${total}`);
  resumen.push(`${nombre} · pasos completos: ${pasos} de ${total}`);
  writeFileSync(`${salida}/registro_${nombre}.txt`, registro.join('\n') + '\n');
  await navegador.close();
}

writeFileSync(`${salida}/resumen_navegadores.txt`, resumen.join('\n') + '\n');
console.log(resumen.join('\n'));
