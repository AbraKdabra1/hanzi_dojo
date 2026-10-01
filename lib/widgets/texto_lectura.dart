// ─────────────────────────────────────────────────────────────────────────────
// texto_lectura.dart — Un párrafo de la sección «Leer» y la ficha de carácter
//
// ParrafoLectura dibuja el texto chino carácter por carácter, cada uno con su
// pinyin encima (como los libros para aprender chino). Se puede tocar
// cualquier carácter para ver su ficha: pinyin, significado, nivel HSK, oírlo
// y practicar su escritura.
//
// Cortes de línea: los signos de cierre (，。！？”…) se pegan al carácter de
// antes y los de apertura (“《（) al de después, para que ninguna línea
// empiece con una coma, como en cualquier texto chino bien compuesto.
//
// Los nombres propios van subrayados: así se ve que 孔融 es una persona y no
// dos palabras que tengas que conocer.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../screens/pantalla_estudio.dart';
import 'boton_voz.dart';
import 'comunes.dart';

/// Signos que nunca deben empezar una línea (se pegan al carácter anterior).
const _cierre = '，。！？；：、）》」』”’…—·.,!?;:)';

/// Signos que nunca deben terminar una línea (se pegan al siguiente).
const _apertura = '“‘《「『（(';

bool esHan(String c) {
  if (c.isEmpty) return false;
  final r = c.runes.first;
  return (r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF) || (r >= 0x20000 && r <= 0x2FFFF);
}

/// Agrupa las posiciones de [caracteres] en bloques que no se pueden partir
/// entre líneas: un carácter con la puntuación que lo acompaña.
List<List<int>> bloquesSinCorte(List<String> caracteres) {
  final bloques = <List<int>>[];
  final pendientes = <int>[]; // signos de apertura esperando su carácter
  for (int i = 0; i < caracteres.length; i++) {
    final c = caracteres[i];
    if (c.trim().isEmpty) continue;
    if (_cierre.contains(c) && bloques.isNotEmpty && pendientes.isEmpty) {
      bloques.last.add(i);
    } else if (_apertura.contains(c)) {
      pendientes.add(i);
    } else {
      bloques.add([...pendientes, i]);
      pendientes.clear();
    }
  }
  if (pendientes.isNotEmpty) bloques.add([...pendientes]);
  return bloques;
}

class ParrafoLectura extends StatelessWidget {
  const ParrafoLectura({
    super.key,
    required this.parrafo,
    required this.tamano,
    required this.mostrarPinyin,
    required this.mostrarTraduccion,
    required this.onAlternarTraduccion,
    this.seleccionado,
    required this.onTocarCaracter,
  });

  final ParrafoLibro parrafo;
  final double tamano;
  final bool mostrarPinyin;
  final bool mostrarTraduccion;
  final VoidCallback onAlternarTraduccion;

  /// Posición del carácter resaltado (el de la ficha abierta), si hay.
  final int? seleccionado;
  final ValueChanged<int> onTocarCaracter;

  @override
  Widget build(BuildContext context) {
    final p = parrafo;
    final tamanoPinyin = (tamano * 0.42).clamp(10.0, 15.0);
    final alturaPinyin = tamanoPinyin * 1.3;

    Widget celda(int i) {
      final c = p.caracteres[i];
      final han = esHan(c);
      final nombre = han && p.esNombre(i);
      final marcado = i == seleccionado;
      final texto = Text(
        c,
        style: TextStyle(
          fontSize: tamano,
          height: 1.25,
          color: Colors.black87,
          decoration: nombre ? TextDecoration.underline : null,
          decorationColor: const Color(0x99795548),
          decorationThickness: 1.5,
        ),
      );
      final columna = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mostrarPinyin)
            SizedBox(
              height: alturaPinyin,
              child: Text(
                p.pinyin[i],
                style: TextStyle(fontSize: tamanoPinyin, color: Colors.grey.shade600, height: 1.2),
              ),
            ),
          texto,
        ],
      );
      if (!han) return columna;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTocarCaracter(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: marcado ? const Color(0x40FFC107) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: columna,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          runSpacing: tamano * 0.3,
          children: [
            for (final bloque in bloquesSinCorte(p.caracteres))
              Row(mainAxisSize: MainAxisSize.min, children: [for (final i in bloque) celda(i)]),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: mostrarTraduccion
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    p.espanol,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.35),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BotonVoz(texto: p.chino, tamano: 16),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: mostrarTraduccion ? 'Ocultar traducción' : 'Ver traducción',
              icon: Icon(
                mostrarTraduccion ? Icons.translate : Icons.translate_outlined,
                size: 18,
                color: mostrarTraduccion ? Colors.black87 : Colors.black38,
              ),
              onPressed: onAlternarTraduccion,
            ),
          ],
        ),
      ],
    );
  }
}

/// Hoja inferior con la ficha de un carácter tocado en un libro.
class FichaCaracterLectura extends StatelessWidget {
  const FichaCaracterLectura({super.key, required this.texto, required this.pinyinEnTexto});

  /// El carácter tocado.
  final String texto;

  /// Cómo se lee en esta oración (puede ser distinto de su lectura principal:
  /// 长 = zhǎng en 长大).
  final String pinyinEnTexto;

  @override
  Widget build(BuildContext context) {
    final repo = DatosApp.de(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFAFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      child: FutureBuilder<Caracter?>(
        future: repo.caracterPorTexto(texto),
        builder: (context, instantanea) {
          final c = instantanea.data;
          final cargando = instantanea.connectionState != ConnectionState.done;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFBDBDBD), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(texto, style: const TextStyle(fontSize: 64, height: 1.1)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pinyinEnTexto,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: 1)),
                        if (c != null && c.pinyin != pinyinEnTexto && pinyinEnTexto.isNotEmpty)
                          Text('aquí; en el diccionario: ${c.pinyin}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Row(children: [
                          if (c != null) EtiquetaNivel(nivel: c.nivelHsk),
                          if (c != null) const SizedBox(width: 8),
                          if (c != null)
                            Text(c.progreso == null ? 'Nuevo para ti' : 'Ya lo estudias',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ]),
                      ],
                    ),
                  ),
                  BotonVoz(texto: texto),
                ],
              ),
              const SizedBox(height: 14),
              if (cargando)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54)),
                )
              else if (c == null)
                Text('Este carácter no está en la base de la app.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700))
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: TextoSignificado(caracter: c, maxLineas: 4, tamano: 16),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Practicar su escritura'),
                    onPressed: () {
                      // Se toma el Navigator antes de cerrar la hoja: después
                      // su contexto ya no sirve para abrir otra pantalla.
                      final navegador = Navigator.of(context);
                      navegador.pop();
                      navegador.push(
                        MaterialPageRoute<void>(
                          builder: (_) => PantallaEstudio(
                            filtro: FiltroEstudio.unico(c.id),
                            modoNovato: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
