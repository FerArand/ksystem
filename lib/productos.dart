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
    // No ponemos _cargando = true aquí para evitar parpadeos molestos al sumar stock rápido
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
    // Actualizamos solo el elemento en la lista local para que sea instantáneo
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
      _cargarProductos(); // Recarga completa para quitarlo de la lista
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado")));
    }
  }

  // --- FORMULARIO DE EDICIÓN (IGUAL A NUEVO INGRESO) ---
  Future<void> _editarProducto(Producto p) async {
    final codigoController = TextEditingController(text: p.codigo);
    final descController = TextEditingController(text: p.descripcion);
    final marcaController = TextEditingController(text: p.marca);
    final costoController = TextEditingController(text: p.costo.toString());
    final skuController = TextEditingController(text: p.sku);
    final facturaController = TextEditingController(text: p.factura);
    final cantidadController = TextEditingController(text: p.stock.toString());

    // Calcular ganancia actual para mostrarla
    double gananciaInicial = 46.0;
    if (p.costo > 0) {
      gananciaInicial = ((p.precio / p.costo) - 1) * 100;
    }
    final gananciaController = TextEditingController(text: gananciaInicial.toStringAsFixed(1));

    final ValueNotifier<double> precioCalculado = ValueNotifier(p.precio);
    final _formKey = GlobalKey<FormState>();

    void _calcular() {
      double c = double.tryParse(costoController.text) ?? 0;
      double g = double.tryParse(gananciaController.text) ?? 0;
      precioCalculado.value = c * (1 + (g / 100));
    }
    costoController.addListener(_calcular);
    gananciaController.addListener(_calcular);

    InputDecoration decoracion(String label, {bool obligatorio = false, String? suffix}) {
      return InputDecoration(
          label: RichText(text: TextSpan(text: label, style: const TextStyle(color: Colors.black87), children: obligatorio ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [])),
          suffixText: suffix, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
      );
    }
    String? validar(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Producto"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: codigoController, decoration: decoracion("Código Barras", obligatorio: true), validator: validar),
                  const SizedBox(height: 10),
                  TextFormField(controller: descController, decoration: decoracion("Descripción", obligatorio: true), validator: validar, maxLines: 2),
                  const SizedBox(height: 10),
                  TextFormField(controller: marcaController, decoration: decoracion("Marca", obligatorio: true), validator: validar),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField(controller: costoController, decoration: decoracion("Costo", obligatorio: true, suffix: "\$"), keyboardType: TextInputType.number, validator: validar)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: gananciaController, decoration: decoracion("Ganancia", obligatorio: true, suffix: "%"), keyboardType: TextInputType.number, validator: validar)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ValueListenableBuilder<double>(valueListenable: precioCalculado, builder: (c, v, _) => Container(
                        width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.blue[50],
                        child: Text("Nuevo Precio Público: \$${v.toStringAsFixed(2)}", textAlign: TextAlign.center, style: TextStyle(color: Colores.azulCielo, fontWeight: FontWeight.bold))
                    )),
                  ),
                  Row(children: [
                    Expanded(child: TextFormField(controller: skuController, decoration: decoracion("SKU (Opcional)"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: facturaController, decoration: decoracion("Factura (Opcional)"))),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(controller: cantidadController, decoration: decoracion("Inventario Actual"), keyboardType: TextInputType.number),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colores.azulCielo, foregroundColor: Colors.white),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                double costo = double.tryParse(costoController.text) ?? 0;
                double ganancia = double.tryParse(gananciaController.text) ?? 0;
                double pPublico = costo * (1 + (ganancia/100));
                int stock = int.tryParse(cantidadController.text) ?? 0;

                final pEditado = Producto(
                    id: p.id,
                    codigo: codigoController.text.trim(),
                    sku: skuController.text.trim(),
                    factura: facturaController.text.trim(),
                    marca: marcaController.text.trim(),
                    descripcion: descController.text.trim(),
                    costo: costo,
                    precio: double.parse(pPublico.toStringAsFixed(2)),
                    precioRappi: double.parse((pPublico * 1.35).toStringAsFixed(2)),
                    stock: stock,
                    borrado: false
                );

                await DBHelper.instance.updateProducto(pEditado.aMapa());
                _cargarProductos(); // Refrescar lista completa
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cambios guardados")));
              }
            },
            child: const Text("Guardar Cambios"),
          )
        ],
      ),
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
              setState(() => _cargando = true); // Solo ponemos cargando al buscar
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
                                onPressed: () => _editarProducto(p),
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