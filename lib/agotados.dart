import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/product_card.dart';
import 'constants/colores.dart';

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
        barrierDismissible: true,
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
        // --- ENCABEZADO UNIFICADO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(
            color: Colores.agotados,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 15),
              const Text("PRODUCTOS AGOTADOS", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: Colores.agotados))
              : _listaAgotados.isEmpty
              ? const Center(child: Text("No hay productos agotados", style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
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