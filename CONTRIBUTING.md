# Cómo colaborar con Hanzi Dojo

¡Gracias por querer ayudar! Hanzi Dojo es software libre (GPL-3.0) y mejora con
cada reporte.

## Reportar un problema o sugerir algo

- **Desde la app** (lo más fácil): Ajustes → **Reportar un problema**. El
  formulario de GitHub se abre ya lleno con la versión de la app y, si quieres,
  el informe de errores. Ves todo antes de enviarlo.
  - En la pantalla de estudio, la bandera 🚩 reporta un error en el carácter que
    estás escribiendo.
  - En «Leer», toca un carácter → **Reportar un error**.
- **Desde GitHub**: pestaña *Issues* → *New issue* → elige *Error de la app*,
  *Error en el contenido* o *Sugerencia*.

## Corregir el contenido

Todo el contenido son archivos de texto en `herramientas_datos/fuentes/`:

| Qué | Archivo |
|---|---|
| Significado en español de un carácter | `traducciones/significados_es.tsv` |
| Traducción de una oración de ejemplo | `traducciones/ejemplos_es.tsv` |
| Quitar una oración de ejemplo | agrega su número a `traducciones/ejemplos_excluidos.tsv` |
| Texto o traducción de un libro de «Leer» | `libros/*.txt` (formato en `herramientas_datos/libros.py`) |

Después de editar:

```bash
pip install pypinyin                              # solo si editaste un libro
python herramientas_datos/preparar_libros.py      # solo si editaste un libro
python herramientas_datos/construir_db.py
python herramientas_datos/validar_db.py
```

`validar_db.py` debe terminar con «✓ La base cumple con todo lo revisado».

### Libros de «Leer»

- Las historias de HSK 1 a 5 son clásicas (de dominio público) y están contadas
  de nuevo para la app: al menos el 90 % de sus caracteres debe ser del nivel
  del libro o menor (`preparar_libros.py` lo mide y dice cuáles se pasan).
- Solo textos libres de derechos: autores fallecidos hace más de 100 años.
- Nombres propios entre llaves `{孔融}` (basta una vez por libro); una lectura
  que el pinyin automático confunde, entre corchetes: `长[zhǎng]`.

## Programar

Requisitos: Flutter 3.44 (Dart 3.12).

```bash
flutter pub get
flutter analyze
flutter test
```

- El código y los comentarios están en español.
- Las pantallas no escriben SQL: todo pasa por `lib/datos/repositorio.dart`.
- Cada cambio de comportamiento lleva su prueba en `test/`.
- Haz tus cambios en una rama y abre un *pull request*; la integración continua
  revisa la base, el análisis, las pruebas y que el APK compile.

## Licencia

Al contribuir aceptas que tu aporte se publique bajo la misma licencia del
proyecto: **GPL-3.0 o posterior** para el código, y la licencia de su fuente
para los datos (CC BY-SA 4.0 para lo que deriva de CC-CEDICT, por ejemplo).
