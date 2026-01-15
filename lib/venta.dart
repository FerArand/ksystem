import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'busqueda.dart';
import 'lista_usuario.dart';

enum ModoVenta { mostrador, rappi }

class ItemVenta {
  final Producto producto;
  int cantidad;

  ItemVenta({
    required this.producto,
    this.cantidad = 1,
  });
}

class Venta extends StatefulWidget {
  const Venta({Key? key}) : super(key: key);

  @override
  State<Venta> createState() => _VentaState();
}

class _VentaState extends State<Venta> {
  ModoVenta _modo = ModoVenta.mostrador;

  final List<ItemVenta> _items = [];
  String _textoBusqueda = '';

  final TextEditingController _recibidoController = TextEditingController();

  Timer? _searchDebounce;
  Timer? _recibidoDebounce;

  @override
  void dispose() {
    _recibidoDebounce?.cancel();
    _searchDebounce?.cancel();
    _recibidoController.dispose();
    super.dispose();
  }

  /// Colección de productos del usuario logueado (helper centralizado)
  CollectionReference<Map<String, dynamic>> _coleccionProductosUsuario() {
    return coleccionProductosUsuario();
  }

  double _precioProducto(Producto p) {
    return _modo == ModoVenta.mostrador ? p.precio : p.precioRappi;
  }

  double get _total {
    return _items.fold(
      0.0,
          (suma, item) => suma + _precioProducto(item.producto) * item.cantidad,
    );
  }

  double get _recibido {
    //permite coma o punto como separador decimal
    final texto = _recibidoController.text.replaceAll(',', '.');
    return double.tryParse(texto) ?? 0.0;
  }

  double get _cambio {
    final cambio = _recibido - _total;
    if (cambio < 0) return 0.0;
    return cambio;
  }

  void _cambiarModo(ModoVenta modo) {
    if (_modo == modo) return;
    setState(() {
      _modo = modo;
    });
  }

  void _actualizarBusqueda(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _textoBusqueda = value;
      });
    });
  }

  void _agregarProducto(Producto producto) {
    final idx = _items.indexWhere((i) => i.producto.id == producto.id);
    if (idx == -1) {
      if (producto.stock <= 0) {
        _mostrarSnack('No hay stock disponible de este producto.');
        return;
      }
      setState(() {
        _items.add(ItemVenta(producto: producto, cantidad: 1));
      });
    } else {
      if (_items[idx].cantidad >= producto.stock) {
        _mostrarSnack('No hay stock suficiente para aumentar la cantidad.');
        return;
      }
      setState(() {
        _items[idx].cantidad++;
      });
    }
  }

  void _incrementarCantidad(ItemVenta item) {
    if (item.cantidad >= item.producto.stock) {
      _mostrarSnack('No hay stock suficiente.');
      return;
    }
    setState(() {
      item.cantidad++;
    });
  }

  void _disminuirCantidad(ItemVenta item) {
    if (item.cantidad > 1) {
      setState(() {
        item.cantidad--;
      });
    }
  }

  void _eliminarItem(ItemVenta item) {
    setState(() {
      _items.remove(item);
    });
  }

  void _cancelarVenta() {
    setState(() {
      _items.clear();
      _recibidoController.clear();
      _textoBusqueda = ''; //no funciona completamente
    });
  }

  Future<void> _finalizarVenta() async {
    if (_items.isEmpty) {
      _mostrarSnack('No hay productos en la venta.');
      return;
    }

    if (_total <= 0) {
      _mostrarSnack('El total es 0. Verifica los precios.');
      return;
    }

    if (_recibido < _total) {
      _mostrarSnack('El dinero recibido es menor que el total.');
      return;
    }

    late final CollectionReference<Map<String, dynamic>> productosRef;
    try {
      productosRef = coleccionProductosUsuario();
    } catch (_) {
      _mostrarSnack('No hay usuario autenticado.');
      return;
    }

    try { //intenta vender
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        for (final item in _items) {
          final ref = productosRef.doc(item.producto.id);

          final snap = await transaction.get(ref);
          final data = snap.data() as Map<String, dynamic>?;

          if (data == null) {
            throw Exception(
              'Producto no encontrado: ${item.producto.descripcion}',
            );
          }

          final stockActual = (data['stock'] as num?)?.toInt() ?? 0;
          if (stockActual < item.cantidad) {
            throw Exception(
              'Stock insuficiente para: ${item.producto.descripcion}',
            );
          }

          final nuevoStock = stockActual - item.cantidad;
          transaction.update(ref, {'stock': nuevoStock});
        }
      });

      _mostrarSnack('Venta realizada correctamente.');
      setState(() {
        _items.clear();
        _recibidoController.clear();
      });
    } catch (e) {
      _mostrarSnack('Error al realizar la venta: $e');
    }
  }

  void _mostrarSnack(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de búsqueda
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por factura o descripción',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _actualizarBusqueda,
                ),
                const SizedBox(height: 8),

                // Área de resultados de búsqueda
                SizedBox(
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colores.gris300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _textoBusqueda.isEmpty
                        ? const Center(
                      child: Text(
                        'Escribe para buscar productos...',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                        : StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: _coleccionProductosUsuario()
                          .where('borrado', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar productos:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        final todosProductos = docs
                            .map(
                              (d) => Producto.desdeMapa(
                            d.data(),
                            d.id,
                          ),
                        )
                            .toList();

                        final productosFiltrados =
                        Busqueda.filtrarPorFacturaODescripcion(
                          todosProductos,
                          _textoBusqueda,
                        );

                        if (productosFiltrados.isEmpty) {
                          return const Center(
                            child: Text(
                              'No se encontraron productos.',
                              style: TextStyle(fontSize: 12),
                            ),
                          );
                        }

                        return Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            itemCount: productosFiltrados.length,
                            itemBuilder: (context, index) {
                              final p = productosFiltrados[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  p.descripcion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Factura: ${p.factura} • Stock: ${p.stock}',
                                  style:
                                  const TextStyle(fontSize: 11),
                                ),
                                trailing: Text(
                                  '\$${_precioProducto(p).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => _agregarProducto(p),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(),

                //lista de productos agregados a la venta
                const Text(
                  'Productos en la venta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colores.gris300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _items.isEmpty
                        ? const Center(
                      child: Text(
                        'No hay productos en la venta.',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                        : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final precioUnitario =
                          _precioProducto(item.producto);
                          final subtotal =
                              precioUnitario * item.cantidad;

                          return ListTile(
                            dense: true,
                            leading: IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colores.rojo,
                              onPressed: () =>
                                  _eliminarItem(item),
                            ),
                            title: Text(
                              item.producto.descripcion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Factura: ${item.producto.factura}',
                              style:
                              const TextStyle(fontSize: 11),
                            ),
                            trailing: SizedBox(
                              width: 180,
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () =>
                                        _disminuirCantidad(item),
                                  ),
                                  Text(
                                    item.cantidad.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () =>
                                        _incrementarCantidad(item),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                //botones: En mostrador o Rappi
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _cambiarModo(ModoVenta.mostrador),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: _modo == ModoVenta.mostrador
                                ? Colores.azulPrincipal
                                : Colores.blanco,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colores.azulPrincipal,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'En mostrador',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _modo == ModoVenta.mostrador
                                    ? Colores.blanco
                                    : Colores.azulPrincipal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _cambiarModo(ModoVenta.rappi),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: _modo == ModoVenta.rappi
                                ? Colores.rosa
                                : Colores.blanco,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colores.rosa,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Rappi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _modo == ModoVenta.rappi
                                    ? Colores.rojo900
                                    : Colores.rojo400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                //dinero
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colores.gris100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colores.gris300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Resumen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _recibidoController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Dinero recibido',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          _recibidoDebounce?.cancel();
                          _recibidoDebounce =
                              Timer(const Duration(milliseconds: 180), () {
                                if (!mounted) return;
                                setState(() {});
                              });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cambio:',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            '\$${_cambio.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Botones Cancelar y Finalizar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colores.rojo,
                      ),
                      onPressed: _cancelarVenta,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colores.verde,
                      ),
                      onPressed: _finalizarVenta,
                      child: const Text('Finalizar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}