import 'dart:math' as math;
import 'package:flutter/material.dart';

class DTWHelper {
  // Distancia euclidiana entre dos puntos
  static double _distancia(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  // Reduce una lista de puntos a N puntos equidistantes
  static List<Offset> _normalizar(List<Offset> puntos, int n) {
    if (puntos.length <= 1) return puntos;
    
    // Calcular longitud total del trazo
    double longitudTotal = 0;
    for (int i = 1; i < puntos.length; i++) {
      longitudTotal += _distancia(puntos[i - 1], puntos[i]);
    }

    final double paso = longitudTotal / (n - 1);
    final List<Offset> resultado = [puntos.first];
    double acumulado = 0;
    int j = 0;

    for (int i = 1; i < n - 1; i++) {
      final double objetivo = paso * i;
      while (j < puntos.length - 2 &&
          acumulado + _distancia(puntos[j], puntos[j + 1]) < objetivo) {
        acumulado += _distancia(puntos[j], puntos[j + 1]);
        j++;
      }
      final double resto = objetivo - acumulado;
      final double segmento = _distancia(puntos[j], puntos[j + 1]);
      final double t = segmento == 0 ? 0 : resto / segmento;
      resultado.add(Offset(
        puntos[j].dx + t * (puntos[j + 1].dx - puntos[j].dx),
        puntos[j].dy + t * (puntos[j + 1].dy - puntos[j].dy),
      ));
    }

    resultado.add(puntos.last);
    return resultado;
  }

  // Algoritmo DTW — devuelve el costo normalizado (menor = más similar)
  static double calcular(List<Offset> trazoUsuario, List<Offset> trazoEsperado) {
    const int n = 16; // Puntos de comparación
    final List<Offset> a = _normalizar(trazoUsuario, n);
    final List<Offset> b = _normalizar(trazoEsperado, n);

    // Matriz de costos
    final List<List<double>> matriz = List.generate(
      n, (_) => List.filled(n, double.infinity));
    matriz[0][0] = _distancia(a[0], b[0]);

    for (int i = 1; i < n; i++) {
      matriz[i][0] = matriz[i - 1][0] + _distancia(a[i], b[0]);
    }
    for (int j = 1; j < n; j++) {
      matriz[0][j] = matriz[0][j - 1] + _distancia(a[0], b[j]);
    }
    for (int i = 1; i < n; i++) {
      for (int j = 1; j < n; j++) {
        final double costo = _distancia(a[i], b[j]);
        matriz[i][j] = costo + [
          matriz[i - 1][j],
          matriz[i][j - 1],
          matriz[i - 1][j - 1],
        ].reduce(math.min);
      }
    }

    // Normalizar por longitud del camino
    return matriz[n - 1][n - 1] / n;
  }
}