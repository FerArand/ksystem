import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'widgets/product_form_dialog.dart'; // <--- Importamos el formulario unificado
import 'widgets/product_card.dart';

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
          where: 'descripcion LIKE ? OR codigo LIKE ? OR sku LIKE ? OR marca LIKE ? OR ubicacion LIKE ?',
          whereArgs: ['%$_query%', '%$_query%', '%$_query%', '%$_query%', '%$_query%']
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
            title: const Text("¿Eliminar producto del sistema?"),
            content: Text("Se eliminará '${p.descripcion}' definitivamente."),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
            ]
        )
    );

    if(conf == true) {
      await DBHelper.instance.deleteProducto(p.id!);
      _cargarProductos();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado.")));
    }
  }

  // --- NUEVA FUNCIÓN UNIFICADA PARA EDITAR ---
  void _abrirEdicion(Producto p) {
    showDialog(
        context: context,
        barrierDismissible: true,
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
                labelText: "Buscar producto...",
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
              ? const Center(child: Text("No se encontraron productos", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _listaProductos.length,
            itemBuilder: (ctx, i) {
              final p = _listaProductos[i];
              return ProductCard(
                producto: p,
                onEdit: () => _abrirEdicion(p),
                onDelete: () => _borrar(p),
                onStockChange: (cantidad) => _modificarStock(p, cantidad),
              );
            },
          ),
        )
      ],
    );
  }
}