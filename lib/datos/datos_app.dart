// ─────────────────────────────────────────────────────────────────────────────
// datos_app.dart — Da acceso al Repositorio desde cualquier pantalla
//
// Se coloca una vez arriba de toda la app (ver main.dart). Cualquier pantalla
// obtiene el repositorio con:   final repo = DatosApp.de(context);
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';

import 'repositorio.dart';

class DatosApp extends InheritedWidget {
  const DatosApp({super.key, required this.repo, required super.child});

  final Repositorio repo;

  static Repositorio de(BuildContext context) {
    final datos = context.getInheritedWidgetOfExactType<DatosApp>();
    assert(datos != null, 'DatosApp no está arriba de esta pantalla');
    return datos!.repo;
  }

  @override
  bool updateShouldNotify(DatosApp old) => !identical(old.repo, repo);
}
