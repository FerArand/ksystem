import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'widgets/product_form_dialog.dart'; // <--- Importamos el formulario unificado

class Productos extends StatefulWidget {
  const Productos({Key? key}) : super(key: key);

  @override
  State<Productos> createState() => _ProductosState();
}

class _ProductosState extends State<Productos> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  List<Producto> _listaProductos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  // Carga productos desde BD
  Future<void> _cargarProductos() async {
    final db = await DBHelper.instance.database;
    List<Map<String, dynamic>> maps;

    if (_query.isEmpty) {
      maps = await db.query('productos', orderBy: 'descripcion ASC', limit: 100);
    } else {
      maps = await db.query(
          'productos',
          where: 'descripcion LIKE ? OR codigo LIKE ? OR sku LIKE ? OR marca LIKE ?',
          whereArgs: ['%$_query%', '%$_query%', '%$_query%', '%$_query%']
      );
    }

    setState(() {
      _listaProductos = maps.map((e) => Producto.desdeMapa(e)).toList();
      _cargando = false;
    });
  }

  // --- MODIFICAR STOCK RÁPIDO (+/-) ---
  Future<void> _modificarStock(Producto p, int cantidad) async {
    await DBHelper.instance.updateStock(p.codigo, cantidad);
    setState(() {
      p.stock += cantidad;
    });
  }

  // --- ELIMINAR ---
  Future<void> _borrar(Producto p) async {
    bool? conf = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: const Text("¿Eliminar Producto?"),
            content: Text("Se borrará permanentemente: ${p.descripcion}"),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("BORRAR", style: TextStyle(color: Colors.red))),
            ]
        )
    );

    if(conf == true) {
      await DBHelper.instance.deleteProducto(p.id!);
      _cargarProductos();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado")));
    }
  }

  // --- NUEVA FUNCIÓN UNIFICADA PARA EDITAR ---
  void _abrirEdicion(Producto p) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ProductFormDialog(
          productoExistente: p, // Pasamos el producto para que rellene los datos
          onGuardado: (prodActualizado) {
            // Al guardar, refrescamos la lista
            _cargarProductos();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto actualizado")));
          },
        )
    );
  }

  // --- VISTA PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BARRA DE BÚSQUEDA
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
                labelText: "Consultar inventario (Nombre, Código, Marca, SKU)...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white
            ),
            onChanged: (v) {
              _query = v;
              setState(() => _cargando = true);
              _cargarProductos();
            },
          ),
        ),

        // LISTA DE PRODUCTOS (Estilo Tarjeta Renovado)
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _listaProductos.isEmpty
              ? const Center(child: Text("No hay productos.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _listaProductos.length,
            itemBuilder: (ctx, i) {
              final p = _listaProductos[i];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // FILA 1: DATOS PRINCIPALES
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text("Código: ${p.codigo} | SKU: ${p.sku}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                Text("Marca: ${p.marca} | Factura: ${p.factura}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text("\$${p.precio.toStringAsFixed(2)}", style: TextStyle(color: Colores.azulCielo, fontWeight: FontWeight.bold, fontSize: 20)),
                              const Text("P. Público", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                      const Divider(),

                      // FILA 2: CONTROLES Y ACCIONES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // BOTONES DE ACCIÓN (Editar / Eliminar)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                tooltip: "Editar",
                                onPressed: () => _abrirEdicion(p), // <-- USAMOS LA NUEVA FUNCIÓN
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: "Eliminar",
                                onPressed: () => _borrar(p),
                              ),
                            ],
                          ),

                          // CONTROL DE STOCK RÁPIDO
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300)
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.red, size: 20),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  onPressed: () => _modificarStock(p, -1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                      "${p.stock}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: Colors.green, size: 20),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  onPressed: () => _modificarStock(p, 1),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}