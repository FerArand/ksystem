import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../models/producto.dart';
import '../db_helper.dart'; // Necesario para buscar los datos completos
import 'package:flutter/foundation.dart';

class RecentDB {
  static final RecentDB instance = RecentDB._init();

  RecentDB._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  // Guardar producto nuevo (o actualizar la fecha si ya existe)
  Future<void> agregarReciente(String codigo) async {
    final db = await _db;
    final fecha = DateTime.now().toIso8601String();
    await db.insert('recientes',
        {'codigo': codigo, 'fecha_agregado': fecha},
        conflictAlgorithm: ConflictAlgorithm.replace
    );
    // Fire-and-forget intencional: si falla al limpiar después
    // de insertar, no es crítico. El siguiente ciclo lo limpiará.
    _limpiarAntiguos().catchError((e) => debugPrint('[RecentDB] Limpieza: $e'));
  }

  // NUEVO: Método centralizado que devuelve los productos ya armados
  Future<List<Producto>> obtenerProductosRecientesCompletos() async {
    final codigos = await obtenerCodigosRecientes();
    if (codigos.isEmpty) return [];

    // Ejecutamos en paralelo (rápido y eficiente)
    final resultados = await Future.wait(
      codigos.map((codigo) => DBHelper.instance.getProductoPorCodigo(codigo)),
    );

    // Filtramos los nulos (productos borrados) y convertimos a objetos Producto
    return resultados
        .whereType<Map<String, dynamic>>()
        .map(Producto.desdeMapa)
        .toList();
  }

  Future<List<String>> obtenerCodigosRecientes() async {
    final db = await _db;
    // Aquí SÍ esperamos: necesitamos que la limpieza termine
    // ANTES de hacer el query, si no devolvemos basura.
    await _limpiarAntiguos();
    final res = await db.query('recientes', orderBy: 'fecha_agregado DESC');
    return res.map((e) => e['codigo'] as String).toList();
  }

  // Borrar los de más de 7 días
  Future<void> _limpiarAntiguos() async {
    final db = await _db;
    final limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete('recientes', where: 'fecha_agregado < ?', whereArgs: [limite]);
  }
}//