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
    // Inicializar ffi para escritorio (Windows/Linux)
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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Tabla Productos
    await db.execute('''
    CREATE TABLE productos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codigo TEXT UNIQUE,
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

    // Tabla Ventas
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

    // Tabla Historial Ingresos (Para lo de los 3 días)
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

  // --- CRUD PRODUCTOS ---

  Future<int> insertProducto(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('productos', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProductoPorCodigo(String codigo) async {
    final db = await database;
    final maps = await db.query(
      'productos',
      where: 'codigo = ? OR factura = ?', // Busca por código de barras o factura antigua
      whereArgs: [codigo, codigo],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Búsqueda por nombre (LIKE)
  Future<List<Map<String, dynamic>>> buscarProductos(String query) async {
    final db = await database;
    return await db.query(
      'productos',
      where: 'descripcion LIKE ? OR codigo LIKE ? OR factura LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }

  Future<int> updateStock(String codigo, int cantidadSumar) async {
    final db = await database;
    // Primero obtenemos el stock actual
    final prod = await getProductoPorCodigo(codigo);
    if (prod == null) return 0;

    int stockActual = prod['stock'];
    int nuevoStock = stockActual + cantidadSumar;

    return await db.update(
      'productos',
      {'stock': nuevoStock},
      where: 'id = ?',
      whereArgs: [prod['id']],
    );
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  // --- VENTAS ---
  Future<int> insertVenta(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('ventas', row);
  }
  // --- VINCULACIÓN Y ACTUALIZACIONES ---

  // Reemplaza el código temporal por el código de barras real escaneado
  Future<int> vincularCodigo(int idProducto, String nuevoCodigo) async {
    final db = await database;
    return await db.update(
      'productos',
      {'codigo': nuevoCodigo},
      where: 'id = ?',
      whereArgs: [idProducto],
    );
  }
}