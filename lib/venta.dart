import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';

class Venta extends StatefulWidget {
  const Venta({Key? key}) : super(key: key);

  @override
  State<Venta> createState() => _VentaState();
}

class _VentaState extends State<Venta> {
  final List<Producto> _carrito = [];
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
    for (var p in _carrito) temp += p.precio;
    setState(() => _total = temp);
  }

  Future<void> _escanearCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    final data = await DBHelper.instance.getProductoPorCodigo(codigo.trim());
    _agregarAlCarrito(data, codigo);
    _codigoController.clear();
    _focusNode.requestFocus();
  }

  void _agregarAlCarrito(Map<String, dynamic>? data, String codigoRef) {
    if (data != null) {
      final producto = Producto.desdeMapa(data);
      if (producto.stock > 0) {
        setState(() {
          _carrito.add(producto);
          _calcularTotal();
        });
      } else {
        _alerta("Sin stock", "El producto ${producto.descripcion} no tiene existencias.");
      }
    } else {
      _alerta("No encontrado", "Producto no encontrado con código: $codigoRef");
    }
  }

  // --- NUEVO: BÚSQUEDA MANUAL ---
  Future<void> _abrirBusquedaManual() async {
    await showDialog(
      context: context,
      builder: (context) => DialogoBusquedaVenta(
        onSeleccionado: (producto) {
          // Agregar directo al carrito
          if (producto.stock > 0) {
            setState(() {
              _carrito.add(producto);
              _calcularTotal();
            });
            Navigator.pop(context); // Cerrar dialogo
          } else {
            Navigator.pop(context);
            _alerta("Sin stock", "No hay existencias de ${producto.descripcion}");
          }
        },
      ),
    );
    _focusNode.requestFocus(); // Devolver foco al escáner
  }

  // ... (El resto de _finalizarVenta y _mostrarAlerta es igual al anterior) ...
  Future<void> _finalizarVenta() async {
    // ... (Copia tu lógica de finalizar venta aquí) ...
    // Si necesitas que te la repita, avísame.
    // Solo asegurate de limpiar el carrito y recalcular al final.
    if (_carrito.isEmpty) return;
    String itemsResumen = _carrito.map((e) => "${e.codigo}:${e.precio}").join(",");
    final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await DBHelper.instance.insertVenta({
      'fecha': fecha,
      'total': _total,
      'recibido': _recibido,
      'cambio': (_recibido - _total),
      'cliente': 'Mostrador',
      'items': itemsResumen
    });
    for (var p in _carrito) {
      await DBHelper.instance.updateStock(p.codigo, -1);
    }
    setState(() {
      _carrito.clear();
      _total = 0.0;
      _recibido = 0.0;
      _recibidoController.clear();
    });
    _alerta("Venta", "Venta realizada con éxito");
  }

  void _alerta(String t, String m) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(t), content: Text(m), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text("OK"))]));
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
                label: const Text("Buscar Manual\n(Tornillos, etc)"),
              )
            ],
          ),
          const SizedBox(height: 20),

          // AREA PRINCIPAL (Igual que antes)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: ListView.builder(
                      itemCount: _carrito.length,
                      itemBuilder: (context, index) {
                        final p = _carrito[index];
                        return ListTile(
                          title: Text(p.descripcion),
                          subtitle: Text(p.codigo),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("\$${p.precio.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _carrito.removeAt(index);
                                    _calcularTotal();
                                  });
                                },
                              )
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
                    color: Colors.grey[100],
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text("Resumen de Venta", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Text("Total: \$${_total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _recibidoController,
                            decoration: const InputDecoration(labelText: "Dinero Recibido", prefixText: "\$"),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              setState(() {
                                _recibido = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Text("Cambio: \$${(_recibido - _total).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colores.verde, padding: const EdgeInsets.all(20)),
                            onPressed: _finalizarVenta,
                            icon: const Icon(Icons.check),
                            label: const Text("COBRAR"),
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

// Dialogo para buscar manualmente en Ventas
class DialogoBusquedaVenta extends StatefulWidget {
  final Function(Producto) onSeleccionado;
  const DialogoBusquedaVenta({Key? key, required this.onSeleccionado}) : super(key: key);

  @override
  State<DialogoBusquedaVenta> createState() => _DialogoBusquedaVentaState();
}

class _DialogoBusquedaVentaState extends State<DialogoBusquedaVenta> {
  List<Producto> _resultados = [];

  Future<void> _buscar(String query) async {
    if (query.length < 2) return; // Optimización
    final db = await DBHelper.instance.database;
    final res = await db.query(
      'productos',
      where: 'descripcion LIKE ? OR factura LIKE ?', // Quitamos codigo de aquí porque es manual
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
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "Escribe nombre (ej: Tornillo)..."),
              onChanged: _buscar,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _resultados.length,
                itemBuilder: (ctx, i) {
                  final p = _resultados[i];
                  return ListTile(
                    title: Text(p.descripcion),
                    subtitle: Text("\$${p.precio} | Stock: ${p.stock}"),
                    onTap: () => widget.onSeleccionado(p),
                  );
                },
              ),
            )
          ],
        ),
      ),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text("Cancelar"))],
    );
  }
}