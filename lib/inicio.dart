import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'constants/colores.dart';
import 'productos.dart';
import 'venta.dart';
import 'auth_helpers.dart';
import 'lista_usuario.dart';

class Inicio extends StatefulWidget {
  const Inicio({Key? key}) : super(key: key);

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  String _seccionActual = 'productos';
  bool _importando = false;

  //importación desde excel
  Future<void> _importarExcel() async {
    setState(() => _importando = true);

    try {
      final usuario = usuarioActualONulo();
      if (usuario == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para importar productos.'),
          ),
        );
        return;
      }

      final productosRef = coleccionProductosUsuario();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        var excel = Excel.decodeBytes(bytes);
        Sheet? sheet = excel.tables['Precios MENUDEO'];

        if (sheet != null) {
          WriteBatch batch = FirebaseFirestore.instance.batch();
          int count = 0;

          dynamic getCell(Data? cell) {
            if (cell == null) return null;
            var v = cell.value;
            if (v == null) return null;
            if (v is FormulaCellValue) return null;
            if (v is BoolCellValue) return v.value;
            if (v is IntCellValue) return v.value;
            if (v is DoubleCellValue) return v.value;
            if (v is TextCellValue) return v.value;
            return v;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            List<Data?> row = sheet.row(r);

            var facturaCell = getCell(row.length > 1 ? row[1] : null);
            var descripcionCell = getCell(row.length > 3 ? row[3] : null);
            var costoCell = getCell(row.length > 4 ? row[4] : null);

            if (facturaCell == null || descripcionCell == null || costoCell == null) continue;

            String factura = facturaCell.toString().trim();
            String descripcion = descripcionCell.toString().trim();

            var marcaCell = getCell(row.length > 2 ? row[2] : null);
            String marca = marcaCell?.toString().trim() ?? '';

            int stock = 0;
            var stockCell = getCell(row.length > 0 ? row[0] : null);
            if (stockCell != null) stock = (stockCell as num).toInt();

            double costo = (costoCell as num).toDouble();

            double precio = double.parse((costo * 1.46).toStringAsFixed(2));
            double precioRappi = double.parse((precio * 1.35).toStringAsFixed(2));

            Map<String, dynamic> data = {
              'factura': factura,
              'descripcion': descripcion,
              'marca': marca,
              'costo': costo,
              'precio': precio,
              'precioRappi': precioRappi,
              'stock': stock,
              'borrado': false,
            };

            batch.set(productosRef.doc(factura), data);

            if (++count % 500 == 0) {
              await batch.commit();
              batch = FirebaseFirestore.instance.batch();
            }
          }

          await batch.commit();
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
  // CERRAR SESIÓN
  // ------------------------------------------
  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  // ------------------------------------------
  // CONTENIDO CENTRAL
  // ------------------------------------------
  Widget _contenido() {
    if (_importando) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_seccionActual) {
      case 'productos':
        return const Productos();
      case 'venta':
        return const Venta();
      default:
        return const Productos();
    }
  }

  // ------------------------------------------
  // UI
  // ------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // BARRA SUPERIOR
          Container(
            color: Colores.azulCielo,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            height: 50,
            alignment: Alignment.centerLeft,
            child: const Text(
              'KTOOLS',
              style: TextStyle(
                color: Colores.blanco,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // CONTENIDO PRINCIPAL
          Expanded(
            child: Row(
              children: [
                // MENÚ LATERAL
                Container(
                  width: 200,
                  color: Colores.grisOscuro,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Productos',
                              style: TextStyle(color: Colores.blanco),
                            ),
                            selected: _seccionActual == 'productos',
                            selectedTileColor: Colores.gris,
                            onTap: () {
                              setState(() => _seccionActual = 'productos');
                            },
                          ),
                          ListTile(
                            title: const Text(
                              'Nueva venta',
                              style: TextStyle(color: Colores.blanco),
                            ),
                            selected: _seccionActual == 'venta',
                            selectedTileColor: Colores.gris,
                            onTap: () {
                              setState(() => _seccionActual = 'venta');
                            },
                          ),
                          ListTile(
                            title: const Text(
                              'Importar Excel',
                              style: TextStyle(color: Colores.blanco),
                            ),
                            onTap: _importarExcel,
                          ),
                        ],
                      ),
                      ListTile(
                        title: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: Colores.blanco),
                        ),
                        onTap: _cerrarSesion,
                      ),
                    ],
                  ),
                ),

                // ÁREA BLANCA
                Expanded(child: _contenido()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}