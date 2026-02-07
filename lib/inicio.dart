import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import 'constants/colores.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'venta.dart';
import 'productos.dart';
import 'nuevo_ingreso.dart';
import 'deudas.dart'; // Módulo de Deudas
import 'calendario_ventas.dart'; // Módulo Unificado de Calendario

class Inicio extends StatefulWidget {
  const Inicio({Key? key}) : super(key: key);

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  String _seccionActual = 'venta';
  bool _importando = false;

  // ------------------------------------------
  // EXPORTAR A EXCEL (TU CÓDIGO ORIGINAL)
  // ------------------------------------------
  Future<void> _exportarExcel() async {
    setState(() => _importando = true);

    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('productos');
      List<Producto> productos = List.generate(maps.length, (i) => Producto.desdeMapa(maps[i]));

      var excel = Excel.createExcel();
      String sheetName = 'Precios MENUDEO';
      Sheet sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // ENCABEZADOS
      List<String> titulos = [
        'Código',         // A - 0
        'Inventario',     // B - 1
        'Factura',        // C - 2
        'SKU',            // D - 3
        'Marca',          // E - 4
        'Descripción',    // F - 5
        'Costo',          // G - 6
        'Precio Público', // H - 7
        'Costo Rappi'     // I - 8
      ];

      sheetObject.appendRow(titulos.map((e) => TextCellValue(e)).toList());

      // LLENAR DATOS
      Map<int, double> anchos = {};
      void checkW(int col, String txt) {
        double len = txt.length * 1.1;
        if (len < 10) len = 10;
        if (anchos[col] == null || len > anchos[col]!) anchos[col] = len;
      }

      for (var p in productos) {
        String vCod = p.codigo;
        String vStock = p.stock.toString();
        String vFact = p.factura;
        String vSku = p.sku;
        String vMarca = p.marca;
        String vDesc = p.descripcion;

        checkW(0, vCod); checkW(1, vStock); checkW(2, vFact); checkW(3, vSku);
        checkW(4, vMarca); checkW(5, vDesc);

        List<CellValue> row = [
          TextCellValue(vCod),
          IntCellValue(p.stock),
          TextCellValue(vFact),
          TextCellValue(vSku),
          TextCellValue(vMarca),
          TextCellValue(vDesc),
          DoubleCellValue(p.costo),
          DoubleCellValue(p.precio),
          DoubleCellValue(p.precioRappi),
        ];
        sheetObject.appendRow(row);
      }

      // Aplicar anchos
      for (int i = 0; i < titulos.length; i++) {
        double w = anchos[i] ?? 12.0;
        if (w > 70) w = 70;
        sheetObject.setColumnWidth(i, w);
      }

      // Guardar
      Directory? directory;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        directory = await getDownloadsDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      String fecha = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      String filePath = "${directory.path}/Inventario_KSystem_$fecha.xlsx";

      var fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        _mostrarAlerta("Exportación Exitosa", "Archivo guardado en:\n$filePath");
      }
    } catch (e) {
      _mostrarAlerta("Error Exportar", e.toString());
    } finally {
      setState(() => _importando = false);
    }
  }

  // ------------------------------------------
  // IMPORTAR DESDE EXCEL (TU CÓDIGO ORIGINAL)
  // ------------------------------------------
  Future<void> _importarExcel() async {
    setState(() => _importando = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        Sheet? sheet = excel.tables['Precios MENUDEO'];
        sheet ??= excel.tables[excel.tables.keys.first];

        if (sheet != null && sheet.maxRows > 1) {

          // DETECTAR FORMATO
          List<Data?> headerRow = sheet.row(0);
          String firstHeader = headerRow.isNotEmpty ? headerRow[0]?.value.toString().trim() ?? '' : '';
          bool esFormatoApp = firstHeader.toLowerCase().contains("código") || firstHeader.toLowerCase().contains("codigo");

          List<Producto> productosNuevos = [];
          List<Producto> productosExistentesEnExcel = [];

          // Helpers seguros
          dynamic val(List<Data?> row, int i) => (i < row.length) ? row[i]?.value : null;
          String str(dynamic v) => v?.toString().trim() ?? '';
          double dbl(dynamic v) {
            if (v == null) return 0.0;
            return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          }

          // LEER FILAS
          for (int r = 1; r < sheet.maxRows; r++) {
            List<Data?> row = sheet.row(r);
            if (row.isEmpty) continue;

            String codigo = '';
            String stockStr = '';
            String factura = '';
            String sku = '';
            String marca = '';
            String descripcion = '';
            double costo = 0.0;

            // Variables de precio que calcularemos nosotros
            double precio = 0.0;
            double rappi = 0.0;

            try {
              if (esFormatoApp) {
                // FORMATO APP (9 columnas)
                codigo = str(val(row, 0));
                stockStr = str(val(row, 1));
                factura = str(val(row, 2));
                sku = str(val(row, 3));
                marca = str(val(row, 4));
                descripcion = str(val(row, 5));
                costo = dbl(val(row, 6));
              } else {
                // FORMATO ORIGINAL (8 columnas)
                stockStr = str(val(row, 0));
                factura = str(val(row, 1));
                sku = str(val(row, 2));
                marca = str(val(row, 3));
                descripcion = str(val(row, 4));
                costo = dbl(val(row, 5));
                codigo = "GEN-${DateTime.now().millisecondsSinceEpoch}-$r";
              }

              if (descripcion.isEmpty) continue;

              // --- CÁLCULO FORZADO DE PRECIOS (REGLA 48%) ---
              if (costo > 0) {
                // Precio Público = Costo + 48%
                precio = double.parse((costo * 1.48).toStringAsFixed(2));
                // Rappi = Precio Público + 35%
                rappi = double.parse((precio * 1.35).toStringAsFixed(2));
              }

              int stock = int.tryParse(stockStr) ?? 0;

              Producto p = Producto(
                  codigo: codigo,
                  sku: sku,
                  factura: factura,
                  marca: marca,
                  descripcion: descripcion,
                  costo: costo,
                  precio: precio,
                  precioRappi: rappi,
                  stock: stock,
                  borrado: false
              );

              // DETECCIÓN DE DUPLICADOS
              bool existe = false;
              int? idBd;

              if (esFormatoApp && !codigo.startsWith("GEN-")) {
                final porCodigo = await DBHelper.instance.getProductoPorCodigo(codigo);
                if (porCodigo != null) {
                  existe = true;
                  idBd = porCodigo['id'];
                }
              }

              if (!existe) {
                final porNombre = await DBHelper.instance.buscarProductos(descripcion);
                var match = porNombre.firstWhere(
                        (element) => element['descripcion'].toString().toLowerCase() == descripcion.toLowerCase(),
                    orElse: () => {}
                );

                if (match.isNotEmpty) {
                  existe = true;
                  idBd = match['id'];
                  String codigoBd = match['codigo'];
                  if (!codigoBd.startsWith("GEN-")) {
                    p.codigo = codigoBd;
                  }
                }
              }

              if (existe) {
                p.id = idBd;
                productosExistentesEnExcel.add(p);
              } else {
                productosNuevos.add(p);
              }

            } catch (e) {
              print("Error fila $r: $e");
            }
          }

          // FLUJO DE DECISIÓN
          bool actualizarExistentes = false;
          bool cancelar = false;

          if (productosExistentesEnExcel.isNotEmpty) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text("⚠️ Duplicados Detectados"),
                content: Text(
                    "Hay ${productosExistentesEnExcel.length} productos que ya existen.\n\n"
                        "Se recalcularán sus precios al 48% de margen basándose en el COSTO del Excel.\n"
                        "¿Deseas aplicar estos cambios?"
                ),
                actions: [
                  TextButton(
                    onPressed: () { cancelar = true; Navigator.pop(ctx); },
                    child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      actualizarExistentes = false;
                      Navigator.pop(ctx);
                    },
                    child: const Text("Ignorar (Solo Nuevos)"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colores.azulCielo, foregroundColor: Colors.white),
                    onPressed: () {
                      actualizarExistentes = true;
                      Navigator.pop(ctx);
                    },
                    child: const Text("ACTUALIZAR PRECIOS"),
                  )
                ],
              ),
            );
          }

          if (cancelar) {
            setState(() => _importando = false);
            return;
          }

          // GUARDAR
          int insertados = 0;
          int actualizados = 0;

          for (var p in productosNuevos) {
            await DBHelper.instance.insertProducto(p.aMapa());
            insertados++;
          }

          if (actualizarExistentes) {
            for (var p in productosExistentesEnExcel) {
              if (p.id != null) {
                await DBHelper.instance.updateProducto(p.aMapa());
                actualizados++;
              }
            }
          }

          _mostrarAlerta(
              "Importación Finalizada",
              "Nuevos agregados: $insertados\n"
                  "Actualizados (Margen 48%): $actualizados\n"
                  "Total procesados: ${insertados + actualizados}"
          );
        }
      }
    } catch (e) {
      _mostrarAlerta("Error Crítico", e.toString());
    } finally {
      setState(() => _importando = false);
    }
  }

  void _mostrarAlerta(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(mensaje)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  // --- SELECCIÓN DE VISTAS (Aquí integramos los nuevos módulos) ---
  Widget _contenido() {
    if (_importando) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Recalculando precios y procesando..."),
        ],
      ));
    }

    switch (_seccionActual) {
      case 'venta': return const Venta();
      case 'deudas': return const Deudas(); // Nuevo Módulo Deudas
      case 'calendario': return const CalendarioVentas(); // Nuevo Módulo Calendario
      case 'anadir': return const NuevoIngreso();
      case 'consultar': return const Productos();
      default: return const Venta();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- BARRA LATERAL (Restaurada al estilo original) ---
          Container(
            width: 230,
            color: Colores.grisOscuro, // Usando tu color original
            child: Column(
              children: [
                const SizedBox(height: 30),
                // Logo textual (Sin "tiendita", estilo original)
                const Text('KTOOLS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const Text('Local System', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Text('By: Ferplace', style: TextStyle(color: Colors.grey, fontSize: 8)),
                const SizedBox(height: 40),

                // MENÚ PRINCIPAL
                _buildMenuItem(Icons.point_of_sale, 'Venta', 'venta'),
                _buildMenuItem(Icons.money_off, 'Deudas / Fiado', 'deudas'),
                _buildMenuItem(Icons.calendar_month, 'Calendario', 'calendario'), // Reemplaza a Historial y Ventas Hoy
                _buildMenuItem(Icons.add_circle_outline, 'Añadir', 'anadir'),
                _buildMenuItem(Icons.list_alt, 'Consultar', 'consultar'),

                const Divider(color: Colors.grey),

                // EXCEL (RESTAURADO)
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

                const Spacer(),

                // --- VERSIÓN SOLICITADA ---
                const Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("v1.2.0", style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),

          // CONTENIDO PRINCIPAL
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _contenido(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String seccion) {
    bool isSelected = _seccionActual == seccion;
    return Container(
      color: isSelected ? Colors.white.withOpacity(0.1) : null,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colores.azulCielo : Colors.white),
        title: Text(title, style: TextStyle(color: isSelected ? Colores.azulCielo : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        onTap: () => setState(() => _seccionActual = seccion),
      ),
    );
  }
}