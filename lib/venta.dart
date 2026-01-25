import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'databases/history_db.dart';

// Clase auxiliar para agrupar productos en la venta
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
  // Usamos List<ItemVenta> en lugar de List<Producto>
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
    for (var item in _carrito) {
      temp += item.subtotal;
    }
    setState(() => _total = temp);
  }

  Future<void> _escanearCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    // Buscar primero en BD
    final data = await DBHelper.instance.getProductoPorCodigo(codigo.trim());

    if (data != null) {
      final p = Producto.desdeMapa(data);
      _agregarItemLogica(p);
    } else {
      _alerta("No encontrado", "Producto no encontrado con código: $codigo");
    }

    _codigoController.clear();
    _focusNode.requestFocus();
  }

  // Lógica centralizada para agregar o sumar cantidad
  void _agregarItemLogica(Producto p) {
    if (p.stock <= 0) {
      _alerta("Sin Stock", "El producto ${p.descripcion} no tiene existencias.");
      return;
    }

    // Verificar si ya está en el carrito para agrupar
    int index = _carrito.indexWhere((item) => item.producto.id == p.id);

    setState(() {
      if (index != -1) {
        // Ya existe: validamos stock y sumamos 1
        if (_carrito[index].cantidad < p.stock) {
          _carrito[index].cantidad++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No hay más stock de ${p.descripcion}"), duration: const Duration(milliseconds: 800))
          );
        }
      } else {
        // Nuevo en carrito
        _carrito.insert(0, ItemVenta(producto: p, cantidad: 1)); // Insertar al inicio para verlo rápido
      }
      _calcularTotal();
    });
  }

  // Modificar cantidad con botones +/-
  void _cambiarCantidad(ItemVenta item, int delta) {
    setState(() {
      int nuevaCant = item.cantidad + delta;
      if (nuevaCant > item.producto.stock) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock insuficiente")));
        return;
      }
      if (nuevaCant < 1) {
        // Si baja de 1, preguntar si borrar
        _eliminarItem(item);
        return;
      }
      item.cantidad = nuevaCant;
      _calcularTotal();
    });
  }

  void _eliminarItem(ItemVenta item) {
    setState(() {
      _carrito.remove(item);
      _calcularTotal();
    });
  }

  // --- NUEVO: BÚSQUEDA MANUAL ---
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

  // --- NUEVO: EDITAR PRODUCTO DESDE VENTA ---
  Future<void> _editarProductoEnVenta(ItemVenta item) async {
    // Reutilizamos la lógica del formulario de edición.
    // Lo ideal es tener este diálogo en un archivo aparte, pero lo incluyo aquí para que funcione
    // copiando solo este archivo.
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DialogoEditarProducto(
          producto: item.producto,
          onGuardado: (Producto prodActualizado) {
            setState(() {
              // Actualizamos el producto en el carrito
              item.producto = prodActualizado;
              _calcularTotal();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto actualizado")));
          },
        )
    );
  }

  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) return;
    if (_recibido < _total) {
      _alerta("Pago insuficiente", "Falta dinero.");
      return;
    }

    String itemsResumen = _carrito.map((e) => "${e.cantidad}x ${e.producto.descripcion}").join("|");    final fechaObj = DateTime.now();
    final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaObj);

    // --- CALCULAR COSTO TOTAL (Sumando costo unitario * cantidad de cada item) ---
    double costoTotalVenta = 0.0;
    for (var item in _carrito) {
      costoTotalVenta += (item.producto.costo * item.cantidad);
    }
    // ---------------------------------------------------------------------------

    int ventaId = await DBHelper.instance.insertVenta({
      'fecha': fecha,
      'total': _total,
      'recibido': _recibido,
      'cambio': (_recibido - _total),
      'cliente': 'Mostrador',
      'items': itemsResumen
    });

    for (var item in _carrito) {
      await DBHelper.instance.updateStock(item.producto.codigo, -item.cantidad);
    }

    // --- GUARDAR EN HISTORIAL CON COSTO ---
    await HistoryDB.instance.registrarVenta(
      folio: ventaId,
      fecha: fecha,
      total: _total,
      costoTotal: costoTotalVenta, // <--- Pasamos el costo aquí
      items: itemsResumen,
    );

    // ... (El resto de tu código de impresión e interfaz sigue igual) ...
    try {
      await ImpresionTicket.imprimirTicket(
        items: _carrito,
        total: _total,
        recibido: _recibido,
        cambio: (_recibido - _total),
        folioVenta: ventaId,
      );
    } catch (e) { print(e); }

    setState(() {
      _carrito.clear();
      _total = 0.0;
      _recibido = 0.0;
      _recibidoController.clear();
    });
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
          // FILA SUPERIOR: ESCÁNER + BOTÓN BÚSQUEDA
          Row(
            children: [
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
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    backgroundColor: Colores.azulCielo,
                    foregroundColor: Colors.white
                ),
                onPressed: _abrirBusquedaManual,
                icon: const Icon(Icons.search),
                label: const Text("Buscar Manual"),
              )
            ],
          ),
          const SizedBox(height: 20),

          // AREA PRINCIPAL
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LISTA DE PRODUCTOS EN CARRITO
                Expanded(
                  flex: 3, // Más espacio para la lista
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
                              // 1. Descripción y Precio unitario
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

                              // 2. Controles de Cantidad (+ / -)
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

                              // 3. Subtotal
                              SizedBox(
                                width: 80,
                                child: Text("\$${item.subtotal.toStringAsFixed(2)}",
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colores.azulPrincipal)),
                              ),

                              // 4. Botones Acción (Editar / Eliminar)
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

                // PANEL LATERAL DE TOTALES
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
}

// --- COMPONENTES AUXILIARES ---

// Dialogo de Búsqueda
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
    final res = await db.query(
      'productos',
      where: 'descripcion LIKE ? OR factura LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    setState(() {
      _resultados = res.map((e) => Producto.desdeMapa(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Buscar producto manual"),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "Escribe nombre (ej: Tornillo)...", border: OutlineInputBorder()),
              onChanged: _buscar,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                separatorBuilder: (ctx, i) => const Divider(),
                itemCount: _resultados.length,
                itemBuilder: (ctx, i) {
                  final p = _resultados[i];
                  return ListTile(
                    title: Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("\$${p.precio} | Stock: ${p.stock} | Código: ${p.codigo}"),
                    trailing: ElevatedButton(
                      child: const Text("AGREGAR"),
                      onPressed: () => widget.onSeleccionado(p),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar"))],
    );
  }
}

// Dialogo Editar Producto (Copia simplificada y adaptada para ser llamada desde Venta)
class DialogoEditarProducto extends StatefulWidget {
  final Producto producto;
  final Function(Producto) onGuardado;

  const DialogoEditarProducto({Key? key, required this.producto, required this.onGuardado}) : super(key: key);

  @override
  State<DialogoEditarProducto> createState() => _DialogoEditarProductoState();
}

class _DialogoEditarProductoState extends State<DialogoEditarProducto> {
  late TextEditingController codigoCtrl;
  late TextEditingController descCtrl;
  late TextEditingController costoCtrl;
  late TextEditingController precioCtrl; // EDITABLE
  late TextEditingController gananciaCtrl;
  late TextEditingController stockCtrl;
  final FocusNode precioFocus = FocusNode();
  final FocusNode costoFocus = FocusNode();
  final FocusNode gananciaFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    codigoCtrl = TextEditingController(text: p.codigo);
    descCtrl = TextEditingController(text: p.descripcion);
    costoCtrl = TextEditingController(text: p.costo.toString());
    precioCtrl = TextEditingController(text: p.precio.toString());
    stockCtrl = TextEditingController(text: p.stock.toString());

    double g = 0;
    if(p.costo > 0) g = ((p.precio / p.costo) - 1) * 100;
    gananciaCtrl = TextEditingController(text: g.toStringAsFixed(1));

    costoCtrl.addListener(_calc);
    precioCtrl.addListener(_calc);
    gananciaCtrl.addListener(_calc);
  }

  void _calc() {
    double c = double.tryParse(costoCtrl.text) ?? 0;
    if (precioFocus.hasFocus) {
      double p = double.tryParse(precioCtrl.text) ?? 0;
      if (c > 0) {
        double nuevaG = ((p / c) - 1) * 100;
        gananciaCtrl.text = nuevaG.toStringAsFixed(1);
      }
    } else if (costoFocus.hasFocus || gananciaFocus.hasFocus) {
      double g = double.tryParse(gananciaCtrl.text) ?? 0;
      double nuevoP = c * (1 + (g/100));
      precioCtrl.text = nuevoP.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Editar Producto Rápido"),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            children: [
              TextFormField(controller: codigoCtrl, decoration: const InputDecoration(labelText: "Código")),
              const SizedBox(height: 10),
              TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: "Descripción")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: costoCtrl, focusNode: costoFocus, decoration: const InputDecoration(labelText: "Costo \$"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: gananciaCtrl, focusNode: gananciaFocus, decoration: const InputDecoration(labelText: "Margen %"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                      controller: precioCtrl,
                      focusNode: precioFocus,
                      decoration: const InputDecoration(labelText: "PRECIO PÚBLICO", filled: true, fillColor: Color(0xFFE3F2FD))
                  )),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(controller: stockCtrl, decoration: const InputDecoration(labelText: "Stock (Inventario)")),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          child: const Text("GUARDAR CAMBIOS"),
          onPressed: () async {
            // Guardar en BD
            final p = widget.producto;
            p.codigo = codigoCtrl.text;
            p.descripcion = descCtrl.text;
            p.costo = double.tryParse(costoCtrl.text) ?? 0;
            p.precio = double.tryParse(precioCtrl.text) ?? 0;
            p.stock = int.tryParse(stockCtrl.text) ?? 0;

            await DBHelper.instance.updateProducto(p.aMapa());
            widget.onGuardado(p); // Callback
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}