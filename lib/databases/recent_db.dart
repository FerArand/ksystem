import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../models/producto.dart';
import '../db_helper.dart';
import 'package:flutter/foundation.dart';

class RecentDB {
  static final RecentDB instance = RecentDB._init();

  RecentDB._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> agregarReciente(String codigo) async {
    final db = await _db;
    final fecha = DateTime.now().toIso8601String();
    await db.insert('recientes',
        {'codigo': codigo, 'fecha_agregado': fecha},
        conflictAlgorithm: ConflictAlgorithm.replace
    );
    _limpiarAntiguos().catchError((e) => debugPrint('[RecentDB] Limpieza: $e'));
  }

  Future<List<Producto>> obtenerProductosRecientesCompletos() async {
    final codigos = await obtenerCodigosRecientes();
    if (codigos.isEmpty) return [];

    final resultados = await Future.wait(
      codigos.map((codigo) => DBHelper.instance.getProductoPorCodigo(codigo)),
    );

    return resultados
        .whereType<Map<String, dynamic>>()
        .map(Producto.desdeMapa)
        .toList();
  }

  Future<List<String>> obtenerCodigosRecientes() async {
    final db = await _db;
    await _limpiarAntiguos();
    final res = await db.query('recientes', orderBy: 'fecha_agregado DESC');
    return res.map((e) => e['codigo'] as String).toList();
  }

  Future<void> _limpiarAntiguos() async {
    final db = await _db;
    final limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete('recientes', where: 'fecha_agregado < ?', whereArgs: [limite]);
  }
}
