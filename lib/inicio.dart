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
import 'deudas.dart';
import 'calendario_ventas.dart';
import 'pedidos.dart';

class Inicio extends StatefulWidget {
  const Inicio({Key? key}) : super(key: key);

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  String _seccionActual = 'venta';
  bool _importando = false;

  Future<void> _exportarExcel() async {
    setState(() => _importando = true);

    try {
      final db = await DBHelper.instance.database;
      final excel = Excel.createExcel();

      // 1. HOJA DE PRODUCTOS (INVENTARIO)
      const String sheetProd = 'Inventario';
      excel.rename(excel.getDefaultSheet()!, sheetProd);
      final Sheet sProd = excel[sheetProd];
      final List<String> hProd = [
        'Código',
        'Stock',
        'Ubicación',
        'SKU',
        'Marca',
        'Descripción',
        'Costo',
        'Precio',
        'PrecioRappi',
        'Es_Granel',
      ];
      sProd.appendRow(hProd.map((e) => TextCellValue(e)).toList());

      final mapsProd = await db.query('productos', where: 'borrado = 0');
      for (final p in mapsProd) {
        sProd.appendRow([
          TextCellValue((p['codigo'] ?? '').toString()),
          DoubleCellValue((p['stock'] as num?)?.toDouble() ?? 0.0),
          TextCellValue((p['ubicacion'] ?? '').toString()),
          TextCellValue((p['sku'] ?? '').toString()),
          TextCellValue((p['marca'] ?? '').toString()),
          TextCellValue((p['descripcion'] ?? '').toString()),
          DoubleCellValue((p['costo'] as num?)?.toDouble() ?? 0.0),
          DoubleCellValue((p['precio'] as num?)?.toDouble() ?? 0.0),
          DoubleCellValue((p['precioRappi'] as num?)?.toDouble() ?? 0.0),
          IntCellValue((p['es_granel'] == 1) ? 1 : 0),
        ]);
      }

      // 2. HOJA DE HISTORIAL DE VENTAS
      const String sheetVentas = 'Historial_Ventas';
      final Sheet sVentas = excel[sheetVentas];
      final List<String> hVentas = [
        'ID',
        'Folio',
        'Fecha',
        'Total',
        'Costo_Total',
        'Metodo_Pago',
        'Items',
        'Cliente',
      ];
      sVentas.appendRow(hVentas.map((e) => TextCellValue(e)).toList());

      final mapsVentas = await db.query('ventas_historial', orderBy: 'fecha DESC');
      for (final v in mapsVentas) {
        sVentas.appendRow([
          IntCellValue((v['id'] as int?) ?? 0),
          TextCellValue((v['folio_venta'] ?? v['id'] ?? '').toString()),
          TextCellValue((v['fecha'] ?? '').toString()),
          DoubleCellValue((v['total'] as num?)?.toDouble() ?? 0.0),
          DoubleCellValue((v['costo_total'] as num?)?.toDouble() ?? 0.0),
          TextCellValue((v['metodo_pago'] ?? 'Efectivo').toString()),
          TextCellValue((v['items'] ?? '').toString()),
          TextCellValue((v['cliente'] ?? '').toString()),
        ]);
      }

      // 3. HOJA DE DEUDORES
      const String sheetDeudas = 'Deudores';
      final Sheet sDeudas = excel[sheetDeudas];
      final List<String> hDeudas = ['Nombre', 'Total_Deuda', 'Último_Fiado', 'Items'];
      sDeudas.appendRow(hDeudas.map((e) => TextCellValue(e)).toList());

      final mapsDeudas = await db.query('deudores');
      for (final d in mapsDeudas) {
        sDeudas.appendRow([
          TextCellValue((d['nombre'] ?? '').toString()),
          DoubleCellValue((d['total_deuda'] as num?)?.toDouble() ?? 0.0),
          TextCellValue((d['fecha_ultimo_fiado'] ?? '').toString()),
          TextCellValue((d['items'] ?? '').toString()),
        ]);
      }

      // 4. HOJA DE HISTORIAL DE INGRESOS
      const String sheetIngresos = 'Historial_Ingresos';
      final Sheet sIngresos = excel[sheetIngresos];
      final List<String> hIngresos = ['ID', 'Producto', 'Cantidad', 'Fecha', 'Acción'];
      sIngresos.appendRow(hIngresos.map((e) => TextCellValue(e)).toList());

      final mapsIngresos = await db.query('historial_ingresos', orderBy: 'fecha_ingreso DESC');
      for (final i in mapsIngresos) {
        sIngresos.appendRow([
          IntCellValue((i['id'] as int?) ?? 0),
          TextCellValue((i['codigo_producto'] ?? '').toString()),
          DoubleCellValue((i['cantidad'] as num?)?.toDouble() ?? 0.0),
          TextCellValue((i['fecha_ingreso'] ?? '').toString()),
          TextCellValue((i['accion'] ?? '').toString()),
        ]);
      }

      Directory? directory = await getDownloadsDirectory();
      directory ??= await getApplicationDocumentsDirectory();

      final String fecha = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      final String filePath = '${directory.path}/Respaldo_KSystem_$fecha.xlsx';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        _mostrarAlerta(
          'Exportación Exitosa',
          'Se ha generado el respaldo en Excel correctamente.\n\nUbicación:\n$filePath',
        );
      }
    } catch (e) {
      _mostrarAlerta('Error al exportar', e.toString());
    } finally {
      setState(() => _importando = false);
    }
  }

  Future<void> _importarExcel() async {
    setState(() => _importando = true);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final bytes = File(result.files.single.path!).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        Sheet? sheet = excel.tables['Inventario'] ?? excel.tables['Precios MENUDEO'];
        sheet ??= excel.tables[excel.tables.keys.first];

        if (sheet != null && sheet.maxRows > 1) {
          final List<Producto> productosDelExcel = [];

          dynamic val(List<Data?> row, int i) => (i < row.length) ? row[i]?.value : null;
          String str(dynamic v) => v?.toString().trim() ?? '';
          double dbl(dynamic v) {
            if (v == null) return 0.0;
            return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            final List<Data?> row = sheet.row(r);
            if (row.isEmpty) continue;

            final String codigo = str(val(row, 0));
            final double stock = dbl(val(row, 1));
            final String ubicacion = str(val(row, 2));
            final String sku = str(val(row, 3));
            final String marca = str(val(row, 4));
            final String descripcion = str(val(row, 5));
            final double costo = dbl(val(row, 6));
            final double precio = dbl(val(row, 7));
            final double rappi = dbl(val(row, 8));
            final bool esGranel = str(val(row, 9)) == '1' ||
                str(val(row, 9)).toLowerCase() == 'true';

            if (descripcion.isEmpty) continue;

            productosDelExcel.add(
              Producto(
                codigo: codigo,
                sku: sku,
                factura: '',
                ubicacion: ubicacion,
                marca: marca,
                descripcion: descripcion,
                costo: costo,
                precio: precio,
                precioRappi: rappi,
                stock: stock,
                esGranel: esGranel,
                borrado: false,
              ),
            );
          }

          bool confirmar = false;
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              title: const Text('ADVERTENCIA: SINCRONIZACIÓN DE INVENTARIO'),
              content: Text(
                'Se procederá a actualizar el inventario con los datos del archivo seleccionado.\n\n'
                    '1. Se reemplazarán los productos actuales.\n'
                    '2. Se cargarán ${productosDelExcel.length} productos desde el Excel.\n\n'
                    '¿Desea continuar con la sincronización?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    confirmar = true;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Confirmar Sincronización'),
                ),
              ],
            ),
          );

          if (!confirmar) return;

          final db = await DBHelper.instance.database;
          await db.transaction((txn) async {
            await txn.delete('productos');
            for (final p in productosDelExcel) {
              await txn.insert('productos', p.aMapa());
            }
          });

          _mostrarAlerta(
            'Sincronización Finalizada',
            'El inventario ha sido actualizado correctamente.\n\nTotal productos cargados: ${productosDelExcel.length}',
          );
        }
      }
    } catch (e) {
      _mostrarAlerta('Error al importar', e.toString());
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_importando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Procesando archivo Excel...'),
          ],
        ),
      );
    }

    switch (_seccionActual) {
      case 'venta':
        return const Venta();
      case 'deudas':
        return const Deudas();
      case 'calendario':
        return const CalendarioVentas();
      case 'pedidos':
        return const Pedidos();
      case 'anadir':
        return const NuevoIngreso();
      case 'agotados':
        return const Agotados();
      case 'consultar':
        return const Productos();
      default:
        return const Venta();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: isDesktop
              ? null
              : AppBar(
            backgroundColor: Colores.grisOscuro,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'KTOOLS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          drawer: isDesktop ? null : _buildSidebar(isDrawer: true),
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(isDrawer: false),
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
            Color(0xFF0D1B2A),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'KTOOLS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Text('Ksystem POS Desktop', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const Text('By: Ferplace', style: TextStyle(color: Colors.grey, fontSize: 8)),
          const SizedBox(height: 40),
          _buildMenuItem(Icons.point_of_sale, 'Venta', 'venta', isDrawer),
          _buildMenuItem(Icons.shopping_bag, 'Pedidos', 'pedidos', isDrawer),
          _buildMenuItem(Icons.money_off, 'Fiado', 'deudas', isDrawer),
          _buildMenuItem(Icons.calendar_month, 'Calendario', 'calendario', isDrawer),
          _buildMenuItem(Icons.add_circle_outline, 'Añadir', 'anadir', isDrawer),
          _buildMenuItem(Icons.warning_amber_rounded, 'Agotados', 'agotados', isDrawer),
          _buildMenuItem(Icons.list_alt, 'Consultar', 'consultar', isDrawer),
          const Divider(color: Colors.grey),
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
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'v2.5.0',
                style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String seccion, bool isDrawer) {
    final bool isSelected = _seccionActual == seccion;

    BoxDecoration? decoration;
    const EdgeInsets margin = EdgeInsets.symmetric(horizontal: 12, vertical: 4);

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
        color: const Color(0xFF003366).withValues(alpha: 0.6),
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
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colores.azulCielo : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _seccionActual = seccion);
          if (isDrawer) Navigator.pop(context);
        },
      ),
    );
  }
}