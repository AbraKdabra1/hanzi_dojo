// Fuera de la web no se usa (ver reproductor.dart): ahí suena just_audio.

typedef Pista = ({String? url, int pausaMs});

class ReproductorWeb {
  ReproductorWeb._();

  static Never _no() => throw UnsupportedError('Solo en la versión web');

  static String urlDeAsset(String ruta) => _no();
  static Future<bool> tocar(List<Pista> pistas, {double rapidez = 1, void Function(int indice)? alCambiar}) async =>
      _no();
  static void detener() {}
  static void pausar() {}
  static void reanudar() {}
  static void velocidad(double rapidez) {}
  static void registrarPrueba(Future<bool> Function() tocar) {}
}
