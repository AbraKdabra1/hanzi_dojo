// ─────────────────────────────────────────────────────────────────────────────
// pantalla_biblioteca.dart — «Leer»: los libros, agrupados por nivel HSK
//
// Hay tres tipos de libro:
//   · Adaptados: historias clásicas chinas (de dominio público) contadas de
//     nuevo para la app con los caracteres de su nivel.
//   · Originales: textos clásicos tal cual, con traducción (niveles altos).
//   · Mis libros: los que agregas tú (TXT, EPUB o texto pegado). Se quedan
//     solo en el teléfono; la app estima su nivel HSK y calcula el pinyin
//     (ver importar_libro.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/importar_libro.dart';
import '../datos/modelos.dart';
import '../datos/registro_errores.dart';
import '../helpers/archivos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_libro.dart';

class PantallaBiblioteca extends StatefulWidget {
  const PantallaBiblioteca({super.key});

  @override
  State<PantallaBiblioteca> createState() => _PantallaBibliotecaState();
}

class _PantallaBibliotecaState extends State<PantallaBiblioteca> {
  List<Libro>? _libros;
  List<Libro> _misLibros = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final libros = await repo.libros();
    final mios = await repo.misLibros();
    if (mounted) {
      setState(() {
        _libros = libros;
        _misLibros = mios;
      });
    }
  }

  Future<void> _abrir(Libro libro) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PantallaLibro(libro: libro)));
    _cargar(); // al volver, actualizar lo leído
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ── Agregar un libro ────────────────────────────────────────────────────

  Future<void> _agregar() async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (contexto) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFAFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(8, 12, 8, MediaQuery.of(contexto).padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Agregar un libro', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Abrir un archivo'),
              subtitle: const Text('TXT (UTF-8 o GBK) o EPUB sin protección'),
              onTap: () => Navigator.pop(contexto, 'archivo'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('Pegar un texto'),
              subtitle: const Text('Un artículo, un cuento, la letra de una canción…'),
              onTap: () => Navigator.pop(contexto, 'texto'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Tus libros se quedan solo en este teléfono. La app calcula el pinyin y estima '
                'su nivel HSK.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    if (opcion == 'archivo') {
      await _importarArchivo();
    } else {
      await _pegarTexto();
    }
  }

  Future<void> _importarArchivo() async {
    final ArchivoAbierto? archivo;
    try {
      archivo = await Archivos.abrir();
    } catch (e, pila) {
      RegistroErrores.registrar('Mis libros', e, pila);
      _aviso('No se pudo abrir el selector de archivos: $e');
      return;
    }
    if (archivo == null) return;
    final nombre = archivo.nombre;
    final bytes = archivo.bytes;
    await _preparar(
      archivo: nombre,
      peticion: (tabla, diccionario) => PeticionLibro.archivo(nombre, bytes, tabla, diccionario),
    );
  }

  Future<void> _pegarTexto() async {
    final titulo = TextEditingController();
    final texto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Pegar un texto'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titulo,
                decoration: const InputDecoration(labelText: 'Título (opcional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: texto,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Texto en chino',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Agregar')),
        ],
      ),
    );
    final t = titulo.text;
    final x = texto.text;
    titulo.dispose();
    texto.dispose();
    if (ok != true) return;
    await _preparar(archivo: '', peticion: (_, diccionario) => PeticionLibro.texto(t, x, diccionario));
  }

  /// Lee, prepara (en otro isolate) y guarda un libro, con un aviso de espera.
  Future<void> _preparar({
    required String archivo,
    required PeticionLibro Function(String tablaGbk, DiccionarioLectura diccionario) peticion,
  }) async {
    final repo = DatosApp.de(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Expanded(child: Text('Preparando tu libro…')),
        ]),
      ),
    );
    var cerrado = false;
    void cerrarEspera() {
      if (!cerrado && mounted) Navigator.of(context, rootNavigator: true).pop();
      cerrado = true;
    }

    try {
      final tabla = await repo.tablaGbk();
      final diccionario = await repo.diccionarioLectura();
      // En otro isolate: un libro largo tarda unos segundos en partirse.
      final preparado = await compute(prepararLibro, peticion(tabla, diccionario));
      final id = await repo.guardarLibroPropio(preparado, archivo: archivo);
      cerrarEspera();
      await _cargar();
      final nivel = preparado.nivelEstimado == 0
          ? 'más difícil que HSK 7-9'
          : 'nivel estimado ${nombreDeNivel(preparado.nivelEstimado)}';
      _aviso('Agregado: ${preparado.libro.titulo} · ${preparado.libro.capitulos.length} capítulos · $nivel');
      final libro = await repo.miLibro(id);
      if (libro != null && mounted) _abrir(libro);
    } on LibroInvalido catch (e) {
      cerrarEspera();
      _aviso(e.mensaje);
    } catch (e, pila) {
      cerrarEspera();
      RegistroErrores.registrar('Mis libros', e, pila);
      _aviso('No se pudo agregar el libro: $e');
    }
  }

  Future<void> _borrar(Libro libro) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar este libro?'),
        content: Text('«${libro.titulo}» se borrará del teléfono, con lo que llevas leído. '
            'Tu archivo original no se toca.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await DatosApp.de(context).borrarLibroPropio(libro.id);
    await _cargar();
  }

  // ── Pantalla ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final libros = _libros;
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Leer', subtitulo: 'Libros graduados por nivel HSK'),
        body: libros == null
            ? const Center(child: CircularProgressIndicator(color: Colors.black54))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      'Toca cualquier carácter para ver su significado y practicarlo. '
                      'Los nombres propios van subrayados.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                    ),
                  ),
                  for (final (i, libro) in libros.indexed) ...[
                    if (i == 0 || libros[i - 1].nivelHsk != libro.nivelHsk)
                      _Encabezado(texto: nombreDeNivel(libro.nivelHsk), color: EtiquetaNivel.colorDe(libro.nivelHsk)),
                    _TarjetaLibro(libro: libro, onTap: () => _abrir(libro)),
                    const SizedBox(height: 10),
                  ],
                  _Encabezado(
                    texto: 'MIS LIBROS',
                    color: Colors.black87,
                    accion: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar'),
                      onPressed: _agregar,
                    ),
                  ),
                  if (_misLibros.isEmpty)
                    TarjetaVidrio(
                      onTap: _agregar,
                      child: Row(
                        children: [
                          const Icon(Icons.library_add_outlined, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Agrega tus propios textos en chino: archivos TXT o EPUB sin '
                              'protección, o un texto que pegues. Se quedan solo en tu teléfono.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final libro in _misLibros) ...[
                      _TarjetaLibro(libro: libro, onTap: () => _abrir(libro), onBorrar: () => _borrar(libro)),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.texto, required this.color, this.accion});

  final String texto;
  final Color color;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, accion == null ? 8 : 12, 0, accion == null ? 8 : 2),
      child: Row(
        children: [
          Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, color: color)),
          ),
          if (accion case final a?) a,
        ],
      ),
    );
  }
}

class _TarjetaLibro extends StatelessWidget {
  const _TarjetaLibro({required this.libro, required this.onTap, this.onBorrar});

  final Libro libro;
  final VoidCallback onTap;

  /// Solo libros propios: menú con "Borrar".
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    final color = libro.propio ? const Color(0xFF5D4037) : EtiquetaNivel.colorDe(libro.nivelHsk);
    final nivel = libro.propio
        ? (libro.nivelHsk == 0 ? ' · más difícil que HSK 7-9' : ' · ${nombreDeNivel(libro.nivelHsk)} aprox.')
        : '';
    return TarjetaVidrio(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortadaLibro(libro: libro, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libro.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: libro.propio ? 17 : 20, fontWeight: FontWeight.w600)),
                if (libro.tituloPinyin.isNotEmpty)
                  Text(libro.tituloPinyin, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (libro.tituloEs.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(libro.tituloEs, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 6),
                Text(
                  '${tipoDeLibro(libro)} · ${libro.capitulos} '
                  '${libro.capitulos == 1 ? 'capítulo' : 'capítulos'}$nivel',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                BarraAvance(valor: libro.capitulosLeidos, total: libro.capitulos, color: color),
              ],
            ),
          ),
          if (onBorrar != null)
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              icon: const Icon(Icons.more_vert, color: Colors.black45),
              onSelected: (_) => onBorrar!(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'borrar', child: Text('Borrar'))],
            ),
        ],
      ),
    );
  }
}

/// "Portada" sencilla: el primer carácter del título en un recuadro del
/// color del nivel, como el sello de un libro.
class PortadaLibro extends StatelessWidget {
  const PortadaLibro({super.key, required this.libro, required this.color, this.tamano = 56});

  final Libro libro;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final inicial = libro.titulo.characters.isEmpty ? '书' : libro.titulo.characters.first;
    return Container(
      width: tamano,
      height: tamano * 1.3,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Text(
        inicial,
        style: TextStyle(fontSize: tamano * 0.55, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
