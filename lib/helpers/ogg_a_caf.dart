// ─────────────────────────────────────────────────────────────────────────────
// ogg_a_caf.dart — Opus en Ogg → Opus en CAF, en memoria y sin recodificar
//
// Las grabaciones de la app son Opus dentro de Ogg (.opus). iPhone, iPad y
// Safari no leen el contenedor Ogg, pero sí el mismo Opus dentro de CAF (Core
// Audio Format, de Apple). Aquí solo se cambia la "caja": los paquetes de
// audio pasan tal cual, así que la calidad y el peso no cambian.
//
// Ogg (lo que entra), RFC 3533 y RFC 7845:
//   páginas "OggS"; cada una trae una tabla de segmentos (0-255 bytes). Un
//   paquete termina en el primer segmento de menos de 255 (puede seguir en la
//   página siguiente). Paquete 1 = OpusHead (canales, pre-skip), paquete 2 =
//   OpusTags, el resto = audio. La posición final (granule) dice cuántas
//   muestras valen.
//
// CAF (lo que sale), números en big-endian:
//   "caff" v1, luego bloques [tipo de 4 letras][tamaño de 8 bytes][contenido]:
//   desc  formato: 48 kHz, 'opus', N muestras por paquete, canales
//   chan  mono o estéreo
//   pakt  cuántos paquetes, muestras válidas, pre-skip, sobrantes y el tamaño
//         de cada paquete (enteros de 7 bits por byte)
//   data  los paquetes, uno tras otro
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

class OggACaf {
  OggACaf._();

  /// Convierte un archivo Ogg Opus completo en uno CAF. Lanza
  /// [FormatException] si no es Ogg Opus.
  static Uint8List convertir(Uint8List ogg) {
    final paquetes = <Uint8List>[];
    var granuloFinal = 0;
    final actual = BytesBuilder(copy: false);
    var i = 0;
    while (i + 27 <= ogg.length) {
      if (ogg[i] != 0x4F || ogg[i + 1] != 0x67 || ogg[i + 2] != 0x67 || ogg[i + 3] != 0x53) {
        throw const FormatException('No es un archivo Ogg');
      }
      // Posición (64 bits, little-endian) leída en dos mitades: getInt64 no
      // existe en la web. Todo en 1 = "ningún paquete termina aquí".
      final vista = ByteData.sublistView(ogg, i);
      final bajo = vista.getUint32(6, Endian.little), alto = vista.getUint32(10, Endian.little);
      if (!(bajo == 0xFFFFFFFF && alto == 0xFFFFFFFF)) granuloFinal = alto * 0x100000000 + bajo;
      final segmentos = ogg[i + 26];
      var j = i + 27 + segmentos;
      if (j > ogg.length) throw const FormatException('Página Ogg incompleta');
      for (var s = 0; s < segmentos; s++) {
        final largo = ogg[i + 27 + s];
        if (j + largo > ogg.length) throw const FormatException('Página Ogg incompleta');
        actual.add(Uint8List.sublistView(ogg, j, j + largo));
        j += largo;
        if (largo < 255) paquetes.add(actual.takeBytes());
      }
      i = j;
    }
    if (paquetes.length < 3) throw const FormatException('Ogg sin audio');
    final cabecera = paquetes[0];
    if (cabecera.length < 19 || String.fromCharCodes(cabecera.sublist(0, 8)) != 'OpusHead') {
      throw const FormatException('No es Opus');
    }
    final canales = cabecera[9];
    final preSkip = ByteData.sublistView(cabecera).getUint16(10, Endian.little);
    final audio = paquetes.sublist(2); // sin OpusHead ni OpusTags

    final muestras = [for (final p in audio) muestrasDePaquete(p)];
    final fijo = muestras.every((m) => m == muestras.first) ? muestras.first : 0;
    final total = muestras.fold<int>(0, (a, b) => a + b);
    final validas = (granuloFinal - preSkip).clamp(0, total - preSkip);
    final sobrantes = total - preSkip - validas;

    final salida = BytesBuilder(copy: false);
    void u16(int v) => salida.add((ByteData(2)..setUint16(0, v)).buffer.asUint8List());
    void u32(int v) => salida.add((ByteData(4)..setUint32(0, v)).buffer.asUint8List());
    void i32(int v) => salida.add((ByteData(4)..setInt32(0, v)).buffer.asUint8List());
    void i64(int v) => salida.add((ByteData(8)
          ..setUint32(0, v ~/ 0x100000000)
          ..setUint32(4, v % 0x100000000))
        .buffer
        .asUint8List());
    void texto(String s) => salida.add(s.codeUnits);
    void bloque(String tipo, int tamano) {
      texto(tipo);
      i64(tamano);
    }

    // Cabecera del archivo.
    texto('caff');
    u16(1);
    u16(0);

    // desc: formato del audio.
    bloque('desc', 32);
    salida.add((ByteData(8)..setFloat64(0, 48000)).buffer.asUint8List());
    texto('opus');
    u32(0); // banderas
    u32(0); // bytes por paquete: varía
    u32(fijo); // muestras por paquete (0 = varía, va en la tabla)
    u32(canales);
    u32(0); // bits por canal: no aplica

    // chan: mono (100 << 16 | 1) o estéreo (101 << 16 | 2).
    bloque('chan', 12);
    u32(canales == 2 ? 6619138 : 6553601);
    u32(0);
    u32(0);

    // pakt: la tabla de paquetes.
    final tabla = BytesBuilder(copy: false);
    for (var k = 0; k < audio.length; k++) {
      tabla.add(entero7(audio[k].length));
      if (fijo == 0) tabla.add(entero7(muestras[k]));
    }
    final entradas = tabla.takeBytes();
    bloque('pakt', 24 + entradas.length);
    i64(audio.length);
    i64(validas);
    i32(preSkip);
    i32(sobrantes);
    salida.add(entradas);

    // data: los paquetes tal cual.
    final bytesAudio = audio.fold<int>(0, (a, p) => a + p.length);
    bloque('data', 4 + bytesAudio);
    u32(0); // número de edición
    for (final p in audio) {
      salida.add(p);
    }
    return salida.takeBytes();
  }

  /// Cuántas muestras (a 48 kHz) trae un paquete Opus, según su primer byte
  /// (RFC 6716, sección 3.1).
  static int muestrasDePaquete(Uint8List p) {
    if (p.isEmpty) return 0;
    final toc = p[0];
    final config = toc >> 3;
    final int porTrama; // muestras de cada trama
    if (config < 12) {
      porTrama = const [480, 960, 1920, 2880][config & 3]; // SILK: 10/20/40/60 ms
    } else if (config < 16) {
      porTrama = const [480, 960][config & 1]; // híbrido: 10/20 ms
    } else {
      porTrama = const [120, 240, 480, 960][config & 3]; // CELT: 2.5/5/10/20 ms
    }
    final tramas = switch (toc & 3) {
      0 => 1,
      1 || 2 => 2,
      _ => p.length > 1 ? p[1] & 0x3F : 0,
    };
    return porTrama * tramas;
  }

  /// Entero de CAF: 7 bits por byte, el más significativo primero; el bit
  /// alto dice "sigue otro byte".
  static Uint8List entero7(int v) {
    final grupos = <int>[v & 0x7F];
    v >>= 7;
    while (v > 0) {
      grupos.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    return Uint8List.fromList(grupos.reversed.toList());
  }
}
