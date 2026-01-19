import 'package:flutter/material.dart';
import 'inicio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Aquí ya no inicializamos Firebase
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
      home: const Inicio(), // Va directo al Inicio, sin Login
    );
  }
}