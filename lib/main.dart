import 'inicio.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ksystem/db_helper.dart';
import 'package:ksystem/databases/sync_service.dart';
import 'package:ksystem/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await DBHelper.instance.depurarBaseDatosSeguro();

  unawaited(
    SyncService.instance.inicializar(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
  );

  runApp(const MyApp()); // Deja aquí el nombre exacto de tu clase principal
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KTOOLS - Ksystem',
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