import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <--- 1. Importar esto
import 'inicio.dart';

void main() async { // <--- 2. Convertir main a async
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inicializar los datos de formato para Español (México)
  // Esto carga los nombres de los días y meses en español
  await initializeDateFormatting('es_MX', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KTOOLS Inventory Local',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.lightBlue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const Inicio(),
    );
  }
}