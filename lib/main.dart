import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'inicio.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'databases/app_database.dart';
import 'databases/history_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AppDatabase.instance.database;
  HistoryDB.instance.depurarBaseDatosSeguro();
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