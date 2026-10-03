// Pruebas de SesionEstudio con una "base de datos" falsa en memoria.
//   flutter test test/sesion_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/modelos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/sesion_estudio.dart';
import 'package:hanzi_dojo/datos/srs.dart';

Caracter _car(int id, {bool visto = false}) => Caracter(
      id: id,
      caracter: String.fromCharCode(0x4E00 + id),
      pinyin: 'yī',
      pinyinNum: 'yi1',
      otrasLecturas: '',
      significadoEs: 'uno',
      significadoEn: 'one',
      nivelHsk: 1,
      nivelEscritura: null,
      radical: 1,
      numTrazos: 1,
      esFormaRadical: false,
      progreso: visto
          ? Progreso(
              intervaloDias: 1,
              factor: 2.5,
              aciertosSeguidos: 1,
              vecesVisto: 1,
              proximoRepaso: DateTime(2000),
            )
          : null,
    );

/// Fuente falsa: [nuevos] caracteres nunca vistos, sin repasos vencidos.
class FuenteFalsa implements FuenteSesion {
  FuenteFalsa({required int nuevos, this.limite = 100})
      : _pendientes = [for (int i = 1; i <= nuevos; i++) i];

  final List<int> _pendientes;
  final int limite;
  final List<(int, Calificacion)> respuestas = [];
  int _nuevosHoy = 0;

  @override
  Future<Caracter?> siguiente(FiltroEstudio filtro,
      {required bool permitirNuevos, required Set<int> excluir}) async {
    if (!permitirNuevos) return null;
    final id = _pendientes.where((i) => !excluir.contains(i)).firstOrNull;
    return id == null ? null : _car(id);
  }

  @override
  Future<Caracter?> caracter(int id) async => _car(id, visto: true);

  @override
  Future<void> registrarRespuesta(Caracter c, Calificacion calificacion,
      {DetallePractica detalle = const DetallePractica()}) async {
    respuestas.add((c.id, calificacion));
    if (_pendientes.remove(c.id)) _nuevosHoy++;
  }

  @override
  Future<int> nuevosHoy() async => _nuevosHoy;
  @override
  Future<int> limiteNuevosPorDia() async => limite;
  @override
  Future<bool> quedanNuevos(FiltroEstudio filtro) async => _pendientes.isNotEmpty;
}

void main() {
  test('"Difícil" vuelve a salir después de 3 tarjetas', () async {
    final fuente = FuenteFalsa(nuevos: 10);
    final sesion = SesionEstudio(fuente, const FiltroEstudio.nivel(1));
    final vistos = <int>[];
    for (int i = 0; i < 6; i++) {
      final c = (await sesion.siguiente())!;
      vistos.add(c.id);
      await sesion.responder(c, i == 0 ? Calificacion.dificil : Calificacion.facil);
    }
    // 1 (difícil), 2, 3, 4 y entonces vuelve el 1.
    expect(vistos.take(5), [1, 2, 3, 4, 1]);
  });

  test('al llegar al límite diario termina con limiteDiario y "estudiar más" sigue', () async {
    final fuente = FuenteFalsa(nuevos: 5, limite: 2);
    final sesion = SesionEstudio(fuente, const FiltroEstudio.nivel(1));
    for (int i = 0; i < 2; i++) {
      await sesion.responder((await sesion.siguiente())!, Calificacion.facil);
    }
    expect(await sesion.siguiente(), isNull);
    expect(sesion.fin, FinSesion.limiteDiario);

    sesion.estudiarMas();
    expect(await sesion.siguiente(), isNotNull);
  });

  test('sin nada pendiente termina con completo', () async {
    final sesion = SesionEstudio(FuenteFalsa(nuevos: 1), const FiltroEstudio.nivel(1));
    await sesion.responder((await sesion.siguiente())!, Calificacion.facil);
    expect(await sesion.siguiente(), isNull);
    expect(sesion.fin, FinSesion.completo);
    expect(sesion.nuevasEnSesion, 1);
  });

  test('práctica de un solo carácter: se muestra una vez', () async {
    final sesion = SesionEstudio(FuenteFalsa(nuevos: 3), const FiltroEstudio.unico(2));
    final c = await sesion.siguiente();
    expect(c, isNotNull);
    await sesion.responder(c!, Calificacion.dificil);
    expect(await sesion.siguiente(), isNull);
    expect(sesion.fin, FinSesion.unicoTerminado);
  });
}
