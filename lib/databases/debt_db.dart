import 'app_database.dart';
import 'package:sqflite/sqflite.dart';
import '../models/item_venta.dart'; // Asegúrate de añadir este import arriba

class DebtDB {
  static final DebtDB instance = DebtDB._init();
  DebtDB._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  // Crear o Actualizar Deudor (Sumar a la cuenta)


  Future<void> actualizarDeuda(String nombre, String nuevosItemsJson, double montoAdicional) async {
    final db = await _db;
    final fecha = DateTime.now().toString();
    final res = await db.query('deudores', where: 'nombre = ?', whereArgs: [nombre]);

    if (res.isNotEmpty) {
      final actual = res.first;
      double totalActual = actual['total_deuda'] as double;
      String itemsActuales = actual['items'] as String;

      // USAMOS JSON: Combinamos las listas de items
      List<ItemVenta> listaFinal = ItemVenta.listaDesdeString(itemsActuales);
      listaFinal.addAll(ItemVenta.listaDesdeString(nuevosItemsJson));

      String jsonFinal = ItemVenta.listaAJson(listaFinal);
      double totalFinal = totalActual + montoAdicional;

      await db.update('deudores', {
        'items': jsonFinal,
        'total_deuda': totalFinal,
        'fecha_ultimo_fiado': fecha
      }, where: 'id = ?', whereArgs: [actual['id']]);

    } else {
      await db.insert('deudores', {
        'nombre': nombre,
        'items': nuevosItemsJson,
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