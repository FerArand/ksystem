import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // para fecha
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
  final FocusNode _focusNode = FocusNode(); // Para mantener el foco en el escáner
  double _total = 0.0;
  double _recibido = 0.0;
  final TextEditingController _recibidoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Forzar el foco al campo de código al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _calcularTotal() {
    double temp = 0.0;
    for (var p in _carrito) {
      temp += p.precio;
    }
    setState(() {
      _total = temp;
    });
  }

  // Lógica principal del escáner
  Future<void> _escanearCodigo(String codigo) async {
    if (codigo.isEmpty) return;

    // Buscar en BD
    final data = await DBHelper.instance.getProductoPorCodigo(codigo.trim());

    if (data != null) {
      final producto = Producto.desdeMapa(data);
      if (producto.stock > 0) {
        setState(() {
          _carrito.add(producto); // Añade al carrito
          _calcularTotal();
        });
        // Disminuir stock en tiempo real (Opcional, o hacerlo al finalizar venta)
        // Por ahora solo visual en carrito.
      } else {
        _mostrarAlerta("Sin stock", "El producto ${producto.descripcion} no tiene existencias.");
      }
    } else {
      _mostrarAlerta("Error", "Producto no encontrado con código: $codigo");
    }

    // Limpiar campo y mantener foco para el siguiente escaneo
    _codigoController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) return;

    // Guardar venta en Historial
    final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Generar string de items para guardar simple
    String itemsResumen = _carrito.map((e) => "${e.codigo}:${e.precio}").join(",");

    await DBHelper.instance.insertVenta({
      'fecha': fecha,
      'total': _total,
      'recibido': _recibido,
      'cambio': (_recibido - _total),
      'cliente': 'Mostrador', // O pedir nombre
      'items': itemsResumen
    });

    // Descontar stock definitivamente de la BD
    for (var p in _carrito) {
      await DBHelper.instance.updateStock(p.codigo, -1);
    }

    setState(() {
      _carrito.clear();
      _total = 0.0;
      _recibido = 0.0;
      _recibidoController.clear();
    });

    _mostrarAlerta("Éxito", "Venta registrada correctamente.");
    _focusNode.requestFocus(); // Regresar foco al escáner
  }

  void _mostrarAlerta(String titulo, String mensaje) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(titulo), content: Text(mensaje),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // CAMPO DE ESCANEO
          TextField(
            controller: _codigoController,
            focusNode: _focusNode,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Escanear código de barras aquí (o escribir manual)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code_scanner),
            ),
            onSubmitted: (value) => _escanearCodigo(value),
          ),
          const SizedBox(height: 20),

          // AREA PRINCIPAL: LISTA Y TOTALES
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LISTADO DE PRODUCTOS (Izquierda)
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
                // TOTALES (Derecha)
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
                            label: const Text("COBRAR / FINALIZAR"),
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