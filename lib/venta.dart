import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'databases/history_db.dart';
import 'databases/debt_db.dart';
import 'widgets/product_form_dialog.dart';

class ItemVenta {
  Producto producto;
  int cantidad;
  ItemVenta({required this.producto, this.cantidad = 1});
  double get subtotal => producto.precio * cantidad;
}

class Venta extends StatefulWidget {
  const Venta({Key? key}) : super(key: key);
  @override
  State<Venta> createState() => _VentaState();
}

class _VentaState extends State<Venta> {
  final List<ItemVenta> _carrito = [];
  final TextEditingController _codigoController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  double _total = 0.0;
  double _recibido = 0.0;
  final TextEditingController _recibidoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _calcularTotal() {
    double temp = 0.0;
    for (var item in _carrito) { temp += item.subtotal; }
    setState(() => _total = temp);
  }

  Future<void> _escanearCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    final data = await DBHelper.instance.getProductoPorCodigo(codigo.trim());

    if (data != null) {
      final p = Producto.desdeMapa(data);
      _agregarItemLogica(p);
    } else {
      _mostrarDialogoCrearRapido(codigo.trim());
    }
    _codigoController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _mostrarDialogoCrearRapido(String codigo) async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Producto no encontrado"),
          content: Text("El código '$codigo' no existe. ¿Quieres crearlo ahora?"),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
                child: const Text("CREAR PRODUCTO"),
                onPressed: () {
                  Navigator.pop(ctx);
                  showDialog(
                      context: context,
                      builder: (c) => ProductFormDialog(
                          codigoInicial: codigo,
                          onGuardado: (nuevoProducto) {
                            _agregarItemLogica(nuevoProducto);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto creado y agregado.")));
                          }
                      )
                  );
                }
            )
          ],
        )
    );
  }

  // --- LÓGICA DE FIADO (ACTUALIZADA) ---
  Future<void> _crearFiado() async {
    if (_carrito.isEmpty) return;

    // GUARDAMOS INFO COMPLETA: Cantidad, SKU, Precio Venta y Costo Original
    // Formato: "1x Tornillo [SKU:123] [P:15.5] [C:10.0]"
    String itemsResumen = _carrito.map((e) {
      String extra = "";
      if (e.producto.sku.isNotEmpty) extra += " [SKU:${e.producto.sku}]";
      extra += " [P:${e.producto.precio}]";
      extra += " [C:${e.producto.costo}]";

      return "${e.cantidad}x ${e.producto.descripcion}$extra";
    }).join("|");

    TextEditingController nombreDeudorCtrl = TextEditingController();

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("FIADO - Asignar Deuda"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ingresa el nombre del cliente."),
              const SizedBox(height: 10),
              TextField(
                controller: nombreDeudorCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: "Nombre del Cliente", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 10),
              Text("Total: \$${_total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red))
            ],
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  String nombre = nombreDeudorCtrl.text.trim();
                  if (nombre.isEmpty) return;

                  await DebtDB.instance.actualizarDeuda(nombre, itemsResumen, _total);

                  for (var item in _carrito) {
                    await DBHelper.instance.updateStock(item.producto.codigo, -item.cantidad);
                  }

                  Navigator.pop(ctx);
                  _limpiarTodo();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fiado registrado a $nombre")));
                },
                child: const Text("CONFIRMAR FIADO")
            )
          ],
        )
    );
  }

  void _agregarItemLogica(Producto p) {
    if (p.stock <= 0) {
      _alerta("Sin Stock", "El producto ${p.descripcion} no tiene existencias.");
      return;
    }
    int index = _carrito.indexWhere((item) => item.producto.id == p.id);
    setState(() {
      if (index != -1) {
        if (_carrito[index].cantidad < p.stock) {
          _carrito[index].cantidad++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No hay más stock de ${p.descripcion}"), duration: const Duration(milliseconds: 800)));
        }
      } else {
        _carrito.insert(0, ItemVenta(producto: p, cantidad: 1));
      }
      _calcularTotal();
    });
  }

  void _cambiarCantidad(ItemVenta item, int delta) {
    setState(() {
      int nuevaCant = item.cantidad + delta;
      if (nuevaCant > item.producto.stock) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock insuficiente")));
        return;
      }
      if (nuevaCant < 1) {
        _carrito.remove(item);
      } else {
        item.cantidad = nuevaCant;
      }
      _calcularTotal();
    });
  }

  Future<void> _abrirBusquedaManual() async {
    await showDialog(
      context: context,
      builder: (context) => DialogoBusquedaVenta(
        onSeleccionado: (producto) {
          _agregarItemLogica(producto);
          Navigator.pop(context);
        },
      ),
    );
    _focusNode.requestFocus();
  }

  Future<void> _editarProductoEnVenta(ItemVenta item) async {
    showDialog(
        context: context,
        builder: (c) => ProductFormDialog(
            productoExistente: item.producto,
            onGuardado: (p) {
              setState(() { item.producto = p; _calcularTotal(); });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto actualizado")));
            }
        )
    );
  }

  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) return;
    if (_recibido < _total) {
      _alerta("Pago insuficiente", "Falta dinero.");
      return;
    }

    String itemsResumen = _carrito.map((e) => "${e.cantidad}x ${e.producto.descripcion}").join("|");
    final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    double costoTotalVenta = 0.0;
    for (var item in _carrito) { costoTotalVenta += (item.producto.costo * item.cantidad); }

    int ventaId = await DBHelper.instance.insertVenta({
      'fecha': fecha, 'total': _total, 'recibido': _recibido, 'cambio': (_recibido - _total), 'cliente': 'Mostrador', 'items': itemsResumen
    });
    for (var item in _carrito) { await DBHelper.instance.updateStock(item.producto.codigo, -item.cantidad); }
    await HistoryDB.instance.registrarVenta(folio: ventaId, fecha: fecha, total: _total, costoTotal: costoTotalVenta, items: itemsResumen);

    try {
      await ImpresionTicket.imprimirTicket(items: _carrito, total: _total, recibido: _recibido, cambio: (_recibido - _total), folioVenta: ventaId);
    } catch (e) { print(e); }

    _limpiarTodo();
  }

  void _limpiarTodo() {
    setState(() { _carrito.clear(); _total = 0.0; _recibido = 0.0; _recibidoController.clear(); });
    _focusNode.requestFocus();
  }

  void _alerta(String t, String m) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(t), content: Text(m), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    backgroundColor: Colores.azulCielo,
                    foregroundColor: Colors.white
                ),
                onPressed: _abrirBusquedaManual,
                icon: const Icon(Icons.search),
                label: const Text(""),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _codigoController,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: "Escanea código de barras aquí...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      filled: true,
                      fillColor: Colors.white
                  ),
                  onSubmitted: (value) => _escanearCodigo(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), color: Colors.white),
                    child: _carrito.isEmpty
                        ? const Center(child: Text("Carrito vacío", style: TextStyle(color: Colors.grey, fontSize: 20)))
                        : ListView.separated(
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemCount: _carrito.length,
                      itemBuilder: (context, index) {
                        final item = _carrito[index];
                        final p = item.producto;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          color: index % 2 == 0 ? Colors.blue[50]!.withOpacity(0.3) : Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("\$${p.precio.toStringAsFixed(2)} c/u  |  Disp: ${p.stock}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, color: Colors.red),
                                      onPressed: () => _cambiarCantidad(item, -1),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text("${item.cantidad}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.green),
                                      onPressed: () => _cambiarCantidad(item, 1),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              SizedBox(
                                width: 80,
                                child: Text("\$${item.subtotal.toStringAsFixed(2)}",
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colores.azulPrincipal)),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                tooltip: "Editar info del producto",
                                onPressed: () => _editarProductoEnVenta(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarItem(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                Expanded(
                  flex: 1,
                  child: Card(
                    color: Colors.grey[50],
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text("Resumen", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Divider(thickness: 2),
                          const Spacer(),
                          Text("TOTAL A PAGAR", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          Text("\$${_total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 30),
                          TextField(
                            controller: _recibidoController,
                            decoration: const InputDecoration(labelText: "Dinero Recibido", prefixText: "\$", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 20),
                            onChanged: (val) {
                              setState(() {
                                _recibido = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(10),
                            color: (_recibido - _total) >= 0 ? Colors.green[50] : Colors.red[50],
                            child: Column(
                              children: [
                                const Text("Cambio", style: TextStyle(fontSize: 14)),
                                Text("\$${(_recibido - _total).toStringAsFixed(2)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: (_recibido - _total) >= 0 ? Colors.green : Colors.red)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colores.verde),
                              onPressed: _finalizarVenta,
                              icon: const Icon(Icons.check_circle, size: 30),
                              label: const Text("COBRAR", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _crearFiado,
                            icon: const Icon(Icons.note_add, color: Colors.red),
                            label: const Text("FIADO (Deuda)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _eliminarItem(ItemVenta item) {
    setState(() { _carrito.remove(item); _calcularTotal(); });
  }
}

class DialogoBusquedaVenta extends StatefulWidget {
  final Function(Producto) onSeleccionado;
  const DialogoBusquedaVenta({Key? key, required this.onSeleccionado}) : super(key: key);
  @override
  State<DialogoBusquedaVenta> createState() => _DialogoBusquedaVentaState();
}
class _DialogoBusquedaVentaState extends State<DialogoBusquedaVenta> {
  List<Producto> _resultados = [];
  Future<void> _buscar(String query) async {
    if (query.length < 2) return;
    final db = await DBHelper.instance.database;
    final res = await db.query('productos', where: 'descripcion LIKE ? OR factura LIKE ?', whereArgs: ['%$query%', '%$query%']);
    setState(() => _resultados = res.map((e) => Producto.desdeMapa(e)).toList());
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Buscar producto manual"),
      content: SizedBox(width: 600, height: 500, child: Column(children: [
        TextField(autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "Escribe...", border: OutlineInputBorder()), onChanged: _buscar),
        const SizedBox(height: 10),
        Expanded(child: ListView.separated(separatorBuilder: (c, i) => const Divider(), itemCount: _resultados.length, itemBuilder: (c, i) {
          final p = _resultados[i];
          return ListTile(title: Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("\$${p.precio} | Stock: ${p.stock}"), trailing: ElevatedButton(child: const Text("AGREGAR"), onPressed: () => widget.onSeleccionado(p)));
        }))
      ])),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar"))],
    );
  }
}