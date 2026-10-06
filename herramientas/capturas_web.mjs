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

const navegadores = [
  ['chrome_android', chromium, devices['Pixel 7']],
  ['safari_iphone', webkit, devices['iPhone 15']],
];

const resumen = [];
for (const [nombre, tipo, dispositivo] of navegadores) {
  const registro = [];
  const anotar = (texto) => {
    const linea = `${new Date().toISOString().slice(11, 19)} ${texto}`;
    registro.push(linea);
    console.log(`[${nombre}] ${linea}`);
  };
  const navegador = await tipo.launch();
  const contexto = await navegador.newContext({ ...dispositivo, locale: 'es-MX', timezoneId: 'America/Mexico_City' });
  const pagina = await contexto.newPage();
  pagina.on('console', (m) => anotar(`[consola ${m.type()}] ${m.text()}`));
  pagina.on('pageerror', (e) => anotar(`[error de página] ${e.message}`));
  pagina.on('requestfailed', (r) => anotar(`[falló] ${r.url()} ${r.failure()?.errorText ?? ''}`));

  const captura = async (archivo) => {
    await pagina.screenshot({ path: `${salida}/${nombre}_${archivo}.png` });
    anotar(`captura ${archivo}`);
  };
  const tocar = async (texto) => {
    await pagina.getByText(texto, { exact: true }).first().click({ timeout: 15000 });
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
      await captura(`error_${titulo.replace(/\W+/g, '_')}`).catch(() => {});
    }
  };

  await paso('primera vez', async () => {
    await abrir('primera vez', 240000);
    await captura('01_inicio');
  });
  await paso('estudiar', async () => {
    await tocar('Estudiar');
    await captura('02_modo');
    await tocar('Soy novato');
    await captura('03_niveles');
    await tocar('Niveles HSK');
    await captura('04_hsk');
  });
  await paso('audio', async () => {
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
  await paso('sin internet', async () => {
    // Dar tiempo a que el service worker termine de guardar.
    await pagina.waitForTimeout(3000);
    await contexto.setOffline(true);
    await abrir('sin internet', 90000);
    await captura('06_sin_internet');
    await contexto.setOffline(false);
  });

  anotar(`pasos completos: ${pasos} de 5`);
  resumen.push(`${nombre} · pasos completos: ${pasos} de 5`);
  writeFileSync(`${salida}/registro_${nombre}.txt`, registro.join('\n') + '\n');
  await navegador.close();
}

writeFileSync(`${salida}/resumen_navegadores.txt`, resumen.join('\n') + '\n');
console.log(resumen.join('\n'));
