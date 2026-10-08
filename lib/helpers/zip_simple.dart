// ─────────────────────────────────────────────────────────────────────────────
// zip_simple.dart — Lector mínimo de archivos ZIP (para abrir EPUB)
//
// Un EPUB es un ZIP. Para leerlo basta con:
//   1. Buscar al final del archivo el "directorio central" (la lista de
//      archivos que contiene, con su tamaño y dónde empieza cada uno).
//   2. Para cada archivo, saltar su encabezado local y tomar sus bytes:
//      guardados tal cual (método 0) o comprimidos con deflate (método 8),
//      que descomprime package:archive (Dart puro: sirve también en la web).
// No soporta ZIP64 (archivos de más de 4 GB) ni ZIP cifrados: un EPUB normal
// no los usa.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Inflate;

class ZipSimple {
  ZipSimple._();

  static const _firmaLocal = 0x04034b50;
  static const _firmaCentral = 0x02014b50;
  static const _firmaFin = 0x06054b50;

  /// ¿Empieza como un ZIP ("PK\x03\x04")?
  static bool esZip(Uint8List b) =>
      b.length >= 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04;

  /// Todos los archivos del ZIP: ruta → contenido. Lanza [FormatException]
  /// si el archivo está dañado.
  static Map<String, Uint8List> leer(Uint8List b) {
    final datos = ByteData.sublistView(b);
    int u16(int i) => datos.getUint16(i, Endian.little);
    int u32(int i) => datos.getUint32(i, Endian.little);

    // 1. Fin del directorio central: está en los últimos 22 bytes + comentario.
    var fin = -1;
    for (int i = b.length - 22; i >= 0 && i >= b.length - 22 - 0xFFFF; i--) {
      if (u32(i) == _firmaFin) {
        fin = i;
        break;
      }
    }
    if (fin < 0) throw const FormatException('No es un ZIP');
    final cuantos = u16(fin + 10);
    var p = u32(fin + 16);

    final salida = <String, Uint8List>{};
    for (int n = 0; n < cuantos; n++) {
      if (p + 46 > b.length || u32(p) != _firmaCentral) throw const FormatException('ZIP dañado');
      final metodo = u16(p + 10);
      final comprimido = u32(p + 20);
      final largoNombre = u16(p + 28);
      final largoExtra = u16(p + 30);
      final largoComentario = u16(p + 32);
      final local = u32(p + 42);
      final nombre = utf8.decode(b.sublist(p + 46, p + 46 + largoNombre), allowMalformed: true);
      p += 46 + largoNombre + largoExtra + largoComentario;

      if (nombre.endsWith('/')) continue; // carpeta
      if (local + 30 > b.length || u32(local) != _firmaLocal) throw const FormatException('ZIP dañado');
      final inicio = local + 30 + u16(local + 26) + u16(local + 28);
      if (inicio + comprimido > b.length) throw const FormatException('ZIP dañado');
      final bytes = b.sublist(inicio, inicio + comprimido);
      if (metodo == 0) {
        salida[nombre] = bytes;
      } else if (metodo == 8) {
        salida[nombre] = Uint8List.fromList(Inflate(bytes).getBytes());
      }
      // Otros métodos de compresión no se usan en EPUB: ese archivo se ignora.
    }
    return salida;
  }
}
