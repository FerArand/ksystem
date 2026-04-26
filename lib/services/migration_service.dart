import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../databases/app_database.dart';

class MigrationService {

  static const String _flagKey = 'migration_v1_done';

  // Punto de entrada. Llamas esto desde main.dart.
  static Future<void> ejecutarSiNecesario() async {
    final prefs = await SharedPreferences.getInstance();
    final yaMigrado = prefs.getBool(_flagKey) ?? false;

    if (yaMigrado) return; // Nada que hacer

    debugPrint('[Migración] Iniciando migración de datos...');

    try {
      await _migrar();
      await prefs.setBool(_flagKey, true); // Solo se activa si _migrar() no lanzó excepción
      debugPrint('[Migración] Completada exitosamente.');
    } catch (e) {
      // NO ponemos el flag. El próximo arranque lo reintentará.
      debugPrint('[Migración] FALLÓ: $e');
      rethrow; // Dejar que main.dart lo maneje y muestre error al usuario
    }
  }

  static Future<void> _migrar() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final newDb = await AppDatabase.instance.database;

    // Migramos tabla por tabla, en orden.
    await _migrarProductos(docsDir.path, newDb);
    await _migrarHistorial(docsDir.path, newDb);
    await _migrarDeudores(docsDir.path, newDb);
    await _migrarRecientes(docsDir.path, newDb);

    // Renombramos los viejos a .bak (no borrar aún)
    await _archivarViejos(docsDir.path);
  }

  // --- MIGRACIÓN DE CADA TABLA ---

  static Future<void> _migrarProductos(String dirPath, Database newDb) async {
    final oldPath = join(dirPath, 'ksystem_local.db');
    if (!await File(oldPath).exists()) {
      debugPrint('[Migración] ksystem_local.db no encontrado, omitiendo.');
      return;
    }

    final oldDb = await _abrirSoloLectura(oldPath);

    try {
      final filas = await oldDb.query('productos');
      debugPrint('[Migración] Productos encontrados: ${filas.length}');

      // Usamos transacción para que sea atómico
      await newDb.transaction((txn) async {
        for (final fila in filas) {
          await txn.insert(
            'productos',
            fila,
            conflictAlgorithm: ConflictAlgorithm.ignore, // Si ya existe, no falla
          );
        }
      });

      // Verificación: conteo debe cuadrar
      final countNuevo = Sqflite.firstIntValue(
          await newDb.rawQuery('SELECT COUNT(*) FROM productos')
      ) ?? 0;

      if (countNuevo < filas.length) {
        throw Exception('Productos: esperaba ${filas.length}, llegaron $countNuevo');
      }

    } finally {
      await oldDb.close();
    }
  }

  static Future<void> _migrarHistorial(String dirPath, Database newDb) async {
    final oldPath = join(dirPath, 'ksystem_history_v2.db');
    if (!await File(oldPath).exists()) return;

    final oldDb = await _abrirSoloLectura(oldPath);

    try {
      final filas = await oldDb.query('ventas_historial');
      debugPrint('[Migración] Ventas historial encontradas: ${filas.length}');

      await newDb.transaction((txn) async {
        for (final fila in filas) {
          await txn.insert(
            'ventas_historial',
            fila,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

    } finally {
      await oldDb.close();
    }
  }

  static Future<void> _migrarDeudores(String dirPath, Database newDb) async {
    final oldPath = join(dirPath, 'ksystem_debts.db');
    if (!await File(oldPath).exists()) return;

    final oldDb = await _abrirSoloLectura(oldPath);

    try {
      final filas = await oldDb.query('deudores');
      debugPrint('[Migración] Deudores encontrados: ${filas.length}');

      await newDb.transaction((txn) async {
        for (final fila in filas) {
          await txn.insert(
            'deudores',
            fila,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

    } finally {
      await oldDb.close();
    }
  }

  static Future<void> _migrarRecientes(String dirPath, Database newDb) async {
    final oldPath = join(dirPath, 'ksystem_recent.db');
    if (!await File(oldPath).exists()) return;

    final oldDb = await _abrirSoloLectura(oldPath);

    try {
      final filas = await oldDb.query('recientes');
      debugPrint('[Migración] Recientes encontrados: ${filas.length}');

      await newDb.transaction((txn) async {
        for (final fila in filas) {
          await txn.insert(
            'recientes',
            fila,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

    } finally {
      await oldDb.close();
    }
  }

  // --- UTILIDADES ---

  static Future<Database> _abrirSoloLectura(String path) async {
    return await openDatabase(
      path,
      readOnly: true, // Garantiza que no modificamos nada en los viejos
    );
  }

  static Future<void> _archivarViejos(String dirPath) async {
    final archivos = [
      'ksystem_local.db',
      'ksystem_history_v2.db',
      'ksystem_debts.db',
      'ksystem_recent.db',
    ];

    for (final nombre in archivos) {
      final archivo = File(join(dirPath, nombre));
      if (await archivo.exists()) {
        // Renombrar a .bak, no borrar
        await archivo.rename(join(dirPath, '$nombre.bak'));
        debugPrint('[Migración] Archivado: $nombre → $nombre.bak');
      }
    }
  }
}