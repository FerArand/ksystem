import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';

class Productos extends StatefulWidget {
  const Productos({Key? key}) : super(key: key);

  @override
  State<Productos> createState() => _ProductosState();
}

class _ProductosState extends State<Productos> {
  // Controlador para la barra de búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  // Lista de productos en memoria
  List<Producto> _listaProductos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  // Carga inicial o recarga
  Future<void> _cargarProductos() async {
    setState(() => _cargando = true);
    final db = await DBHelper.instance.database;

    List<Map<String, dynamic>> maps;

    if (_query.isEmpty) {
      // Si no hay búsqueda, traer todo (o limitar a 100 para optimizar)
      maps = await db.query('productos', orderBy: 'descripcion ASC');
    } else {
      // Búsqueda SQL
      maps = await db.query(
        'productos',
        where: 'descripcion LIKE ? OR codigo LIKE ? OR marca LIKE ?',
        whereArgs: ['%$_query%', '%$_query%', '%$_query%'],
      );
    }

    setState(() {
      _listaProductos = maps.map((e) => Producto.desdeMapa(e)).toList();
      _cargando = false;
    });
  }

  // Función para borrar (Lógica de "A la fosa")
  Future<void> _borrarProducto(int id) async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar definitivamente"),
        content: const Text("¿Estás seguro? Esto no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Borrar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DBHelper.instance.deleteProducto(id);
      _cargarProductos(); // Recargar lista
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado")));
    }
  }

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
              labelText: "Buscar por nombre, marca o código...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              setState(() => _query = val);
              _cargarProductos();
            },
          ),
        ),

        // LISTADO
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _listaProductos.isEmpty
              ? const Center(child: Text("No se encontraron productos."))
              : ListView.builder(
            itemCount: _listaProductos.length,
            itemBuilder: (context, index) {
              final p = _listaProductos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Cod: ${p.codigo} | Marca: ${p.marca} | Stock: ${p.stock}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "\$${p.precio.toStringAsFixed(2)}",
                        style: TextStyle(color: Colores.verde, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () {
                          if (p.id != null) _borrarProducto(p.id!);
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}