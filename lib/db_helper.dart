import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _database = await _initDB('ksystem_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    // Incrementamos versión para asegurar cambios si usas onUpgrade (aquí usamos onCreate básico)
    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE productos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codigo TEXT UNIQUE,
      sku TEXT, 
      factura TEXT,
      descripcion TEXT,
      marca TEXT,
      costo REAL,
      precio REAL,
      precioRappi REAL,
      stock INTEGER,
      borrado INTEGER DEFAULT 0
    )
    ''');

    await db.execute('''
    CREATE TABLE ventas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      total REAL,
      recibido REAL,
      cambio REAL,
      cliente TEXT,
      items TEXT 
    )
    ''');

    await db.execute('''
    CREATE TABLE historial_ingresos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codigo_producto TEXT,
      cantidad INTEGER,
      fecha_ingreso TEXT,
      accion TEXT
    )
    ''');
  }

  // --- CRUD ---
  Future<int> insertProducto(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('productos', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProductoPorCodigo(String codigo) async {
    final db = await database;
    final maps = await db.query(
      'productos',
      where: 'codigo = ?',
      whereArgs: [codigo],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> buscarProductos(String query) async {
    final db = await database;
    return await db.query(
      'productos',
      where: 'descripcion LIKE ? OR codigo LIKE ? OR sku LIKE ? OR factura LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
    );
  }

  Future<int> updateStock(String codigo, int cantidadSumar) async {
    final db = await database;
    final prod = await getProductoPorCodigo(codigo);
    if (prod == null) return 0;
    int nuevoStock = prod['stock'] + cantidadSumar;
    return await db.update('productos', {'stock': nuevoStock}, where: 'id = ?', whereArgs: [prod['id']]);
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertVenta(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('ventas', row);
  }

  Future<int> vincularCodigo(int idProducto, String nuevoCodigo) async {
    final db = await database;
    return await db.update('productos', {'codigo': nuevoCodigo}, where: 'id = ?', whereArgs: [idProducto]);
  }
  // --- ACTUALIZAR PRODUCTO COMPLETO ---
  Future<int> updateProducto(Map<String, dynamic> row) async {
    final db = await database;
    int id = row['id'];
    return await db.update(
      'productos',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}