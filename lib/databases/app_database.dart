import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ksystem.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    // version: 1 por ser base nueva. Cuando agregues tablas,
    // incrementas la versión y usas onUpgrade.
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // TODAS las tablas en un solo lugar.
    // Ya no están repartidas en 4 archivos distintos.

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
      CREATE TABLE ventas_historial (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folio_venta INTEGER,
        fecha TEXT,
        total REAL,
        costo_total REAL,
        items TEXT,
        cliente TEXT,
        es_activo INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE deudores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT UNIQUE,
        items TEXT,
        total_deuda REAL,
        fecha_ultimo_fiado TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE recientes (
        codigo TEXT PRIMARY KEY,
        fecha_agregado TEXT
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
}