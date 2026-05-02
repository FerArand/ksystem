import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/product_card.dart';

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
          child: Text("Productos Agotados",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _listaAgotados.isEmpty
              ? const Center(child: Text("No hay productos agotados", style: TextStyle(fontSize: 18)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _listaAgotados.length,
            itemBuilder: (ctx, i) {
              final p = _listaAgotados[i];
              return ProductCard(
                producto: p,
                onEdit: () => _abrirEdicion(p),
                // OMITIMOS onDelete, así el botón de basurero no se dibuja
                onStockChange: (cantidad) => _modificarStock(p, cantidad),
                alertStock: true, // Pinta el contenedor de stock en rojo
              );
            },
          ),
        )
      ],
    );
  }
}