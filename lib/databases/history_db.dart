import 'app_database.dart';

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
  Future<int> registrarVenta({
    required int folio,
    required String fecha,
    required double total,
    required double costoTotal,
    required String items,
    String cliente = "Cliente General"
  }) async {
    final db = await _db;
    // depurarBaseDatos() ya NO va aquí.
    // La limpieza es mantenimiento, no parte de registrar una venta.
    return await db.insert('ventas_historial', {
      'folio_venta': folio,
      'fecha': fecha,
      'total': total,
      'costo_total': costoTotal,
      'items': items,
      'cliente': cliente,
      'es_activo': 1
    });
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
      WHERE fecha LIKE ?
      GROUP BY substr(fecha, 1, 10)
    ''', [fechaLike]);
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