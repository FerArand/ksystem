import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DebtDB {
  static final DebtDB instance = DebtDB._init();
  static Database? _database;

  DebtDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _database = await _initDB('ksystem_debts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE deudores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT UNIQUE,
      items TEXT, -- Guardaremos los productos como un string largo (JSON o pipe separated)
      total_deuda REAL,
      fecha_ultimo_fiado TEXT
    )
    ''');
  }

  // Crear o Actualizar Deudor (Sumar a la cuenta)
  Future<void> actualizarDeuda(String nombre, String nuevosItems, double montoAdicional) async {
    final db = await database;
    final fecha = DateTime.now().toString();

    // Buscamos si ya existe
    final res = await db.query('deudores', where: 'nombre = ?', whereArgs: [nombre]);

    if (res.isNotEmpty) {
      // YA EXISTE: SUMAMOS
      final actual = res.first;
      double totalActual = actual['total_deuda'] as double;
      String itemsActuales = actual['items'] as String;

      // Concatenamos los items nuevos
      String itemsFinal = "$itemsActuales|$nuevosItems";
      double totalFinal = totalActual + montoAdicional;

      await db.update('deudores', {
        'items': itemsFinal,
        'total_deuda': totalFinal,
        'fecha_ultimo_fiado': fecha
      }, where: 'id = ?', whereArgs: [actual['id']]);

    } else {
      // NUEVO DEUDOR
      await db.insert('deudores', {
        'nombre': nombre,
        'items': nuevosItems,
        'total_deuda': montoAdicional,
        'fecha_ultimo_fiado': fecha
      });
    }
  }

  // Obtener lista
  Future<List<Map<String, dynamic>>> obtenerDeudores(String query) async {
    final db = await database;
    if (query.isEmpty) {
      return await db.query('deudores', orderBy: 'fecha_ultimo_fiado DESC');
    } else {
      return await db.query('deudores',
          where: 'nombre LIKE ?',
          whereArgs: ['%$query%'],
          orderBy: 'fecha_ultimo_fiado DESC'
      );
    }
  }

  // Abonar o Liquidar
  Future<void> abonar(int id, double montoAbono) async {
    final db = await database;
    final res = await db.query('deudores', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) {
      double deuda = res.first['total_deuda'] as double;
      double restante = deuda - montoAbono;
      if (restante <= 0) {
        // Se pagó todo, borramos el registro
        await db.delete('deudores', where: 'id = ?', whereArgs: [id]);
      } else {
        await db.update('deudores', {'total_deuda': restante}, where: 'id = ?', whereArgs: [id]);
      }
    }
  }
}