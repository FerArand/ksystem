import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'widgets/product_form_dialog.dart';

class Agotados extends StatefulWidget {
  const Agotados({Key? key}) : super(key: key);

  @override
  State<Agotados> createState() => _AgotadosState();
}

class _AgotadosState extends State<Agotados> {
  List<Producto> _listaAgotados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarAgotados();
  }

  Future<void> _cargarAgotados() async {
    // Usamos la nueva función del Helper
    final maps = await DBHelper.instance.getProductosAgotados();
    setState(() {
      _listaAgotados = maps.map((e) => Producto.desdeMapa(e)).toList();
      _cargando = false;
    });
  }

  Future<void> _modificarStock(Producto p, int cantidad) async {
    await DBHelper.instance.updateStock(p.codigo, cantidad);
    // Recargamos para ver si ya sale de la lista de agotados o cambia el número
    _cargarAgotados();
  }

  void _abrirEdicion(Producto p) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ProductFormDialog(
          productoExistente: p,
          onGuardado: (prodActualizado) {
            _cargarAgotados();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto actualizado")));
          },
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Productos Agotados / Stock Negativo",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _listaAgotados.isEmpty
              ? const Center(child: Text("¡Excelente! No hay productos agotados.", style: TextStyle(fontSize: 18)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _listaAgotados.length,
            itemBuilder: (ctx, i) {
              final p = _listaAgotados[i];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
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
                                Text("Marca: ${p.marca}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            tooltip: "Editar",
                            onPressed: () => _abrirEdicion(p),
                          ),
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.red[50], // Fondo rojo suave para resaltar alerta
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red.shade200)
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.red, size: 20),
                                  onPressed: () => _modificarStock(p, -1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                      "${p.stock}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red) // Texto rojo
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: Colors.green, size: 20),
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