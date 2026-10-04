"""preparar_audio.py — Grabaciones de pronunciación para la app (voz humana).

La voz del teléfono (texto a voz) no existe o falla en muchos teléfonos sin
servicios de Google (p. ej. Huawei), así que la app trae sus propias
grabaciones de hablantes nativos:

  * 1,707 sílabas con tono (todas las del mandarín) — voz de Chen Wang.
  * ~8,500 palabras y caracteres de la lista HSK — voz de Yue Tan (Shtooka).

Fuente: proyecto audio-cmn, https://github.com/hugolpz/audio-cmn
Licencia: CC BY-SA (ver assets/licencias/audio_cmn_CC-BY-SA.txt).

Qué hace con cada grabación:
  1. Recorta el silencio de antes y de después (con un margen, para no comerse
     consonantes suaves como s, sh, x, f). El umbral se calcula por archivo a
     partir de su ruido de fondo.
  2. Iguala el volumen (todas suenan parecido de fuerte).
  3. La guarda en Opus a 20 kbps (formato para voz: ~2-3 KB por palabra).

Uso:
  git clone --filter=blob:none --sparse https://github.com/hugolpz/audio-cmn /tmp/audio-cmn
  (cd /tmp/audio-cmn && git sparse-checkout set 64k)
  python herramientas_datos/preparar_audio.py /tmp/audio-cmn/64k

Genera (se borra y se rehace todo):
  assets/audio/silabas/<pinyin con número>.opus    ma1.opus, lv4.opus, _ng2.opus
  assets/audio/palabras/<código de cada carácter>.opus
        图书馆 → 56fe-4e66-9986.opus (nombres ASCII: más seguros en Android)
  assets/audio/palabras.txt   lista de palabras grabadas, una por línea
  assets/audio/silabas.txt    lista de sílabas grabadas, una por línea
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "assets" / "audio"

TASA_ANALISIS = 16000          # Hz, solo para medir dónde hay voz
CUADRO = 160                   # 10 ms a 16 kHz
MARGEN_ANTES = 0.06            # s de margen antes de la voz
MARGEN_DESPUES = 0.12          # s después (las colas de los tonos se apagan lento)
RMS_OBJETIVO = -20.0           # dBFS de la parte con voz
PICO_MAXIMO = -1.0             # dBFS
KBPS = 20

SOLO_HAN = re.compile(r"^[㐀-鿿]+$")


def nombre_palabra(palabra: str) -> str:
    """图书馆 → '56fe-4e66-9986' (igual que en lib/datos/audio.dart)."""
    return "-".join(f"{ord(c):x}" for c in palabra)


def _pcm(origen: Path) -> np.ndarray:
    crudo = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(origen), "-ac", "1", "-ar", str(TASA_ANALISIS),
         "-f", "s16le", "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(crudo, dtype="<i2").astype(np.float32) / 32768.0


def medir(origen: Path) -> tuple[float, float, float]:
    """(inicio s, fin s, ganancia dB) de la parte con voz."""
    x = _pcm(origen)
    n = len(x) // CUADRO
    if n < 3:
        return 0.0, len(x) / TASA_ANALISIS, 0.0
    cuadros = x[: n * CUADRO].reshape(n, CUADRO)
    db = 10 * np.log10(np.mean(cuadros**2, axis=1) + 1e-12)
    fondo = np.percentile(db, 10)
    pico = db.max()
    # Voz = claramente por encima del ruido de fondo (no "cerca del pico": las
    # consonantes suaves quedan 25-35 dB debajo de la vocal).
    umbral = max(fondo + 12.0, pico - 50.0)
    voz = np.nonzero(db > umbral)[0]
    if len(voz) == 0:
        return 0.0, len(x) / TASA_ANALISIS, 0.0
    inicio = max(0.0, voz[0] * CUADRO / TASA_ANALISIS - MARGEN_ANTES)
    fin = min(len(x) / TASA_ANALISIS, (voz[-1] + 1) * CUADRO / TASA_ANALISIS + MARGEN_DESPUES)

    tramo = x[int(inicio * TASA_ANALISIS): int(fin * TASA_ANALISIS)]
    hablado = cuadros[voz]
    rms = 10 * np.log10(np.mean(hablado**2) + 1e-12)
    pico_muestra = 20 * np.log10(np.max(np.abs(tramo)) + 1e-12)
    ganancia = min(RMS_OBJETIVO - rms, PICO_MAXIMO - pico_muestra)
    return inicio, fin, float(ganancia)


def convertir(tarea: tuple[str, str]) -> tuple[str, int]:
    origen, destino = Path(tarea[0]), Path(tarea[1])
    inicio, fin, ganancia = medir(origen)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", f"{inicio:.3f}", "-to", f"{fin:.3f}", "-i", str(origen),
         "-af", f"volume={ganancia:.2f}dB", "-ac", "1",
         "-c:a", "libopus", "-b:a", f"{KBPS}k", "-vbr", "on", "-application", "voip",
         "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
         str(destino)],
        check=True,
    )
    return destino.name, destino.stat().st_size


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    fuente = Path(sys.argv[1])
    silabas_src = fuente / "syllabs"
    palabras_src = fuente / "hsk"
    if not silabas_src.is_dir() or not palabras_src.is_dir():
        sys.exit(f"No encontré {silabas_src} y {palabras_src}")

    if DESTINO.exists():
        shutil.rmtree(DESTINO)
    (DESTINO / "silabas").mkdir(parents=True)
    (DESTINO / "palabras").mkdir(parents=True)

    tareas: list[tuple[str, str]] = []
    for f in sorted(silabas_src.glob("cmn-*.mp3")):
        clave = f.stem[4:]  # 'cmn-ma1' → 'ma1'
        tareas.append((str(f), str(DESTINO / "silabas" / f"{clave}.opus")))

    palabras: list[str] = []
    for f in sorted(palabras_src.glob("cmn-*.mp3")):
        palabra = f.stem[4:]
        # Se omiten las construcciones como '一_就_' (no son palabras que se lean solas).
        if not SOLO_HAN.match(palabra):
            continue
        palabras.append(palabra)
        tareas.append((str(f), str(DESTINO / "palabras" / f"{nombre_palabra(palabra)}.opus")))

    total = 0
    with ProcessPoolExecutor() as grupo:
        for i, (_, tam) in enumerate(grupo.map(convertir, tareas, chunksize=32), 1):
            total += tam
            if i % 1000 == 0:
                print(f"  {i}/{len(tareas)}…", flush=True)

    (DESTINO / "palabras.txt").write_text("\n".join(palabras) + "\n", encoding="utf-8")
    silabas = sorted(Path(t[1]).stem for t in tareas if "/silabas/" in t[1].replace(os.sep, "/"))
    (DESTINO / "silabas.txt").write_text("\n".join(silabas) + "\n", encoding="utf-8")
    n_sil = len(tareas) - len(palabras)
    print(f"Listo: {n_sil} sílabas + {len(palabras)} palabras, {total / 2**20:.1f} MB en {DESTINO}")


if __name__ == "__main__":
    main()
