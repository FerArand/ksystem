import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

class Facturero {
  final String rfc;
  final String razonSocial;
  final String codigoPostal;
  final String regimenFiscal;
  final String correo;
  final String usoCfdi;

  Facturero({
    required this.rfc,
    required this.razonSocial,
    required this.codigoPostal,
    required this.regimenFiscal,
    required this.correo,
    required this.usoCfdi,
  });

  Map<String, dynamic> toMap() {
    return {
      'rfc': rfc,
      'razon_social': razonSocial,
      'codigo_postal': codigoPostal,
      'regimen_fiscal': regimenFiscal,
      'correo': correo,
      'uso_cfdi': usoCfdi,
    };
  }

  factory Facturero.fromMap(Map<String, dynamic> map) {
    return Facturero(
      rfc: map['rfc'] ?? '',
      razonSocial: map['razon_social'] ?? '',
      codigoPostal: map['codigo_postal'] ?? '',
      regimenFiscal: map['regimen_fiscal'] ?? '',
      correo: map['correo'] ?? '',
      usoCfdi: map['uso_cfdi'] ?? '',
    );
  }
}

class FacturerosDB {
  static const String tableFactureros = 'factureros';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFactureros (
        rfc TEXT PRIMARY KEY,
        razon_social TEXT NOT NULL,
        codigo_postal TEXT NOT NULL,
        regimen_fiscal TEXT NOT NULL,
        correo TEXT NOT NULL,
        uso_cfdi TEXT NOT NULL
      )
    ''');
  }

  static Future<int> guardarOActualizar(Facturero facturero) async {
    final db = await DBHelper.instance.database;
    return await db.insert(
      tableFactureros,
      facturero.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Facturero>> buscarPorRazonSocial(String query) async {
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFactureros,
      where: 'razon_social LIKE ? OR rfc LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'razon_social ASC',
    );
    return List.generate(maps.length, (i) => Facturero.fromMap(maps[i]));
  }
}