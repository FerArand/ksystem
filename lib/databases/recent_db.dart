import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class RecentDB {
  static final RecentDB instance = RecentDB._init();
  static Database? _database;

  RecentDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _database = await _initDB('ksystem_recent.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE recientes (
      codigo TEXT PRIMARY KEY, 
      fecha_agregado TEXT
    )
    ''');
  }

  // Guardar producto nuevo (o actualizar la fecha si ya existe)
  Future<void> agregarReciente(String codigo) async {
    final db = await database;
    final fecha = DateTime.now().toIso8601String();

    // Insert or Replace para actualizar la fecha si lo volvemos a añadir/editar
    await db.insert(
        'recientes',
        {'codigo': codigo, 'fecha_agregado': fecha},
        conflictAlgorithm: ConflictAlgorithm.replace
    );

    _limpiarAntiguos();
  }

  // Borrar los de más de 7 días
  Future<void> _limpiarAntiguos() async {
    final db = await database;
    final limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete('recientes', where: 'fecha_agregado < ?', whereArgs: [limite]);
  }

  // Obtener solo los códigos para luego buscar detalles en la BD principal
  Future<List<String>> obtenerCodigosRecientes() async {
    final db = await database;
    _limpiarAntiguos(); // Asegurar limpieza al consultar
    final res = await db.query('recientes', orderBy: 'fecha_agregado DESC');
    return res.map((e) => e['codigo'] as String).toList();
  }
}//