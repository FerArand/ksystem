import 'app_database.dart';

class DebtDB {
  static final DebtDB instance = DebtDB._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  // Crear o Actualizar Deudor (Sumar a la cuenta)
  Future<void> actualizarDeuda(String nombre, String nuevosItems, double montoAdicional) async {
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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