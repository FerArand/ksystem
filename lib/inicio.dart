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
            // CORRECCIÓN: NO usar factura como código.
            // Generamos un código interno único para que no choque en la BD.
            // Cuando vincules el producto, este código se reemplazará por el real.
            String codigo = "NO_CODIGO_${DateTime.now().millisecondsSinceEpoch}_$r";

            Map<String, dynamic> productoMap = {
              'codigo': codigo,
              'factura': factura,
              'descripcion': descripcion,
              'marca': marca,
              'costo': costo,
              'precio': precio,
              'precioRappi': precioRappi,
              'stock': stock,
              'borrado': 0,
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
  // EXPORTAR A EXCEL (CON AUTO-AJUSTE Y SIN DEPENDENCIAS)
  // ------------------------------------------
  Future<void> _exportarExcel() async {
    setState(() => _importando = true);

    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('productos');
      List<Producto> productos = List.generate(maps.length, (i) => Producto.desdeMapa(maps[i]));

      var excel = Excel.createExcel();
      String sheetName = 'Inventario';
      Sheet sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // --- LÓGICA DE AUTO-ANCHO ---
      Map<int, double> anchosColumnas = {
        0: 15.0, 1: 10.0, 2: 15.0, 3: 30.0, 4: 10.0, 5: 12.0, 6: 12.0, 7: 8.0,
      };

      void checkWidth(int colIndex, String text) {
        double anchoEstimado = text.length * 1.2;
        if (anchoEstimado < 8) anchoEstimado = 8;
        if (anchosColumnas[colIndex] == null || anchoEstimado > anchosColumnas[colIndex]!) {
          anchosColumnas[colIndex] = anchoEstimado;
        }
      }

      List<String> titulos = ['Código', 'Factura', 'Marca', 'Descripción', 'Costo', 'Precio Público', 'Precio Rappi', 'Stock'];
      List<CellValue> headers = titulos.map((e) => TextCellValue(e)).toList();
      sheetObject.appendRow(headers);

      for (var p in productos) {
        String vCodigo = p.codigo;
        String vFactura = p.factura;
        String vMarca = p.marca;
        String vDesc = p.descripcion;

        checkWidth(0, vCodigo);
        checkWidth(1, vFactura);
        checkWidth(2, vMarca);
        checkWidth(3, vDesc);

        List<CellValue> row = [
          TextCellValue(vCodigo),
          TextCellValue(vFactura),
          TextCellValue(vMarca),
          TextCellValue(vDesc),
          DoubleCellValue(p.costo),
          DoubleCellValue(p.precio),
          DoubleCellValue(p.precioRappi),
          IntCellValue(p.stock),
        ];
        sheetObject.appendRow(row);
      }

      for (int i = 0; i < 8; i++) {
        double anchoFinal = anchosColumnas[i] ?? 10.0;
        if (anchoFinal > 60) anchoFinal = 60;
        sheetObject.setColumnWidth(i, anchoFinal);
      }

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

        // ÉXITO: Usamos SnackBar estándar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado exitosamente en: $filePath')),
        );
      }
    } catch (e) {
      // ERROR: Usamos Dialog directo sin depender de función externa
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Error al Exportar"),
          content: SingleChildScrollView(child: Text(e.toString())),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
        ),
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