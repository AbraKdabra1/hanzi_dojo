import 'package:flutter/material.dart';
import 'database/db_helper.dart';
import 'screens/pantalla_inicio.dart'; // ← esta línea

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.poblarBaseDeDatos();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hanzi Dojo',
      theme: ThemeData(
        fontFamily: 'SFPro',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: PantallaInicio(),
    );
  }
}