"""listar_lecturas.py — Qué caracteres sueltos suenan con su propia grabación.

La app trae dos colecciones (ver preparar_audio.py): las sílabas, de una voz,
y las palabras y caracteres HSK, de otra. Al leer una oración, las palabras
suenan con la segunda voz; si cada carácter suelto sonara con la sílaba, la
lectura saltaría de una voz a otra.

Este script escribe assets/audio/lecturas.txt con los caracteres que:
  · tienen grabación propia (están en assets/audio/palabras.txt), y
  · tienen UNA sola lectura en la base (sin otras_lecturas),
junto con la sílaba de esa lectura ('问 wen4'). La app los toca con su
grabación cuando la sílaba que toca en el texto es esa misma; si no (otra
lectura, tono neutro distinto), usa la sílaba.

Uso (después de construir la base y preparar el audio):
    python herramientas_datos/listar_lecturas.py
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BASE = RAIZ / "assets" / "db" / "contenido.db"
AUDIO = RAIZ / "assets" / "audio"


def main() -> None:
    grabados = {l.strip() for l in (AUDIO / "palabras.txt").read_text(encoding="utf-8").splitlines() if l.strip()}
    con = sqlite3.connect(BASE)
    filas = con.execute(
        "SELECT caracter, pinyin_num FROM caracteres "
        "WHERE (otras_lecturas IS NULL OR otras_lecturas = '') AND pinyin_num != ''"
    ).fetchall()
    con.close()
    lineas = sorted(f"{c} {p.lower()}" for c, p in filas if len(c) == 1 and c in grabados)
    (AUDIO / "lecturas.txt").write_text(
        "# Generado por herramientas_datos/listar_lecturas.py: carácter y sílaba de su grabación.\n"
        + "\n".join(lineas) + "\n",
        encoding="utf-8",
    )
    print(f"lecturas.txt: {len(lineas)} caracteres con grabación propia")


if __name__ == "__main__":
    main()
