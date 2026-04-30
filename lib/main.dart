import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <--- 1. Importar esto
import 'services/migration_service.dart';
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

  // Abrimos nueva BD primero (crea tablas si no existen)
  await AppDatabase.instance.database;

  // Ejecutamos migración si es la primera vez
  try {
    await MigrationService.ejecutarSiNecesario();
  } catch (e) {
    // En producción: muestra diálogo de error en lugar de crashear
    runApp(_AppError(mensaje: e.toString()));
    return;
  }

  HistoryDB.instance.depurarBaseDatosSeguro();
  runApp(const MyApp());
}

// Widget mínimo de error para mostrar al usuario si la migración falla
class _AppError extends StatelessWidget {
  final String mensaje;
  const _AppError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error al migrar datos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(mensaje, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                const Text(
                  'No se perdió ningún dato. Reinicia el ksystem. '
                      'Si el error persiste, contacta a Ferpleis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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