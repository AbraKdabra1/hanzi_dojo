import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'database/db_helper.dart';

void main() async {
  // Aseguramos que Flutter espere a la base de datos
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint("Revisando la bóveda de Hanzi...");
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Hanzi Dojo - Alpha'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // 1. Estado Inicial
  String _hanzi = '⛩️';
  String _pinyin = 'Bienvenido al Dojo';
  String _significado = 'Presiona el botón para tu primer Hanzi';

  // 2. Función de extracción a la base de datos
  void _mostrarNuevoHanzi() async {
    final hanziAlAzar = await DatabaseHelper.instance.obtenerHanziAlAzar();
    
    if (hanziAlAzar != null) {
      setState(() {
        _hanzi = hanziAlAzar['simplificado'];
        _pinyin = hanziAlAzar['pinyin'];
        _significado = hanziAlAzar['significados'];
      });
    }
  }

  // 3. El Diseño Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _hanzi,
                style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Text(
                _pinyin,
                style: const TextStyle(fontSize: 28, color: Colors.blueGrey),
              ),
              const SizedBox(height: 15),
              Text(
                _significado,
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarNuevoHanzi,
        tooltip: 'Siguiente Hanzi',
        child: const Icon(Icons.navigate_next),
      ),
    );
  }
}