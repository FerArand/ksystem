import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'databases/app_database.dart';
import 'models/producto.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  DBHelper._init();

  // Cambiamos el nombre o añadimos un getter público
  Future<Database> get database async {
    return await AppDatabase.instance.database;
  }

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<int> insertProducto(Map<String, dynamic> row) async {
    final db = await _db;
    return await db.insert('productos', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // NUEVO: Lógica de negocio encapsulada para búsquedas manuales
  Future<List<Producto>> buscarParaSeleccionManual(String query) async {
    if (query.isEmpty) return [];

    final db = await _db;
    final res = await db.query(
        'productos',
        where: 'descripcion LIKE ? OR factura LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 20 // Límite para proteger la memoria
    );

    // Mapeamos aquí, la UI solo recibe la lista de objetos listos para usar
    return res.map((e) => Producto.desdeMapa(e)).toList();
  }

  Future<Map<String, dynamic>?> getProductoPorCodigo(String codigo) async {
    final db = await _db;
    final maps = await db.query('productos',
        where: 'codigo = ?', whereArgs: [codigo]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<List<Map<String, dynamic>>> buscarProductos(String query) async {
    final db = await _db;
    return await db.query('productos',
        where: 'descripcion LIKE ? OR codigo LIKE ? OR sku LIKE ? OR factura LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%']);
  }

  Future<int> updateStock(String codigo, int cantidad) async {
    final db = await _db;
    final prod = await getProductoPorCodigo(codigo);
    if (prod == null) return 0;
    int nuevoStock = prod['stock'] + cantidad;
    return await db.update('productos', {'stock': nuevoStock},
        where: 'id = ?', whereArgs: [prod['id']]);
  }

  Future<int> deleteProducto(int id) async {
    final db = await _db;
    return await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> vincularCodigo(int idProducto, String nuevoCodigo) async {
    final db = await _db;
    return await db.update('productos', {'codigo': nuevoCodigo},
        where: 'id = ?', whereArgs: [idProducto]);
  }

  Future<int> updateProducto(Map<String, dynamic> row) async {
    final db = await _db;
    return await db.update('productos', row,
        where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<List<Map<String, dynamic>>> getProductosAgotados() async {
    final db = await _db;
    return await db.query('productos',
        where: 'stock <= 0', orderBy: 'descripcion ASC');
  }
}