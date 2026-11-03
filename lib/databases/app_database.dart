import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

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

    return await openDatabase(
      path,
      version: 7, // Versión 7: Venta a granel, métodos de pago y UUID/ISO 8601
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Verifica si una columna ya existe antes de ejecutar ALTER TABLE para evitar errores en producción
  Future<void> _agregarColumnaSegura(
      Database db,
      String tabla,
      String columna,
      String definicionTipo,
      ) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    final existe = info.any((col) => col['name'] == columna);
    if (!existe) {
      await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $definicionTipo');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await migrarItemsAJson(db);
    }
    if (oldVersion < 3) {
      await _agregarColumnaSegura(db, 'ventas_historial', 'recibido', 'REAL DEFAULT 0');
      await _agregarColumnaSegura(db, 'ventas_historial', 'cambio', 'REAL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await _agregarColumnaSegura(db, 'productos', 'ubicacion', 'TEXT DEFAULT ""');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pedidos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT,
          cliente_nombre TEXT,
          cliente_contacto TEXT,
          producto_nombre TEXT,
          producto_sku TEXT,
          precio_normal REAL,
          precio_apartado REAL,
          abono_inicial REAL,
          total_pagado REAL,
          costo REAL,
          descuento REAL,
          fecha_creacion TEXT,
          fecha_entrega TEXT,
          estado TEXT,
          updated_at TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ventas_detalles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          sku TEXT,
          descripcion TEXT,
          cantidad REAL,
          precio REAL,
          costo REAL,
          estado TEXT DEFAULT 'activo'
        )
      ''');
    }
    if (oldVersion < 7) {
      // Migración no destructiva hacia Arquitectura Híbrida, Granel y Métodos de Pago
      await _agregarColumnaSegura(db, 'productos', 'es_granel', 'INTEGER DEFAULT 0');
      await _agregarColumnaSegura(db, 'productos', 'uuid', 'TEXT');
      await _agregarColumnaSegura(db, 'productos', 'updated_at', 'TEXT');

      await _agregarColumnaSegura(db, 'ventas_historial', 'metodo_pago', 'TEXT DEFAULT "Efectivo"');
      await _agregarColumnaSegura(db, 'ventas_historial', 'uuid', 'TEXT');
      await _agregarColumnaSegura(db, 'ventas_historial', 'updated_at', 'TEXT');

      await _agregarColumnaSegura(db, 'deudores', 'uuid', 'TEXT');
      await _agregarColumnaSegura(db, 'deudores', 'updated_at', 'TEXT');

      await _agregarColumnaSegura(db, 'pedidos', 'uuid', 'TEXT');
      await _agregarColumnaSegura(db, 'pedidos', 'updated_at', 'TEXT');

      await _inicializarUuidRegistrosExistentes(db);
    }
  }

  /// Asigna UUID v4 y marca de tiempo ISO 8601 a los registros históricos de producción
  Future<void> _inicializarUuidRegistrosExistentes(Database db) async {
    const uuidGen = Uuid();
    final ahora = DateTime.now().toIso8601String();
    const tablasSincronizables = ['productos', 'ventas_historial', 'deudores', 'pedidos'];

    await db.transaction((txn) async {
      for (final tabla in tablasSincronizables) {
        final pendientes = await txn.query(
          tabla,
          columns: ['id'],
          where: 'uuid IS NULL OR uuid = ""',
        );
        for (final fila in pendientes) {
          await txn.update(
            tabla,
            {'uuid': uuidGen.v4(), 'updated_at': ahora},
            where: 'id = ?',
            whereArgs: [fila['id']],
          );
        }
      }
    });
  }

  Future<void> migrarItemsAJson(Database db) async {
    debugPrint('[AppDB] Migrando items a JSON...');
    final ventas = await db.query('ventas_historial');
    for (final venta in ventas) {
      final raw = venta['items'] as String? ?? '';
      if (raw.trimLeft().startsWith('[')) continue;
      final itemsJson = convertirPipeAJson(raw);
      await db.update(
        'ventas_historial',
        {'items': itemsJson},
        where: 'id = ?',
        whereArgs: [venta['id']],
      );
    }

    final deudores = await db.query('deudores');
    for (final deudor in deudores) {
      final raw = deudor['items'] as String? ?? '';
      if (raw.trimLeft().startsWith('[')) continue;
      final itemsJson = convertirPipeAJson(raw);
      await db.update(
        'deudores',
        {'items': itemsJson},
        where: 'id = ?',
        whereArgs: [deudor['id']],
      );
    }
  }

  String convertirPipeAJson(String raw) {
    if (raw.isEmpty) return '[]';
    final items = raw.split('|').where((s) => s.isNotEmpty).map((s) {
      final skuMatch = RegExp(r'\[SKU:(.*?)\]').firstMatch(s);
      final precioMatch = RegExp(r'\[P:(.*?)\]').firstMatch(s);
      final costoMatch = RegExp(r'\[C:(.*?)\]').firstMatch(s);
      final cantMatch = RegExp(r'^(\d+(\.\d+)?)x').firstMatch(s.trim());
      final descripcion = s
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'^\d+(\.\d+)?x'), '')
          .trim();
      return {
        'sku': skuMatch?.group(1) ?? '',
        'descripcion': descripcion,
        'cantidad': double.tryParse(cantMatch?.group(1) ?? '1') ?? 1,
        'precio': double.tryParse(precioMatch?.group(1) ?? '0') ?? 0.0,
        'costo': double.tryParse(costoMatch?.group(1) ?? '0') ?? 0.0,
      };
    }).toList();
    return jsonEncode(items);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        codigo TEXT UNIQUE,
        sku TEXT,
        factura TEXT,
        ubicacion TEXT,
        descripcion TEXT,
        marca TEXT,
        costo REAL,
        precio REAL,
        precioRappi REAL,
        stock REAL,
        es_granel INTEGER DEFAULT 0,
        borrado INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ventas_historial (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        folio_venta TEXT,
        fecha TEXT,
        total REAL,
        costo_total REAL,
        items TEXT,
        cliente TEXT,
        metodo_pago TEXT DEFAULT 'Efectivo',
        recibido REAL,
        cambio REAL,
        es_activo INTEGER DEFAULT 1,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ventas_detalles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER,
        sku TEXT,
        descripcion TEXT,
        cantidad REAL,
        precio REAL,
        costo REAL,
        estado TEXT DEFAULT 'activo'
      )
    ''');

    await db.execute('''
      CREATE TABLE deudores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        nombre TEXT UNIQUE,
        items TEXT,
        total_deuda REAL,
        fecha_ultimo_fiado TEXT,
        updated_at TEXT
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
        cantidad REAL,
        fecha_ingreso TEXT,
        accion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        cliente_nombre TEXT,
        cliente_contacto TEXT,
        producto_nombre TEXT,
        producto_sku TEXT,
        precio_normal REAL,
        precio_apartado REAL,
        abono_inicial REAL,
        total_pagado REAL,
        costo REAL,
        descuento REAL,
        fecha_creacion TEXT,
        fecha_entrega TEXT,
        estado TEXT,
        updated_at TEXT
      )
    ''');
  }
}