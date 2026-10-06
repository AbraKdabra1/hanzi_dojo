"""medir_recortes.py — Dónde empieza y termina la voz en cada grabación.

Las grabaciones de assets/audio/ ya vienen sin el silencio largo de antes y
después, pero conservan un margen (60 ms antes y 120 ms después: así, oídas
solas, no se comen consonantes suaves ni la cola del tono). Al leer un texto
de corrido, esos márgenes se suman entre palabra y palabra y la lectura suena
entrecortada. Aquí se mide, en cada archivo, dónde está la voz de verdad para
que la app recorte el sobrante al encadenarlas (widgets/boton_voz.dart).

Genera assets/audio/recortes.txt, una línea por grabación:
    s/ma1 31 545          (sílaba ma1: tocar del ms 31 al 545)
    p/56fe-4e66-9986 22 870
(s/ = silabas/, p/ = palabras/; los nombres son los de los archivos).

Requiere ffmpeg y numpy. Uso:
    python herramientas_datos/medir_recortes.py
preparar_audio.py lo corre al final, así que normalmente no hace falta.
"""

from __future__ import annotations

import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
AUDIO = RAIZ / "assets" / "audio"
SALIDA = AUDIO / "recortes.txt"

TASA = 16000
CUADRO = 160            # 10 ms
DEBAJO_DEL_PICO = 35.0  # dB: la voz es lo que esté a menos de esto del cuadro más fuerte
PISO = -60.0            # dBFS: nunca considerar voz algo más bajo que esto
MARGEN_ANTES = 25       # ms antes de la voz (consonantes suaves: s, sh, x, f)
MARGEN_DESPUES = 50     # ms después (la cola del tono)


def medir(ruta: Path) -> tuple[str, int, int]:
    crudo = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(ruta), "-ac", "1", "-ar", str(TASA), "-f", "s16le", "-"],
        check=True, capture_output=True,
    ).stdout
    x = np.frombuffer(crudo, dtype="<i2").astype(np.float32) / 32768.0
    duracion = round(len(x) * 1000 / TASA)
    clave = f"{'s' if ruta.parent.name == 'silabas' else 'p'}/{ruta.stem}"
    n = len(x) // CUADRO
    if n < 3:
        return clave, 0, duracion
    db = 10 * np.log10(np.mean(x[: n * CUADRO].reshape(n, CUADRO) ** 2, axis=1) + 1e-12)
    umbral = max(db.max() - DEBAJO_DEL_PICO, PISO)
    voz = np.nonzero(db >= umbral)[0]
    if len(voz) == 0:
        return clave, 0, duracion
    inicio = max(0, int(voz[0]) * 10 - MARGEN_ANTES)
    fin = min(duracion, (int(voz[-1]) + 1) * 10 + MARGEN_DESPUES)
    return clave, inicio, fin


def main() -> None:
    archivos = sorted((AUDIO / "silabas").glob("*.opus")) + sorted((AUDIO / "palabras").glob("*.opus"))
    if not archivos:
        sys.exit("No hay grabaciones en assets/audio/")
    with ProcessPoolExecutor() as grupo:
        filas = list(grupo.map(medir, archivos, chunksize=64))
    with open(SALIDA, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Generado por herramientas_datos/medir_recortes.py: dónde empieza y termina la voz (ms).\n")
        for clave, inicio, fin in filas:
            f.write(f"{clave} {inicio} {fin}\n")
    print(f"{len(filas)} grabaciones → {SALIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
