import 'app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class HistoryDB {
  static final HistoryDB instance = HistoryDB._init();

  HistoryDB._init();
  Future<Database> get _db async => AppDatabase.instance.database;

  // --- MANTENIMIENTO ---
  Future<void> depurarBaseDatos() async {
    final db = await _db;
    final now = DateTime.now();
    final hace2Anios = now.subtract(const Duration(days: 730)).toIso8601String();
    await db.update('ventas_historial', {'es_activo': 0}, where: "fecha < ? AND es_activo = 1", whereArgs: [hace2Anios]);
    final hace5Anios = now.subtract(const Duration(days: 1825)).toIso8601String();
    await db.delete('ventas_historial', where: "fecha < ?", whereArgs: [hace5Anios]);
  }

  // --- REGISTRAR ---
  // --- REGISTRAR VENTA (Versión Unificada) ---
  Future<int> registrarVenta({
    required String fecha,
    required double total,
    required double costoTotal,
    required String items,
    double recibido = 0,
    double cambio = 0,
    String cliente = "Cliente General"
  }) async {
    final db = await _db;

    // 1. Insertamos la venta. El 'id' se genera solo.
    int idGenerado = await db.insert('ventas_historial', {
      'fecha': fecha,
      'total': total,
      'costo_total': costoTotal,
      'items': items,
      'cliente': cliente,
      'recibido': recibido,
      'cambio': cambio,
      'es_activo': 1
    });

    // 2. Insertamos el detalle de los productos (Desglose real para historial y devoluciones)
    try {
      final List<dynamic> itemsList = jsonDecode(items);
      for (var it in itemsList) {
        await db.insert('ventas_detalles', {
          'venta_id': idGenerado,
          'sku': it['sku'] ?? 'N/A',
          'descripcion': it['descripcion'] ?? 'Sin descripción',
          'cantidad': it['cantidad'] ?? 1,
          'precio': (it['precio'] as num).toDouble(),
          'costo': (it['costo'] as num).toDouble(),
          'estado': 'activo'
        });
      }
    } catch (e) {
      debugPrint('[HistoryDB] Error al guardar detalles: $e');
    }

    // 3. Opcional: Sincronizamos el folio_venta con el ID generado
    // para que coincidan en tus tickets y reportes.
    await db.update(
        'ventas_historial',
        {'folio_venta': idGenerado},
        where: 'id = ?',
        whereArgs: [idGenerado]
    );

    return idGenerado;
  }

// NUEVO: Método seguro para llamar la limpieza desde fuera,
// con manejo de error explícito.
  Future<void> depurarBaseDatosSeguro() async {
    try {
      await depurarBaseDatos();
    } catch (e) {
      // Aquí puedes loggear con un paquete como 'logger'
      // o simplemente imprimir en desarrollo:
      debugPrint('[HistoryDB] Error al depurar: $e');
    }
  }

  Future<void> actualizarVentaModificada({
    required int id,
    required double nuevoTotal,
    required double nuevoCosto,
    required String nuevosItems,
    List<Map<String, dynamic>>? itemsDevueltos,
    required String nuevoFolioDisplay,
  }) async {
    final db = await _db;
    
    // 1. Actualizar cabecera (ventas_historial)
    await db.update('ventas_historial', {
      'total': nuevoTotal,
      'costo_total': nuevoCosto,
      'items': nuevosItems,
      'folio_venta': nuevoFolioDisplay
    }, where: 'id = ?', whereArgs: [id]);

    // 2. Marcar items devueltos en la tabla de detalles
    if (itemsDevueltos != null) {
      for (var item in itemsDevueltos) {
        // Obtenemos los registros activos para este SKU en esta venta
        final res = await db.query(
          'ventas_detalles',
          where: 'venta_id = ? AND sku = ? AND estado = ?',
          whereArgs: [id, item['sku'], 'activo'],
        );

        int cantidadPorDevolver = item['cantidad'];

        for (var row in res) {
          if (cantidadPorDevolver <= 0) break;

          int idRenglon = row['id'] as int;
          int cantidadEnRenglon = row['cantidad'] as int;

          if (cantidadEnRenglon <= cantidadPorDevolver) {
            // Devolución total del renglón o el renglón es menor a lo que falta devolver
            await db.update(
              'ventas_detalles',
              {'estado': 'devuelto'},
              where: 'id = ?',
              whereArgs: [idRenglon]
            );
            cantidadPorDevolver -= cantidadEnRenglon;
          } else {
            // Devolución PARCIAL del renglón (Escenario de los Martillos)
            // 1. Restamos la cantidad al renglón original
            await db.update(
              'ventas_detalles',
              {'cantidad': cantidadEnRenglon - cantidadPorDevolver},
              where: 'id = ?',
              whereArgs: [idRenglon]
            );

            // 2. Creamos un nuevo renglón para la parte devuelta
            await db.insert('ventas_detalles', {
              'venta_id': id,
              'sku': row['sku'],
              'descripcion': row['descripcion'],
              'cantidad': cantidadPorDevolver,
              'precio': row['precio'],
              'costo': row['costo'],
              'estado': 'devuelto'
            });
            
            cantidadPorDevolver = 0;
          }
        }
      }
    }
  }

  // Obtener detalles de una venta (para reimpresión profesional)
  Future<List<Map<String, dynamic>>> obtenerDetallesVenta(int ventaId) async {
    final db = await _db;
    return await db.query('ventas_detalles', where: 'venta_id = ?', whereArgs: [ventaId]);
  }

  // --- BUSCAR HISTORIAL GENERAL ---
  Future<List<Map<String, dynamic>>> buscarVentas(String query, bool soloActivos) async {
    final db = await _db;
    String whereClause = soloActivos ? 'es_activo = 1' : 'es_activo = 0';
    if (query.isNotEmpty) {
      whereClause += " AND (folio_venta LIKE ? OR cliente LIKE ?)";
      return await db.query('ventas_historial', where: whereClause, whereArgs: ['%$query%', '%$query%'], orderBy: 'fecha DESC');
    } else {
      return await db.query('ventas_historial', where: whereClause, orderBy: 'fecha DESC');
    }
  }

  // --- NUEVO: OBTENER VENTAS DE HOY ---
  Future<List<Map<String, dynamic>>> obtenerVentasDelDia(String fechaHoyYMD) async {
    final db = await _db;
    // Buscamos fechas que empiecen con YYYY-MM-DD
    return await db.query(
        'ventas_historial',
        where: 'fecha LIKE ? AND es_activo = 1',
        whereArgs: ['$fechaHoyYMD%'],
        orderBy: 'fecha DESC'
    );
  }

  Future<int> asignarNombreCliente(int id, String nuevoNombre) async {
    final db = await _db;
    return await db.update('ventas_historial', {'cliente': nuevoNombre}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> buscarVentaPorFolio(dynamic folio) async {
    final db = await _db;
    final res = await db.query('ventas_historial', where: 'folio_venta = ?', whereArgs: [folio.toString()], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  // ... código existente ...

  // 1. Obtener resumen de ventas de un MES completo (para pintar los cuadritos)
  Future<List<Map<String, dynamic>>> obtenerVentasPorMes(int mes, int anio) async {
    final db = await _db;
    // Filtramos por fecha string 'YYYY-MM-%'
    String mesStr = mes.toString().padLeft(2, '0');
    String fechaLike = "$anio-$mesStr-%";

    return await db.rawQuery('''
      SELECT 
        substr(fecha, 1, 10) as fecha_dia, 
        SUM(total) as total_venta,
        SUM(costo_total) as total_costo
      FROM ventas_historial
      WHERE fecha LIKE ? AND es_activo = 1
      GROUP BY substr(fecha, 1, 10)
    ''', [fechaLike]);
  }

  // NUEVO: Obtener resumen por rango de fechas (para calendario de semanas completas)
  Future<List<Map<String, dynamic>>> obtenerVentasRango(String fechaInicio, String fechaFin) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        substr(fecha, 1, 10) as fecha_dia, 
        SUM(total) as total_venta,
        SUM(costo_total) as total_costo
      FROM ventas_historial
      WHERE substr(fecha, 1, 10) BETWEEN ? AND ? AND es_activo = 1
      GROUP BY substr(fecha, 1, 10)
    ''', [fechaInicio, fechaFin]);
  }

  // 2. Obtener el producto más vendido del mes (Para la cabecera)
  Future<Map<String, dynamic>?> obtenerProductoMasVendidoMes(int mes, int anio) async {
    final db = await _db;
    String mesStr = mes.toString().padLeft(2, '0');
    String fechaLike = "$anio-$mesStr-%";

    // Nota: Esto requiere procesar el JSON de 'items' o tener una tabla detalle.
    // Como guardas items en string "1x Prod | 2x Prod", hacer esto exacto en SQL es difícil sin normalizar.
    // PARCHE: Por ahora, devolveremos el día con más ventas como "Dato Destacado"
    // O si quieres el producto real, necesitaríamos cambiar cómo guardas los items a una tabla relacional.
    // Asumiré por ahora que mostramos el "Día Récord" o implementamos un parsing manual rápido en Dart.
    return null; // Lo calcularemos en Dart para no complicar la SQL con strings
  }

  // 3. Obtener ventas de UN DÍA específico (Tickets)
  Future<List<Map<String, dynamic>>> obtenerVentasPorDia(String fechaYmd) async {
    final db = await _db;
    return await db.query('ventas_historial',
        where: "fecha LIKE ?",
        whereArgs: ['$fechaYmd%'],
        orderBy: "fecha DESC"
    );
  }
}