import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'agotados.dart';

import 'constants/colores.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'venta.dart';
import 'productos.dart';
import 'nuevo_ingreso.dart';
import 'deudas.dart'; // Módulo de Deudas
import 'calendario_ventas.dart'; // Módulo Unificado de Calendario
import 'pedidos.dart';

class Inicio extends StatefulWidget {
  const Inicio({Key? key}) : super(key: key);

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  String _seccionActual = 'venta';
  bool _importando = false;

  // ------------------------------------------
  // EXPORTAR A EXCEL (Versión Unificada Multi-hoja)
  // ------------------------------------------
  Future<void> _exportarExcel() async {
    setState(() => _importando = true);

    try {
      final db = await DBHelper.instance.database;
      var excel = Excel.createExcel();

      // 1. HOJA DE PRODUCTOS (INVENTARIO)
      String sheetProd = 'Inventario';
      excel.rename(excel.getDefaultSheet()!, sheetProd);
      Sheet sProd = excel[sheetProd];
      List<String> hProd = ['Código', 'Stock', 'Ubicación', 'SKU', 'Marca', 'Descripción', 'Costo', 'Precio', 'PrecioRappi'];
      sProd.appendRow(hProd.map((e) => TextCellValue(e)).toList());

      final List<Map<String, dynamic>> mapsProd = await db.query('productos', where: 'borrado = 0');
      for (var p in mapsProd) {
        sProd.appendRow([
          TextCellValue(p['codigo'].toString()),
          IntCellValue(p['stock'] ?? 0),
          TextCellValue(p['ubicacion'] ?? ''),
          TextCellValue(p['sku'] ?? ''),
          TextCellValue(p['marca'] ?? ''),
          TextCellValue(p['descripcion'] ?? ''),
          DoubleCellValue((p['costo'] as num).toDouble()),
          DoubleCellValue((p['precio'] as num).toDouble()),
          DoubleCellValue((p['precioRappi'] as num).toDouble()),
        ]);
      }

      // 2. HOJA DE HISTORIAL DE VENTAS
      String sheetVentas = 'Historial_Ventas';
      Sheet sVentas = excel[sheetVentas];
      List<String> hVentas = ['ID', 'Folio', 'Fecha', 'Total', 'Costo_Total', 'Items', 'Cliente'];
      sVentas.appendRow(hVentas.map((e) => TextCellValue(e)).toList());

      final List<Map<String, dynamic>> mapsVentas = await db.query('ventas_historial', orderBy: 'fecha DESC');
      for (var v in mapsVentas) {
        sVentas.appendRow([
          IntCellValue(v['id']),
          IntCellValue(v['folio_venta'] ?? 0),
          TextCellValue(v['fecha'] ?? ''),
          DoubleCellValue((v['total'] as num).toDouble()),
          DoubleCellValue((v['costo_total'] as num).toDouble()),
          TextCellValue(v['items'] ?? ''),
          TextCellValue(v['cliente'] ?? ''),
        ]);
      }

      // 3. HOJA DE DEUDORES
      String sheetDeudas = 'Deudores';
      Sheet sDeudas = excel[sheetDeudas];
      List<String> hDeudas = ['Nombre', 'Total_Deuda', 'Último_Fiado', 'Items'];
      sDeudas.appendRow(hDeudas.map((e) => TextCellValue(e)).toList());

      final List<Map<String, dynamic>> mapsDeudas = await db.query('deudores');
      for (var d in mapsDeudas) {
        sDeudas.appendRow([
          TextCellValue(d['nombre'] ?? ''),
          DoubleCellValue((d['total_deuda'] as num).toDouble()),
          TextCellValue(d['fecha_ultimo_fiado'] ?? ''),
          TextCellValue(d['items'] ?? ''),
        ]);
      }

      // 4. HOJA DE HISTORIAL DE INGRESOS
      String sheetIngresos = 'Historial_Ingresos';
      Sheet sIngresos = excel[sheetIngresos];
      List<String> hIngresos = ['ID', 'Producto', 'Cantidad', 'Fecha', 'Acción'];
      sIngresos.appendRow(hIngresos.map((e) => TextCellValue(e)).toList());

      final List<Map<String, dynamic>> mapsIngresos = await db.query('historial_ingresos', orderBy: 'fecha_ingreso DESC');
      for (var i in mapsIngresos) {
        sIngresos.appendRow([
          IntCellValue(i['id']),
          TextCellValue(i['codigo_producto'] ?? ''),
          IntCellValue(i['cantidad'] ?? 0),
          TextCellValue(i['fecha_ingreso'] ?? ''),
          TextCellValue(i['accion'] ?? ''),
        ]);
      }

      // Guardar
      Directory? directory;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        directory = await getDownloadsDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      String fecha = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      String filePath = "${directory.path}/Respaldo_KSystem_$fecha.xlsx";

      var fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        _mostrarAlerta("Exportación Exitosa", "Se ha generado el respaldo en Excel correctamente.\n\nUbicación:\n$filePath");
      }
    } catch (e) {
      _mostrarAlerta("Error al exportar", e.toString());
    } finally {
      setState(() => _importando = false);
    }
  }

  // ------------------------------------------
  // IMPORTAR DESDE EXCEL (Master Sync - Sobrescribe Inventario)
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

        // Priorizamos la hoja de 'Inventario'
        Sheet? sheet = excel.tables['Inventario'] ?? excel.tables['Precios MENUDEO'];
        sheet ??= excel.tables[excel.tables.keys.first];

        if (sheet != null && sheet.maxRows > 1) {
          
          List<Producto> productosDelExcel = [];

          // Helpers seguros
          dynamic val(List<Data?> row, int i) => (i < row.length) ? row[i]?.value : null;
          String str(dynamic v) => v?.toString().trim() ?? '';
          double dbl(dynamic v) {
            if (v == null) return 0.0;
            return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            List<Data?> row = sheet.row(r);
            if (row.isEmpty) continue;

            String codigo = str(val(row, 0));
            int stock = int.tryParse(str(val(row, 1))) ?? 0;
            String ubicacion = str(val(row, 2));
            String sku = str(val(row, 3));
            String marca = str(val(row, 4));
            String descripcion = str(val(row, 5));
            double costo = dbl(val(row, 6));
            double precio = dbl(val(row, 7));
            double rappi = dbl(val(row, 8));

            if (descripcion.isEmpty) continue;

            productosDelExcel.add(Producto(
                codigo: codigo,
                sku: sku,
                factura: "",
                ubicacion: ubicacion,
                marca: marca,
                descripcion: descripcion,
                costo: costo,
                precio: precio,
                precioRappi: rappi,
                stock: stock,
                borrado: false
            ));
          }

          // ADVERTENCIA DE SOBRESCRITURA
          bool confirmar = false;
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              title: const Text("ADVERTENCIA: SINCRONIZACIÓN DE INVENTARIO"),
              content: Text(
                  "Se procederá a actualizar el inventario con los datos del archivo seleccionado.\n\n"
                  "1. Se eliminarán los productos actuales.\n"
                  "2. Se cargarán ${productosDelExcel.length} productos desde el Excel.\n\n"
                  "¿Desea continuar con la sincronización?"
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () { confirmar = true; Navigator.pop(ctx); },
                  child: const Text("Confirmar Sincronización"),
                ),
              ],
            )
          );

          if (!confirmar) return;

          // EJECUCIÓN MAESTRA (Transacción)
          final db = await DBHelper.instance.database;
          await db.transaction((txn) async {
            // 1. Borrar tabla productos
            await txn.delete('productos');
            
            // 2. Insertar nuevos
            for (var p in productosDelExcel) {
              await txn.insert('productos', p.aMapa());
            }
          });

          _mostrarAlerta("Sincronización Finalizada", "El inventario ha sido actualizado correctamente.\n\nTotal productos cargados: ${productosDelExcel.length}");
        }
      }
    } catch (e) {
      _mostrarAlerta("Error al importar", e.toString());
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
          Text("Analizando precios..."),
        ],
      ));
    }

    switch (_seccionActual) {
      case 'venta': return const Venta();
      case 'deudas': return const Deudas(); // Nuevo Módulo Deudas
      case 'calendario': return const CalendarioVentas(); // Nuevo Módulo Calendario
      case 'pedidos': return const Pedidos();
      case 'anadir': return const NuevoIngreso();
      case 'agotados': return const Agotados();
      case 'consultar': return const Productos();
      default: return const Venta();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: isDesktop
              ? null
              : AppBar(
                  backgroundColor: Colores.grisOscuro,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text('KTOOLS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
          drawer: isDesktop ? null : _buildSidebar(isDrawer: true),
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(isDrawer: false),
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
      },
    );
  }

  Widget _buildSidebar({required bool isDrawer}) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colores.grisOscuro,
            Color(0xFF0D1B2A), // Azul muy oscuro (Navy)
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Logo textual (Sin "tiendita", estilo original)
          const Text('KTOOLS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const Text('Local System', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const Text('By: Ferplace', style: TextStyle(color: Colors.grey, fontSize: 8)),
          const SizedBox(height: 40),

          // MENÚ PRINCIPAL
          _buildMenuItem(Icons.point_of_sale, 'Venta', 'venta', isDrawer),
          _buildMenuItem(Icons.shopping_bag, 'Pedidos', 'pedidos', isDrawer),
          _buildMenuItem(Icons.money_off, 'Fiado', 'deudas', isDrawer),
          _buildMenuItem(Icons.calendar_month, 'Calendario', 'calendario', isDrawer), // Reemplaza a Historial y Ventas Hoy
          _buildMenuItem(Icons.add_circle_outline, 'Añadir', 'anadir', isDrawer),
          _buildMenuItem(Icons.warning_amber_rounded, 'Agotados', 'agotados', isDrawer),
          _buildMenuItem(Icons.list_alt, 'Consultar', 'consultar', isDrawer),

          const Divider(color: Colors.grey),

          // EXCEL (RESTAURADO)
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.white70),
            title: const Text('Importar Excel', style: TextStyle(color: Colors.white70, fontSize: 14)),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              _importarExcel();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white70),
            title: const Text('Exportar Excel', style: TextStyle(color: Colors.white70, fontSize: 14)),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              _exportarExcel();
            },
          ),

          const Spacer(),

          // --- VERSIÓN SOLICITADA ---
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("v2.3.1", style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String seccion, bool isDrawer) {
    bool isSelected = _seccionActual == seccion;

    BoxDecoration? decoration;
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4);

    if (isSelected) {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      );
    } else if (seccion == 'venta') {
      decoration = BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1),
      );
    } else if (seccion == 'pedidos') {
      decoration = BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1),
      );
    } else if (seccion == 'anadir') {
      decoration = BoxDecoration(
        color: const Color(0xFF003366).withValues(alpha: 0.6), // Azul oscuro
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 1),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: isSelected ? Colores.azulCielo : Colors.white),
        title: Text(title,
            style: TextStyle(
                color: isSelected ? Colores.azulCielo : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        onTap: () {
          setState(() => _seccionActual = seccion);
          if (isDrawer) Navigator.pop(context);
        },
      ),
    );
  }
}
