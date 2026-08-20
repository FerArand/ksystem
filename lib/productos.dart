import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/product_card.dart';
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

  Future<void> _modificarStock(Producto p, int cantidad) async {
    await DBHelper.instance.updateStock(p.codigo, cantidad);
    setState(() {
      p.stock += cantidad;
    });
  }

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado.")));
    }
  }

  void _abrirEdicion(Producto p) {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => ProductFormDialog(
          productoExistente: p,
          onGuardado: (prodActualizado) {
            _cargarProductos();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto actualizado")));
          },
        )
    );
  }

  void _abrirAjustePrecios() {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => const AjustePreciosDialog()
    ).then((_) {
      _cargarProductos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(
            color: Colores.consultar,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Row(
            children: [
              Icon(Icons.inventory, color: Colors.white, size: 28),
              SizedBox(width: 15),
              Text("INVENTARIO TOTAL", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Buscar producto por Nombre, SKU o Código...",
                    prefixIcon: const Icon(Icons.search, color: Colores.consultar),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colores.consultar, width: 2)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) {
                    _query = v;
                    setState(() => _cargando = true);
                    _cargarProductos();
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _abrirAjustePrecios,
                icon: const Icon(Icons.price_change, color: Colores.consultar),
                label: const Text("Ajuste de precios", style: TextStyle(color: Colores.consultar, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colores.consultar),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: Colores.consultar))
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

class AjustePreciosDialog extends StatefulWidget {
  const AjustePreciosDialog({Key? key}) : super(key: key);

  @override
  State<AjustePreciosDialog> createState() => _AjustePreciosDialogState();
}

class _AjustePreciosDialogState extends State<AjustePreciosDialog> {
  List<String> _todasLasMarcas = [];
  List<String> _marcasFiltradas = [];
  final Set<String> _marcasSeleccionadas = {};

  final TextEditingController _buscadorMarcasCtrl = TextEditingController();
  final TextEditingController _costoCtrl = TextEditingController();
  final TextEditingController _precioCtrl = TextEditingController();

  final FocusNode _costoFocus = FocusNode();
  final FocusNode _precioFocus = FocusNode();

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarMarcas();

    _costoFocus.addListener(() => _formatearPorcentaje(_costoFocus, _costoCtrl));
    _precioFocus.addListener(() => _formatearPorcentaje(_precioFocus, _precioCtrl));
  }

  @override
  void dispose() {
    _buscadorMarcasCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _costoFocus.dispose();
    _precioFocus.dispose();
    super.dispose();
  }

  void _formatearPorcentaje(FocusNode nodo, TextEditingController controlador) {
    if (!nodo.hasFocus && controlador.text.isNotEmpty) {
      if (!controlador.text.endsWith('%')) {
        controlador.text = '${controlador.text}%';
      }
    }
  }

  Future<void> _cargarMarcas() async {
    final marcas = await DBHelper.instance.getMarcasUnicas();
    setState(() {
      _todasLasMarcas = marcas;
      _marcasFiltradas = marcas;
    });
  }

  void _filtrarMarcas(String query) {
    setState(() {
      if (query.isEmpty) {
        _marcasFiltradas = _todasLasMarcas;
      } else {
        _marcasFiltradas = _todasLasMarcas
            .where((m) => m.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _aplicarAjuste() async {
    if (_marcasSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos una marca')));
      return;
    }

    double costoVal = double.tryParse(_costoCtrl.text.replaceAll('%', '')) ?? 0.0;
    double precioVal = double.tryParse(_precioCtrl.text.replaceAll('%', '')) ?? 0.0;

    if (costoVal == 0.0 && precioVal == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un porcentaje de aumento')));
      return;
    }

    String marcasSeleccionadasStr = _marcasSeleccionadas.join(', ');

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advertencia de Modificación', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de aumentar $costoVal% al costo y $precioVal% al precio público de las marcas $marcasSeleccionadasStr?\n\n'
              'Este cambio modificará los precios de todos los artículos correspondientes y no podrá revertirse automáticamente.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colores.rojo, foregroundColor: Colors.white),
            child: const Text('Sí, aplicar ajustes'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);

    await DBHelper.instance.ajustarPreciosMasivo(_marcasSeleccionadas.toList(), costoVal, precioVal);

    setState(() => _procesando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Precios actualizados correctamente')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colores.consultar.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.price_change, color: Colores.consultar, size: 28),
                    ),
                    const SizedBox(width: 15),
                    const Text("Ajuste Masivo de Precios", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colores.consultar)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(thickness: 1.5),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Selección de Marcas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _buscadorMarcasCtrl,
                          decoration: InputDecoration(
                            hintText: "Buscar marca...",
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colores.consultar),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colores.consultar, width: 1.5)),
                          ),
                          onChanged: _filtrarMarcas,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                                ]
                            ),
                            child: _marcasFiltradas.isEmpty
                                ? const Center(child: Text("No hay marcas", style: TextStyle(color: Colors.grey)))
                                : ListView.builder(
                              itemCount: _marcasFiltradas.length,
                              itemBuilder: (ctx, i) {
                                final marca = _marcasFiltradas[i];
                                return CheckboxListTile(
                                  title: Text(marca, style: const TextStyle(fontSize: 14)),
                                  value: _marcasSeleccionadas.contains(marca),
                                  activeColor: Colores.consultar,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      if (val == true) {
                                        _marcasSeleccionadas.add(marca);
                                      } else {
                                        _marcasSeleccionadas.remove(marca);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: VerticalDivider(width: 1, thickness: 1.5),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colores.consultar.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colores.consultar.withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Configuración de Aumentos", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          const Text("Los ajustes se aplicarán únicamente a los productos que pertenezcan a las marcas seleccionadas en el panel izquierdo.", style: TextStyle(color: Colors.black54, fontSize: 14)),
                          const SizedBox(height: 40),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("¿Cuánto más te cuesta?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _costoCtrl,
                                      focusNode: _costoFocus,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*\%?'))],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: "Ej. 10",
                                        hintStyle: const TextStyle(color: Colors.black26),
                                        helperText: "Aumento al costo de adquisición",
                                        prefixIcon: const Icon(Icons.trending_up, color: Colores.consultar),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colores.consultar, width: 2)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("¿Cuánto más al precio público?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _precioCtrl,
                                      focusNode: _precioFocus,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*\%?'))],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: "Ej. 15",
                                        hintStyle: const TextStyle(color: Colors.black26),
                                        helperText: "Aumento al precio de venta",
                                        prefixIcon: const Icon(Icons.sell_outlined, color: Colores.consultar),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colores.consultar, width: 2)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: _procesando ? null : _aplicarAjuste,
                              icon: _procesando
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.save_rounded, size: 24),
                              label: Text(_procesando ? "PROCESANDO ACTUALIZACIÓN..." : "APLICAR AJUSTES AHORA", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colores.consultar,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}