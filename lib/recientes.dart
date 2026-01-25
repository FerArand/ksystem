import 'package:flutter/material.dart';
import 'databases/recent_db.dart';
import 'db_helper.dart'; // Tu DB principal
import 'models/producto.dart';
import 'constants/colores.dart';

class ProductosRecientes extends StatefulWidget {
  const ProductosRecientes({Key? key}) : super(key: key);

  @override
  State<ProductosRecientes> createState() => _ProductosRecientesState();
}

class _ProductosRecientesState extends State<ProductosRecientes> {
  List<Producto> _listaRecientes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // 1. Obtener IDs de la BD de recientes
    final codigos = await RecentDB.instance.obtenerCodigosRecientes();

    if (codigos.isEmpty) {
      setState(() { _listaRecientes = []; _cargando = false; });
      return;
    }

    // 2. Buscar los detalles completos en la BD principal
    // (Sqflite no soporta WHERE IN con arrays directos fácilmente, hacemos un loop o query manual)
    List<Producto> temp = [];
    for (String cod in codigos) {
      final data = await DBHelper.instance.getProductoPorCodigo(cod);
      if (data != null) {
        temp.add(Producto.desdeMapa(data));
      }
    }

    setState(() {
      _listaRecientes = temp;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Productos añadidos en los últimos 7 días", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _listaRecientes.isEmpty
              ? const Center(child: Text("No has añadido productos recientemente."))
              : ListView.builder(
              itemCount: _listaRecientes.length,
              itemBuilder: (ctx, i) {
                final p = _listaRecientes[i];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: ListTile(
                    leading: const Icon(Icons.new_releases, color: Colors.orange),
                    title: Text(p.descripcion),
                    subtitle: Text("Código: ${p.codigo} | Precio: \$${p.precio}"),
                    trailing: Text("Stock: ${p.stock}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }
          ),
        ),
      ],
    );
  }
}