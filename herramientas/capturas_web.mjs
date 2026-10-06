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
  const pagina = await contexto.newPage();
  pagina.on('console', (m) => {
    if (!m.text().includes('GL Driver Message')) anotar(`[consola ${m.type()}] ${m.text()}`);
  });
  pagina.on('pageerror', (e) => anotar(`[error de página] ${e.message}`));
  // Pedidos en curso (para saber cuál se queda colgado) y a otros servidores
  // (la versión web no debería pedir nada fuera de su sitio).
  const enCurso = new Map();
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
  const diagnostico = async () => {
    for (const [r, desde] of enCurso) {
      anotar(`[sin terminar] ${r.method()} ${r.url()} (desde hace ${((Date.now() - desde) / 1000).toFixed(0)} s)`);
    }
    const estado = await pagina
      .evaluate(async () => ({
        sw: navigator.serviceWorker?.controller?.scriptURL ?? 'ninguno',
        bases: (await indexedDB.databases?.())?.map((b) => `${b.name} v${b.version}`).join(', ') ?? '?',
      }))
      .catch((e) => ({ error: e.message }));
    anotar(`[estado] ${JSON.stringify(estado)}`);
  };

  const captura = async (archivo) => {
    await pagina.screenshot({ path: `${salida}/${nombre}_${archivo}.png` });
    anotar(`captura ${archivo}`);
  };
  const tocar = async (texto) => {
    // Las tarjetas juntan título y subtítulo en un mismo elemento: basta con
    // que empiece con el texto.
    const exacto = pagina.getByText(texto, { exact: true });
    const boton = (await exacto.count()) > 0 ? exacto : pagina.getByText(new RegExp(`^\\s*${texto}`));
    await boton.first().click({ timeout: 15000 });
    await pagina.waitForTimeout(2500);
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
  });
  const completo = nombre !== 'chrome_sin_sw';
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
    await abrir('segunda vez', 90000);
    await captura('05_segunda_vez');
  });
  if (completo) await paso('sin internet', async () => {
    // Dar tiempo a que el service worker termine de guardar.
    await pagina.waitForTimeout(3000);
    await contexto.setOffline(true);
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
