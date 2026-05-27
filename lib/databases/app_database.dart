import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

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
    // version: 4 para soportar ubicacion en productos
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: onUpgrade,
    );
  }

    Future onUpgrade(Database db, int oldVersion, int newVersion) async {
      if (oldVersion < 2) {
        await migrarItemsAJson(db);
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE ventas_historial ADD COLUMN recibido REAL DEFAULT 0');
        await db.execute('ALTER TABLE ventas_historial ADD COLUMN cambio REAL DEFAULT 0');
      }
      if (oldVersion < 4) {
        await db.execute('ALTER TABLE productos ADD COLUMN ubicacion TEXT DEFAULT ""');
      }
      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE pedidos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
            estado TEXT
          )
        ''');
      }
      if (oldVersion < 6) {
        await db.execute('''
          CREATE TABLE ventas_detalles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            venta_id INTEGER,
            sku TEXT,
            descripcion TEXT,
            cantidad INTEGER,
            precio REAL,
            costo REAL,
            estado TEXT DEFAULT 'activo'
          )
        ''');
      }
    }

    Future migrarItemsAJson(Database db) async {
      debugPrint('[AppDB] Migrando items a JSON...');

      // --- ventas_historial ---
      final ventas = await db.query('ventas_historial');
      for (final venta in ventas) {
        final raw = venta['items'] as String? ?? '';

        // Si ya es JSON, no tocar
        if (raw.trimLeft().startsWith('[')) continue;

        final itemsJson = convertirPipeAJson(raw);
        await db.update(
          'ventas_historial',
          {'items': itemsJson},
          where: 'id = ?',
          whereArgs: [venta['id']],
        );
      }
      debugPrint('[AppDB] ventas_historial migradas: ${ventas.length} filas');

      // --- deudores ---
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
      debugPrint('[AppDB] deudores migrados: ${deudores.length} filas');
    }

// Convierte "3x Cemento [SKU:C01][P:120.0][C:80.0]|1x Llana..."
// a   "[{"sku":"C01","descripcion":"Cemento","cantidad":3,...}]"
    String convertirPipeAJson(String raw) {
      if (raw.isEmpty) return '[]';

      final items = raw.split('|').where((s) => s.isNotEmpty).map((s) {
        final skuMatch    = RegExp(r'\[SKU:(.*?)\]').firstMatch(s);
        final precioMatch = RegExp(r'\[P:(.*?)\]').firstMatch(s);
        final costoMatch  = RegExp(r'\[C:(.*?)\]').firstMatch(s);
        final cantMatch   = RegExp(r'^(\d+)x').firstMatch(s.trim());
        final descripcion = s.replaceAll(RegExp(r'\[.*?\]'), '')
            .replaceAll(RegExp(r'^\d+x'), '').trim();
        return {
          'sku':         skuMatch?.group(1)    ?? '',
          'descripcion': descripcion,
          'cantidad':    int.tryParse(cantMatch?.group(1) ?? '1') ?? 1,
          'precio':      double.tryParse(precioMatch?.group(1) ?? '0') ?? 0.0,
          'costo':       double.tryParse(costoMatch?.group(1)  ?? '0') ?? 0.0,
        };
      }).toList();

      return jsonEncode(items);
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
        ubicacion TEXT,
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
        recibido REAL,
        cambio REAL,
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

    await db.execute('''
      CREATE TABLE pedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        estado TEXT
      )
    ''');
  }
}