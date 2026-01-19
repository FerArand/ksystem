import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart'; // Necesario para encontrar carpetas

// Tus archivos locales
import 'constants/colores.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'venta.dart';
import 'productos.dart';
import 'nuevo_ingreso.dart';

class Inicio extends StatefulWidget {
  const Inicio({Key? key}) : super(key: key);

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  String _seccionActual = 'venta'; // Sección por defecto
  bool _importando = false;

  // ------------------------------------------
  // IMPORTAR DESDE EXCEL (ADAPTADO A SQLITE)
  // ------------------------------------------
  Future<void> _importarExcel() async {
    setState(() => _importando = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // Intentamos buscar la hoja por nombre, si no, tomamos la primera
        Sheet? sheet = excel.tables['Precios MENUDEO'];
        sheet ??= excel.tables[excel.tables.keys.first];

        if (sheet != null) {
          final db = await DBHelper.instance.database;
          int count = 0;

          // Helper para leer celdas de forma segura
          dynamic getCell(Data? cell) {
            if (cell == null) return null;
            var v = cell.value;
            if (v == null) return null;
            if (v is FormulaCellValue) return null;
            if (v is BoolCellValue) return v.value;
            if (v is IntCellValue) return v.value;
            if (v is DoubleCellValue) return v.value;
            if (v is TextCellValue) return v.value;
            return v; // String u otros
          }

          // Iteramos filas (saltando encabezados si es necesario, aquí asumo fila 1 en adelante)
          for (int r = 1; r < sheet.maxRows; r++) {
            List<Data?> row = sheet.row(r);
            if (row.isEmpty) continue;

            // Mapeo basado en tu Excel original:
            // Col 0: Stock (Inventario)
            // Col 1: Factura
            // Col 2: Marca
            // Col 3: Descripción
            // Col 4: Costo

            var stockCell = getCell(row.length > 0 ? row[0] : null);
            var facturaCell = getCell(row.length > 1 ? row[1] : null);
            var marcaCell = getCell(row.length > 2 ? row[2] : null);
            var descripcionCell = getCell(row.length > 3 ? row[3] : null);
            var costoCell = getCell(row.length > 4 ? row[4] : null);

            // Validamos campos mínimos obligatorios
            if (descripcionCell == null || costoCell == null) continue;

            String descripcion = descripcionCell.toString().trim();
            String factura = facturaCell?.toString().trim() ?? '';
            String marca = marcaCell?.toString().trim() ?? '';

            // Conversiones numéricas seguras
            double costo = 0.0;
            if (costoCell is num) {
              costo = costoCell.toDouble();
            } else {
              costo = double.tryParse(costoCell.toString()) ?? 0.0;
            }

            int stock = 0;
            if (stockCell != null) {
              if (stockCell is num) {
                stock = stockCell.toInt();
              } else {
                stock = int.tryParse(stockCell.toString()) ?? 0;
              }
            }

            // Cálculos de precios (Lógica original)
            double precio = double.parse((costo * 1.46).toStringAsFixed(2));
            double precioRappi = double.parse((precio * 1.35).toStringAsFixed(2));

            // GENERACIÓN DE CÓDIGO
            // Si el Excel tiene columna código (digamos col 5) úsala, si no, usa la factura.
            // Si no hay factura, usa la descripción (no ideal, pero evita vacíos).
            String codigo = '';
            // Verificamos si hay una columna extra para código (tu nuevo excel exportado la tendrá en la col 0, pero el viejo no)
            // Asumiremos lógica de Excel Viejo: Usar Factura como Código
            if (factura.isNotEmpty) {
              codigo = factura;
            } else {
              // Generar un código temporal si no hay factura
              codigo = "GEN-${DateTime.now().millisecondsSinceEpoch}-$r";
            }

            Map<String, dynamic> productoMap = {
              'codigo': codigo,
              'factura': factura,
              'descripcion': descripcion,
              'marca': marca,
              'costo': costo,
              'precio': precio,
              'precioRappi': precioRappi,
              'stock': stock,
              'borrado': 0, // 0 = false en SQLite
            };

            // Insertar en BD (ConflictAlgorithm.replace reemplaza si ya existe el código/ID)
            await DBHelper.instance.insertProducto(productoMap);
            count++;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Importación completada. $count productos procesados.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $e')),
      );
    } finally {
      setState(() => _importando = false);
    }
  }

  // ------------------------------------------
  // EXPORTAR A EXCEL (CON CÓDIGO DE BARRAS)
  // ------------------------------------------
  Future<void> _exportarExcel() async {
    setState(() => _importando = true);

    try {
      // 1. Obtener datos
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('productos');
      List<Producto> productos = List.generate(maps.length, (i) => Producto.desdeMapa(maps[i]));

      // 2. Crear Excel
      var excel = Excel.createExcel();
      String sheetName = 'Inventario';
      Sheet sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // 3. Encabezados
      List<CellValue> headers = [
        TextCellValue('Código'),       // A
        TextCellValue('Factura'),      // B
        TextCellValue('Marca'),        // C
        TextCellValue('Descripción'),  // D
        TextCellValue('Costo'),        // E
        TextCellValue('Precio Público'),// F
        TextCellValue('Precio Rappi'), // G
        TextCellValue('Stock'),        // H
      ];
      sheetObject.appendRow(headers);

      // 4. Llenar filas
      for (var p in productos) {
        List<CellValue> row = [
          TextCellValue(p.codigo),
          TextCellValue(p.factura),
          TextCellValue(p.marca),
          TextCellValue(p.descripcion),
          DoubleCellValue(p.costo),
          DoubleCellValue(p.precio),
          DoubleCellValue(p.precioRappi),
          IntCellValue(p.stock),
        ];
        sheetObject.appendRow(row);
      }

      // 5. Guardar
      Directory? directory;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        directory = await getDownloadsDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      String fecha = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      String filePath = "${directory.path}/Inventario_Ktools_$fecha.xlsx";

      var fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado en: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    } finally {
      setState(() => _importando = false);
    }
  }

  // ------------------------------------------
  // CONTENIDO CENTRAL
  // ------------------------------------------
  Widget _contenido() {
    if (_importando) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Procesando archivo Excel..."),
        ],
      ));
    }

    switch (_seccionActual) {
      case 'venta':
        return const Venta();
      case 'anadir':
        return const NuevoIngreso();
      case 'consultar':
        return const Productos();
      default:
        return const Venta();
    }
  }

  // ------------------------------------------
  // INTERFAZ (UI)
  // ------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // MENÚ LATERAL
          Container(
            width: 220,
            color: Colores.grisOscuro,
            child: Column(
              children: [
                const SizedBox(height: 30),
                // LOGO / TÍTULO
                const Text(
                  'KTOOLS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'Local System',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 40),

                // OPCIONES DE MENÚ
                _buildMenuItem(Icons.point_of_sale, 'Venta (Inicio)', 'venta'),
                _buildMenuItem(Icons.add_circle_outline, 'Añadir / Ingreso', 'anadir'),
                _buildMenuItem(Icons.list_alt, 'Consultar', 'consultar'),

                const Divider(color: Colors.grey),

                // OPCIONES DE ARCHIVO
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.white70),
                  title: const Text('Importar Excel', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  onTap: _importarExcel,
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.white70),
                  title: const Text('Exportar Excel', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  onTap: _exportarExcel,
                ),
              ],
            ),
          ),

          // ÁREA DE CONTENIDO
          Expanded(
            child: Container(
              color: Colors.grey[100], // Fondo ligero para el área de trabajo
              child: _contenido(),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para items del menú
  Widget _buildMenuItem(IconData icon, String title, String seccion) {
    bool isSelected = _seccionActual == seccion;
    return Container(
      color: isSelected ? Colors.white.withOpacity(0.1) : null,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colores.azulCielo : Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colores.azulCielo : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _seccionActual = seccion);
        },
      ),
    );
  }
}