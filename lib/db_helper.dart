import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:ksystem/databases/app_database.dart';
import 'package:ksystem/models/producto.dart';
import 'package:ksystem/models/item_venta.dart';
import "package:ksystem/databases/sync_service.dart";
import "dart:async";

typedef FilaDB = Map< String, dynamic >;
typedef ListaFilasDB = List< FilaDB >;
class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static const Uuid _uuid = Uuid();

  DBHelper._init();

  Future<Database> get database async => await AppDatabase.instance.database;
  Future<Database> get _db async => AppDatabase.instance.database;

  // ===================================================
  // SECCIÓN 1: PRODUCTOS E INVENTARIO (RF-01 a RF-05, RF-16)
  // ===================================================

  Future<int> insertProducto(Map<String, dynamic> row) async {
    final db = await _db;
    final data = Map<String, dynamic>.from(row);
    data['uuid'] ??= _uuid.v4();
    data['updated_at'] = DateTime.now().toIso8601String();
    data['borrado'] ??= 0;
    SyncService.instance.marcarCambiosPendientes();
    return await db.insert(
      'productos',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Producto>> buscarParaSeleccionManual(String query) async {
    if (query.trim().isEmpty) return <Producto>[];
    final db = await _db;
    final patron = '%${query.trim()}%';
    final res = await db.query(
      'productos',
      where:
      'borrado = 0 AND (descripcion LIKE ? OR ubicacion LIKE ? OR sku LIKE ? OR codigo LIKE ?)',
      whereArgs: <Object?>[patron, patron, patron, patron],
      orderBy: 'descripcion ASC',
      limit: 20, // RNF-04: Límite de 20 en autocompletado rápido de POS
    );
    return res.map((Map<String, dynamic> e) => Producto.desdeMapa(e)).toList();
  }

  Future<List<Producto>> buscarProductosMulticriterio(
      String filtro, {
        int limite = 100,
      }) async {
    final db = await _db;
    if (filtro.trim().isEmpty) {
      final res = await db.query(
        'productos',
        where: 'borrado = 0',
        orderBy: 'descripcion ASC',
        limit: limite, // RNF-04: Límite de 100 en vista general
      );
      return res
          .map((Map<String, dynamic> e) => Producto.desdeMapa(e))
          .toList();
    }
    final patron = '%${filtro.trim()}%';
    final resultados = await db.query(
      'productos',
      where:
      'borrado = 0 AND (descripcion LIKE ? OR codigo LIKE ? OR sku LIKE ? OR marca LIKE ? OR ubicacion LIKE ?)',
      whereArgs: <Object?>[patron, patron, patron, patron, patron],
      orderBy: 'descripcion ASC',
      limit: limite,
    );
    return resultados
        .map((Map<String, dynamic> mapa) => Producto.desdeMapa(mapa))
        .toList();
  }

  Future<Map<String, dynamic>?> getProductoPorCodigo(String codigo) async {
    final db = await _db;
    final maps = await db.query(
      'productos',
      where: 'codigo = ? AND borrado = 0',
      whereArgs: <Object?>[codigo],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<List<Map<String, dynamic>>> buscarProductos(String query) async {
    final db = await _db;
    if (query.trim().isEmpty) {
      return await db.query(
        'productos',
        where: 'borrado = 0',
        orderBy: 'descripcion ASC',
      );
    }
    final patron = '%${query.trim()}%';
    return await db.query(
      'productos',
      where:
      'borrado = 0 AND (descripcion LIKE ? OR codigo LIKE ? OR sku LIKE ? OR marca LIKE ? OR ubicacion LIKE ?)',
      whereArgs: <Object?>[patron, patron, patron, patron, patron],
      orderBy: 'descripcion ASC',
    );
  }

  /// Soporta incremento o descuento tanto entero como decimal (Venta a Granel RF-16)
  Future<int> updateStock(String codigo, num cantidad) async {
    final db = await _db;
    final prod = await getProductoPorCodigo(codigo);
    if (prod == null) return 0;
    final double stockActual = (prod['stock'] as num?)?.toDouble() ?? 0.0;
    final double nuevoStock = double.parse(
      (stockActual + cantidad.toDouble()).toStringAsFixed(4),
    );
    SyncService.instance.marcarCambiosPendientes();
    return await db.update(
      'productos',
      <String, Object?>{
        'stock': nuevoStock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[prod['id']],
    );
  }

  /// Baja lógica para preservar integridad referencial en historial de cortes (RF-01 / 5.3.4)
  Future<int> deleteProducto(int id) async {
    final db = await _db;
    return await db.update(
      'productos',
      <String, Object?>{
        'borrado': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> eliminarProductoLogico(int idProducto) async {
    await deleteProducto(idProducto);
  }

  Future<int> vincularCodigo(int idProducto, String nuevoCodigo) async {
    final db = await _db;
    return await db.update(
      'productos',
      <String, Object?>{
        'codigo': nuevoCodigo,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[idProducto],
    );
  }

  Future<int> updateProducto(Map<String, dynamic> row) async {
    final db = await _db;
    final data = Map<String, dynamic>.from(row);
    data['updated_at'] = DateTime.now().toIso8601String();
    SyncService.instance.marcarCambiosPendientes();
    return await db.update(
      'productos',
      data,
      where: 'id = ?',
      whereArgs: <Object?>[data['id']],
    );
  }

  Future<List<Map<String, dynamic>>> getProductosAgotados() async {
    final db = await _db;
    return await db.query(
      'productos',
      where: 'borrado = 0 AND stock <= 0',
      orderBy: 'descripcion ASC',
    );
  }

  /// Obtiene la lista de marcas únicas registradas en el inventario (usado en productos.dart)
  Future<List<String>> getMarcasUnicas() async {
    final db = await _db;
    final res = await db.rawQuery(
      "SELECT DISTINCT marca FROM productos WHERE borrado = 0 AND marca IS NOT NULL AND TRIM(marca) != '' ORDER BY marca ASC",
    );
    return res
        .map((Map<String, Object?> row) => (row['marca'] ?? '').toString().trim())
        .where((String m) => m.isNotEmpty)
        .toList();
  }

  /// Ajusta costo y precio masivamente recibiendo List<String> de marcas (firma exacta de productos.dart)
  Future<int> ajustarPreciosMasivo(
      List<String> marcas,
      double porcentajeCosto,
      double porcentajePrecio,
      ) async {
    final db = await _db;
    final double factorCosto = 1.0 + (porcentajeCosto / 100.0);
    final double factorPrecio = 1.0 + (porcentajePrecio / 100.0);
    final String ahora = DateTime.now().toIso8601String();

    String whereClause = 'borrado = 0';
    List<Object?> args = <Object?>[];

    final List<String> marcasLimpias = marcas
        .map((String m) => m.trim())
        .where((String m) => m.isNotEmpty && m.toUpperCase() != 'TODAS')
        .toList();

    if (marcasLimpias.isNotEmpty) {
      final String placeholders =
      List<String>.filled(marcasLimpias.length, '?').join(', ');
      whereClause += ' AND marca IN ($placeholders)';
      args.addAll(marcasLimpias);
    }

    final List<Map<String, Object?>> productos = await db.query(
      'productos',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
    );

    int actualizados = 0;
    await db.transaction((Transaction txn) async {
      for (final Map<String, Object?> p in productos) {
        final double costoActual = (p['costo'] as num?)?.toDouble() ?? 0.0;
        final double precioActual = (p['precio'] as num?)?.toDouble() ?? 0.0;
        final double rappiActual = (p['precioRappi'] as num?)?.toDouble() ?? 0.0;

        final double nuevoCosto = porcentajeCosto != 0
            ? double.parse((costoActual * factorCosto).toStringAsFixed(2))
            : costoActual;
        final double nuevoPrecio = porcentajePrecio != 0
            ? double.parse((precioActual * factorPrecio).toStringAsFixed(2))
            : precioActual;
        final double nuevoRappi = porcentajePrecio != 0
            ? double.parse((rappiActual * factorPrecio).toStringAsFixed(2))
            : rappiActual;

        await txn.update(
          'productos',
          <String, Object?>{
            'costo': nuevoCosto,
            'precio': nuevoPrecio,
            'precioRappi': nuevoRappi,
            'updated_at': ahora,
          },
          where: 'id = ?',
          whereArgs: <Object?>[p['id']],
        );
        actualizados++;
      }
    });

    return actualizados;
  }

  // ===================================================
  // SECCIÓN 2: DEUDAS Y FINANZAS (RF-11 y RF-12)
  // ===================================================

  Future<void> actualizarDeuda(
      String nombre,
      String nuevosItemsJson,
      double montoAdicional,
      ) async {
    final db = await _db;
    final ahora = DateTime.now().toIso8601String();
    final res = await db.query(
      'deudores',
      where: 'nombre = ?',
      whereArgs: <Object?>[nombre],
    );

    if (res.isNotEmpty) {
      final actual = res.first;
      final double totalActual =
          (actual['total_deuda'] as num?)?.toDouble() ?? 0.0;
      final String itemsActuales = (actual['items'] ?? '[]').toString();

      final List<ItemVenta> listaFinal =
      ItemVenta.listaDesdeString(itemsActuales);
      listaFinal.addAll(ItemVenta.listaDesdeString(nuevosItemsJson));

      final String jsonFinal = ItemVenta.listaAJson(listaFinal);
      final double totalFinal = totalActual + montoAdicional;

      await db.update(
        'deudores',
        <String, Object?>{
          'items': jsonFinal,
          'total_deuda': totalFinal,
          'fecha_ultimo_fiado': ahora,
          'updated_at': ahora,
        },
        where: 'id = ?',
        whereArgs: <Object?>[actual['id']],
      );
    } else {
      await db.insert('deudores', <String, Object?>{
        'uuid': _uuid.v4(),
        'nombre': nombre,
        'items': nuevosItemsJson,
        'total_deuda': montoAdicional,
        'fecha_ultimo_fiado': ahora,
        'updated_at': ahora,
      });
    }
    SyncService.instance.marcarCambiosPendientes();
  }

  Future<List<Map<String, dynamic>>> obtenerDeudores(String query) async {
    final db = await _db;
    if (query.trim().isEmpty) {
      return await db.query('deudores', orderBy: 'fecha_ultimo_fiado DESC');
    } else {
      return await db.query(
        'deudores',
        where: 'nombre LIKE ?',
        whereArgs: <Object?>['%${query.trim()}%'],
        orderBy: 'fecha_ultimo_fiado DESC',
      );
    }
  }

  Future<void> abonar(int id, double montoAbono) async {
    final db = await _db;
    final res = await db.query(
      'deudores',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (res.isNotEmpty) {
      final double deuda =
          (res.first['total_deuda'] as num?)?.toDouble() ?? 0.0;
      final double restante = deuda - montoAbono;
      if (restante <= 0.009) {
        await db.delete('deudores', where: 'id = ?', whereArgs: <Object?>[id]);
      } else {
        await db.update(
          'deudores',
          <String, Object?>{
            'total_deuda': restante,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      }
    }
    SyncService.instance.marcarCambiosPendientes();
  }

  // ===================================================
  // SECCIÓN 3: HISTORIAL, VENTAS, DEVOLUCIONES Y REPORTES
  // ===================================================

  Future<void> depurarBaseDatos() async {
    final db = await _db;
    final now = DateTime.now();
    final limiteSieteDias =
    now.subtract(const Duration(days: 7)).toIso8601String();
    final hace2Anios =
    now.subtract(const Duration(days: 730)).toIso8601String();
    final hace5Anios =
    now.subtract(const Duration(days: 1825)).toIso8601String();

    await db.delete(
      'recientes',
      where: 'fecha_agregado < ?',
      whereArgs: <Object?>[limiteSieteDias],
    );
    await db.update(
      'ventas_historial',
      <String, Object?>{
        'es_activo': 0,
        'updated_at': now.toIso8601String(),
      },
      where: 'fecha < ? AND es_activo = 1',
      whereArgs: <Object?>[hace2Anios],
    );
    await db.delete(
      'ventas_historial',
      where: 'fecha < ?',
      whereArgs: <Object?>[hace5Anios],
    );
  }

  Future<void> depurarBaseDatosSeguro() async {
    try {
      await depurarBaseDatos();
    } catch (e) {
      debugPrint('[DBHelper] Error al depurar: $e');
    }
  }

  Future< int > registrarVenta({
    required String fecha,
    required double total,
    required double costoTotal,
    required String items,
    double recibido = 0,
    double cambio = 0,
    String cliente = 'Cliente General',
    String metodoPago = 'Efectivo',
  }) async {
    final db = await _db;
    final ahora = DateTime.now().toIso8601String();

    // 1. Guardamos el ID en una variable en lugar de hacer return directo
    final int idGenerado = await db.transaction((txn) async {
      final int nuevoId = await txn.insert('ventas_historial', {
        'uuid': _uuid.v4(),
        'fecha': fecha,
        'total': total,
        'costo_total': costoTotal,
        'items': items,
        'cliente': cliente,
        'metodo_pago': metodoPago,
        'recibido': recibido,
        'cambio': cambio,
        'es_activo': 1,
        'updated_at': ahora,
      });

      try {
        final List< dynamic > itemsList = jsonDecode(items);
        for (final it in itemsList) {
          if (it is Map) {
            await txn.insert('ventas_detalles', {
              'venta_id': nuevoId,
              'sku': it['sku'] ?? 'N/A',
              'descripcion': it['descripcion'] ?? 'Sin descripción',
              'cantidad': (it['cantidad'] as num?)?.toDouble() ?? 1.0,
              'precio': (it['precio'] as num?)?.toDouble() ?? 0.0,
              'costo': (it['costo'] as num?)?.toDouble() ?? 0.0,
              'estado': 'activo',
            });
          }
        }
      } catch (e) {
        debugPrint('[DBHelper] Error al guardar detalles: $e');
      }

      await txn.update(
        'ventas_historial',
        {'folio_venta': nuevoId.toString()},
        where: 'id = ?',
        whereArgs: [nuevoId],
      );

      return nuevoId;
    });

    // 2. Marcamos que hay cambios y disparamos el respaldo (ya NO es código muerto)
    SyncService.instance.marcarCambiosPendientes();
    unawaited(SyncService.instance.sincronizarTodo());

    // 3. Ahora sí retornamos el folio generado
    return idGenerado;
  }

  Future< void > actualizarVentaModificada({
    required int id,
    required double nuevoTotal,
    required double nuevoCosto,
    required String nuevosItems,
    ListaFilasDB? itemsDevueltos,
    String? nuevoFolioDisplay,
  }) async {
    final db = await _db;
    final ahora = DateTime.now().toIso8601String();
    final String baseFolio = (nuevoFolioDisplay != null && nuevoFolioDisplay.isNotEmpty)
        ? nuevoFolioDisplay
        : id.toString();
    final String folioFinal = baseFolio.endsWith('M') ? baseFolio : '${baseFolio}M';

    await db.transaction((txn) async {
      await txn.update(
        'ventas_historial',
        {
          'total': nuevoTotal,
          'costo_total': nuevoCosto,
          'items': nuevosItems,
          'folio_venta': folioFinal,
          'updated_at': ahora,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (itemsDevueltos != null) {
        for (final item in itemsDevueltos) {
          final res = await txn.query(
            'ventas_detalles',
            where: 'venta_id = ? AND sku = ? AND estado = ?',
            whereArgs: [id, item['sku'], 'activo'],
          );

          double cantidadPorDevolver = (item['cantidad'] as num?)?.toDouble() ?? 0.0;

          for (final row in res) {
            if (cantidadPorDevolver <= 0.0001) break;

            final int idRenglon = row['id'] as int;
            final double cantidadEnRenglon = (row['cantidad'] as num?)?.toDouble() ?? 0.0;

            if (cantidadEnRenglon <= cantidadPorDevolver + 0.0001) {
              await txn.update(
                'ventas_detalles',
                {'estado': 'devuelto'},
                where: 'id = ?',
                whereArgs: [idRenglon],
              );
              cantidadPorDevolver -= cantidadEnRenglon;
            } else {
              final double cantidadRestante = double.parse(
                (cantidadEnRenglon - cantidadPorDevolver).toStringAsFixed(4),
              );
              await txn.update(
                'ventas_detalles',
                {'cantidad': cantidadRestante},
                where: 'id = ?',
                whereArgs: [idRenglon],
              );

              await txn.insert('ventas_detalles', {
                'venta_id': id,
                'sku': row['sku'],
                'descripcion': row['descripcion'],
                'cantidad': cantidadPorDevolver,
                'precio': row['precio'],
                'costo': row['costo'],
                'estado': 'devuelto',
              });

              cantidadPorDevolver = 0;
            }
          }
        }
      }
    });

    // Marcamos cambio pendiente y sincronizamos en segundo plano
    SyncService.instance.marcarCambiosPendientes();
    unawaited(SyncService.instance.sincronizarTodo());
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesVenta(int ventaId) async {
    final db = await _db;
    return await db.query(
      'ventas_detalles',
      where: 'venta_id = ?',
      whereArgs: <Object?>[ventaId],
    );
  }

  Future<List<Map<String, dynamic>>> buscarVentas(
      String query,
      bool soloActivos,
      ) async {
    final db = await _db;
    String whereClause = soloActivos ? 'es_activo = 1' : 'es_activo = 0';
    if (query.trim().isNotEmpty) {
      final patron = '%${query.trim()}%';
      whereClause += ' AND (folio_venta LIKE ? OR cliente LIKE ?)';
      return await db.query(
        'ventas_historial',
        where: whereClause,
        whereArgs: <Object?>[patron, patron],
        orderBy: 'fecha DESC',
      );
    } else {
      return await db.query(
        'ventas_historial',
        where: whereClause,
        orderBy: 'fecha DESC',
      );
    }
  }

  Future<List<Map<String, dynamic>>> obtenerVentasDelDia(
      String fechaHoyYMD,
      ) async {
    final db = await _db;
    return await db.query(
      'ventas_historial',
      where: 'fecha LIKE ? AND es_activo = 1',
      whereArgs: <Object?>['$fechaHoyYMD%'],
      orderBy: 'fecha DESC',
    );
  }

  Future<int> asignarNombreCliente(int id, String nuevoNombre) async {
    final db = await _db;
    return await db.update(
      'ventas_historial',
      <String, Object?>{
        'cliente': nuevoNombre,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<Map<String, dynamic>?> buscarVentaPorFolio(dynamic folio) async {
    final db = await _db;
    final res = await db.query(
      'ventas_historial',
      where: 'folio_venta = ?',
      whereArgs: <Object?>[folio.toString()],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorMes(
      int mes,
      int anio,
      ) async {
    final db = await _db;
    final String mesStr = mes.toString().padLeft(2, '0');
    final String fechaLike = '$anio-$mesStr-%';

    return await db.rawQuery('''
      SELECT 
        substr(fecha, 1, 10) as fecha_dia, 
        COALESCE(SUM(total), 0.0) as total_venta,
        COALESCE(SUM(costo_total), 0.0) as total_costo
      FROM ventas_historial
      WHERE fecha LIKE ? AND es_activo = 1
      GROUP BY substr(fecha, 1, 10)
    ''', <Object?>[fechaLike]);
  }

  Future<List<Map<String, dynamic>>> obtenerVentasRango(
      String fechaInicio,
      String fechaFin,
      ) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        substr(fecha, 1, 10) as fecha_dia, 
        COALESCE(SUM(total), 0.0) as total_venta,
        COALESCE(SUM(costo_total), 0.0) as total_costo
      FROM ventas_historial
      WHERE substr(fecha, 1, 10) BETWEEN ? AND ? AND es_activo = 1
      GROUP BY substr(fecha, 1, 10)
    ''', <Object?>[fechaInicio, fechaFin]);
  }

  Future<Map<String, dynamic>> obtenerResumenCorteFinanciero(
      String prefijoFecha,
      ) async {
    final db = await _db;
    final res = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total), 0.0) AS ingreso_bruto,
        COALESCE(SUM(costo_total), 0.0) AS capital_recuperacion,
        COALESCE(SUM(total - costo_total), 0.0) AS utilidad_neta
      FROM ventas_historial
      WHERE es_activo = 1 AND fecha LIKE ?
    ''', <Object?>['$prefijoFecha%']);
    return res.first;
  }

  Future<Map<String, dynamic>?> obtenerProductoMasVendidoMes(
      int mes,
      int anio,
      ) async {
    final db = await _db;
    final String mesStr = mes.toString().padLeft(2, '0');
    final String fechaLike = '$anio-$mesStr-%';

    final res = await db.rawQuery('''
      SELECT 
        d.sku,
        d.descripcion,
        SUM(d.cantidad) AS total_unidades,
        SUM(d.cantidad * d.precio) AS total_ingresos
      FROM ventas_detalles d
      INNER JOIN ventas_historial v ON v.id = d.venta_id
      WHERE v.fecha LIKE ? AND v.es_activo = 1 AND d.estado = 'activo'
      GROUP BY d.sku, d.descripcion
      ORDER BY total_unidades DESC
      LIMIT 1
    ''', <Object?>[fechaLike]);

    if (res.isNotEmpty && res.first['descripcion'] != null) {
      return res.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorDia(
      String fechaYmd,
      ) async {
    final db = await _db;
    return await db.query(
      'ventas_historial',
      where: 'fecha LIKE ?',
      whereArgs: <Object?>['$fechaYmd%'],
      orderBy: 'fecha DESC',
    );
  }

  // ===================================================
  // SECCIÓN 4: ARTÍCULOS RECIENTES (RF-06)
  // ===================================================

  Future<void> agregarReciente(String codigo) async {
    final db = await _db;
    final fecha = DateTime.now().toIso8601String();
    await db.insert(
      'recientes',
      <String, Object?>{'codigo': codigo, 'fecha_agregado': fecha},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _limpiarAntiguos().catchError((Object e) => debugPrint('[DBHelper] Limpieza: $e'));
  }

  Future<List<Producto>> obtenerProductosRecientesCompletos() async {
    final codigos = await obtenerCodigosRecientes();
    if (codigos.isEmpty) return <Producto>[];

    final resultados = await Future.wait(
      codigos.map((String codigo) => getProductoPorCodigo(codigo)),
    );

    final List<Producto> productos = <Producto>[];
    for (final Map<String, dynamic>? mapa in resultados) {
      if (mapa != null) {
        productos.add(Producto.desdeMapa(mapa));
      }
    }
    return productos;
  }

  Future<List<String>> obtenerCodigosRecientes() async {
    final db = await _db;
    await _limpiarAntiguos();
    final res = await db.query('recientes', orderBy: 'fecha_agregado DESC');
    return res.map((Map<String, Object?> e) => e['codigo'] as String).toList();
  }

  Future<void> _limpiarAntiguos() async {
    final db = await _db;
    final limite =
    DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete(
      'recientes',
      where: 'fecha_agregado < ?',
      whereArgs: <Object?>[limite],
    );
  }
}