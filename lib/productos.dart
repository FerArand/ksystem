import 'package:flutter/material.dart'; //cards
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants/colores.dart';
import 'models/producto.dart';
import 'busqueda.dart';
import 'lista_usuario.dart';
import 'auth_helpers.dart';

class Productos extends StatefulWidget {
  const Productos({Key? key}) : super(key: key);

  @override
  State<Productos> createState() => _ProductosState();
}

class _ProductosState extends State<Productos> {
  String _textoBusqueda = '';

  // Colección de productos del usuario actual
  CollectionReference<Map<String, dynamic>> _coleccionProductosUsuario() {
    return coleccionProductosUsuario();
  }

  // Confirmar dinamitar
  Future<void> _confirmarDinamitar(Producto p) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Seguro que quieres dinamitar este objeto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, me confundí'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colores.rojo,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Kboom'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _coleccionProductosUsuario().doc(p.id).delete();
    }
  }

  // Diálogo para registrar nuevo producto
  Future<void> _mostrarDialogoNuevoProducto() async {
    final facturaController = TextEditingController();
    final cantidadController = TextEditingController();
    final marcaController = TextEditingController();
    final descripcionController = TextEditingController();
    final costoController = TextEditingController();
    bool mostrarError = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Registrar nuevo producto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: facturaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      label: RichText(
                        text: const TextSpan(
                          text: 'Número de factura',
                          style: TextStyle(color: Colores.gris),
                          children: [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colores.rojo),
                            ),
                          ],
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      label: Text('¿Cuántas unidades?'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: marcaController,
                    decoration: const InputDecoration(
                      label: Text('Marca'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descripcionController,
                    decoration: InputDecoration(
                      label: RichText(
                        text: const TextSpan(
                          text: 'Descripción',
                          style: TextStyle(color: Colores.gris),
                          children: [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colores.rojo),
                            ),
                          ],
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: costoController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      label: RichText(
                        text: const TextSpan(
                          text: 'Costo con IVA',
                          style: TextStyle(color: Colores.gris),
                          children: [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colores.rojo),
                            ),
                          ],
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (mostrarError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Por favor, completa los campos obligatorios.',
                        style: TextStyle(color: Colores.rojo),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Descartar',
                  style: TextStyle(color: Colores.rojo),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colores.verde,
                ),
                onPressed: () async {
                  final fac = facturaController.text.trim();
                  final desc = descripcionController.text.trim();
                  final costoTexto = costoController.text.trim();

                  if (fac.isEmpty || desc.isEmpty || costoTexto.isEmpty) {
                    setState(() {
                      mostrarError = true;
                    });
                    return;
                  }

                  final costo = double.tryParse(costoTexto);
                  if (costo == null) {
                    setState(() {
                      mostrarError = true;
                    });
                    return;
                  }

                  int cantidad = 0;
                  if (cantidadController.text.trim().isNotEmpty) {
                    cantidad =
                        int.tryParse(cantidadController.text.trim()) ?? 0;
                  }

                  final marca = marcaController.text.trim();
                  final precioPublico =
                  double.parse((costo * 1.47).toStringAsFixed(2));
                  final precioRappi =
                  double.parse((precioPublico * 1.35).toStringAsFixed(2));

                  await _coleccionProductosUsuario().doc(fac).set({
                    'factura': fac,
                    'descripcion': desc,
                    'marca': marca,
                    'costo': costo,
                    'precio': precioPublico,
                    'precioRappi': precioRappi,
                    'stock': cantidad,
                    'borrado': false,
                  });

                  Navigator.of(context).pop();
                },
                child: const Text('Añadir'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _mostrarDialogoEditarProducto(Producto p) async {
    final facturaController = TextEditingController(text: p.factura);
    final cantidadController = TextEditingController(text: p.stock.toString());
    final marcaController = TextEditingController(text: p.marca);
    final descripcionController = TextEditingController(text: p.descripcion);

    final costoController = TextEditingController(text: p.costo.toString());
    bool mostrarError = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: facturaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        label: RichText(
                          text: const TextSpan(
                            text: 'Número de factura',
                            style: TextStyle(color: Colores.gris),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colores.rojo),
                              ),
                            ],
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cantidadController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        label: Text('¿Cuántas unidades?'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: marcaController,
                      decoration: const InputDecoration(
                        label: Text('Marca'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descripcionController,
                      decoration: InputDecoration(
                        label: RichText(
                          text: const TextSpan(
                            text: 'Descripción',
                            style: TextStyle(color: Colores.gris),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colores.rojo),
                              ),
                            ],
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: costoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        label: RichText(
                          text: const TextSpan(
                            text: 'Costo con IVA',
                            style: TextStyle(color: Colores.gris),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colores.rojo),
                              ),
                            ],
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (mostrarError)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Por favor, revisa los campos marcados.',
                          style: TextStyle(color: Colores.rojo),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colores.rojo),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.verde,
                  ),
                  onPressed: () async {
                    final fac = facturaController.text.trim();
                    final desc = descripcionController.text.trim();
                    final costoTexto = costoController.text.trim();

                    if (fac.isEmpty || desc.isEmpty || costoTexto.isEmpty) {
                      setState(() {
                        mostrarError = true;
                      });
                      return;
                    }

                    final costo = double.tryParse(costoTexto);
                    if (costo == null) {
                      setState(() {
                        mostrarError = true;
                      });
                      return;
                    }

                    int cantidad = 0;
                    if (cantidadController.text.trim().isNotEmpty) {
                      cantidad =
                          int.tryParse(cantidadController.text.trim()) ?? 0;
                    }

                    final marca = marcaController.text.trim();
                    final precioPublico =
                    double.parse((costo * 1.47).toStringAsFixed(2));
                    final precioRappi =
                    double.parse((precioPublico * 1.35).toStringAsFixed(2));

                    final nuevaData = {
                      'factura': fac,
                      'descripcion': desc,
                      'marca': marca,
                      'costo': costo,
                      'precio': precioPublico,
                      'precioRappi': precioRappi,
                      'stock': cantidad,
                      'borrado': p.borrado,
                    };

                    // Si la factura no cambió, solo se actualiza este documento
                    if (fac == p.id) {
                      await _coleccionProductosUsuario()
                          .doc(p.id)
                          .update(nuevaData);
                    } else {
                      // Si cambia el número de factura (ID), creamos uno nuevo y borramos el anterior
                      await _coleccionProductosUsuario()
                          .doc(fac)
                          .set(nuevaData);
                      await _coleccionProductosUsuario().doc(p.id).delete();
                    }

                    Navigator.of(context).pop();
                  },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //añadir stock a un producto existente
  Future<void> _mostrarDialogoAgregarStock() async {
    //tomamos los que no están descontinuados
    final snapshot = await _coleccionProductosUsuario()
        .where('borrado', isEqualTo: false)
        .get();

    List<Producto> todosLosProductos = snapshot.docs
        .map(
          (doc) => Producto.desdeMapa(
        doc.data() as Map<String, dynamic>,
        doc.id,
      ),
    )
        .toList();

    final facturaController = TextEditingController();
    final cantidadController = TextEditingController();
    Producto? productoCoincidente;
    bool mostrarError = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void actualizarCoincidencia(String input) {
              final query = input.trim();
              if (query.length >= 2) {
                final encontrado =
                Busqueda.encontrarUnoPorFacturaODescripcion(
                  todosLosProductos,
                  query,
                );
                setState(() {
                  productoCoincidente = encontrado;
                });
              } else {
                setState(() {
                  productoCoincidente = null;
                });
              }
            }

            return AlertDialog(
              title: const Text('Añadir stock'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: facturaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de factura',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      actualizarCoincidencia(value.trim());
                    },
                  ),
                  const SizedBox(height: 8),
                  if (facturaController.text.trim().length >= 2)
                    Text(
                      productoCoincidente != null
                          ? ((productoCoincidente!.marca.isNotEmpty
                          ? '${productoCoincidente!.marca} - '
                          : '') +
                          productoCoincidente!.descripcion)
                          : 'Producto no encontrado',
                      style: TextStyle(
                        color: productoCoincidente != null
                            ? Colores.negro
                            : Colores.rojo,
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad a añadir',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (mostrarError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Por favor, ingresa los datos correctamente.',
                        style: TextStyle(color: Colores.rojo),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Descartar',
                    style: TextStyle(color: Colores.rojo),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.verde,
                  ),
                  onPressed: () async {
                    final fac = facturaController.text.trim();
                    final cantidad =
                        int.tryParse(cantidadController.text.trim()) ?? 0;

                    if (fac.isEmpty ||
                        productoCoincidente == null ||
                        cantidad <= 0) {
                      setState(() {
                        mostrarError = true;
                      });
                      return;
                    }

                    await _coleccionProductosUsuario()
                        .doc(productoCoincidente!.id)
                        .update({
                      'stock': productoCoincidente!.stock + cantidad,
                    });

                    Navigator.of(context).pop();
                  },
                  child: const Text('Hecho'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = usuarioActualONulo();
    if (usuario == null) {
      return const Center(
        child: Text('Inicia sesión para ver tus productos.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Barra de búsqueda y botones de acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por número de factura o descripción',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) { //búsqueda en caliente
                    setState(() {
                      _textoBusqueda = value.trim();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colores.verde,
                ),
                onPressed: _mostrarDialogoNuevoProducto,
                child: const Text('Nuevo producto'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _mostrarDialogoAgregarStock,
                child: const Text('Añadir stock'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Lista de productos
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _coleccionProductosUsuario().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar productos:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Producto> productos = snapshot.data!.docs
                    .map(
                      (doc) => Producto.desdeMapa(
                    doc.data(),
                    doc.id,
                  ),
                )
                    .toList();

                productos.sort((a, b) {
                  if (a.borrado != b.borrado) {
                    if (a.borrado) return 1;
                    return -1;
                  }

                  final importanciaA = (a.stock == 0)
                      ? 2
                      : ((a.stock > 0 && a.stock < 2) ? 1 : 0);
                  final importanciaB = (b.stock == 0)
                      ? 2
                      : ((b.stock > 0 && b.stock < 2) ? 1 : 0);

                  if (importanciaA != importanciaB) {
                    return importanciaB.compareTo(importanciaA);
                  }

                  final facA = int.tryParse(a.factura) ?? -1;
                  final facB = int.tryParse(b.factura) ?? -1;
                  if (facA != -1 && facB != -1) {
                    return facA.compareTo(facB);
                  }
                  return a.factura.compareTo(b.factura);
                });

                // Filtro de búsqueda
                if (_textoBusqueda.isNotEmpty) {
                  productos = Busqueda.filtrarPorFacturaODescripcion(
                    productos,
                    _textoBusqueda,
                  );
                }

                if (productos.isEmpty) {
                  return const Center(child: Text('No hay productos.'));
                }

                return ListView.builder(
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final p = productos[index];
                    final descontinuado = p.borrado;

                    // Color de fondo
                    Color? tileColor;
                    if (descontinuado) {
                      tileColor = Colores.gris100;
                    } else if (p.stock == 0) {
                      tileColor = Colores.rosa;
                    } else if (p.stock > 0 && p.stock < 2) {
                      tileColor = Colores.amarilloClaro;
                    }

                    final stockTexto = descontinuado
                        ? 'Stock: Descontinuado'
                        : 'Stock: ${p.stock}';

                    return Card(
                      color: tileColor,
                      child: ListTile(
                        title: Text('${p.factura} - ${p.descripcion}'),
                        subtitle: Text(
                          'Marca: ${p.marca.isNotEmpty ? p.marca : '-'}'
                              '\n$stockTexto, Público: \$${p.precio.toStringAsFixed(2)}, '
                              'Rappi: \$${p.precioRappi.toStringAsFixed(2)}',
                        ),
                        trailing: descontinuado
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón de reincorporar (naranja)
                            IconButton(
                              icon: const Icon(Icons.undo),
                              color: Colores.naranja,
                              tooltip: 'Reincorporar',
                              onPressed: () async {
                                await _coleccionProductosUsuario()
                                    .doc(p.id)
                                    .update({'borrado': false});
                              },
                            ),
                            IconButton(
                              tooltip: 'Dinamitar',
                              onPressed: () => _confirmarDinamitar(p),
                              icon: const Text(
                                '💥',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // NUEVO: botón de editar
                            IconButton(
                              icon: const Icon(Icons.edit),
                              color: Colors.blue,
                              tooltip: 'Editar producto',
                              onPressed: () {
                                _mostrarDialogoEditarProducto(p);
                              },
                            ),
                            // Botón de marcar como descontinuado
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colores.gris,
                              tooltip: 'Marcar como descontinuado',
                              onPressed: () async {
                                await _coleccionProductosUsuario()
                                    .doc(p.id)
                                    .update({'borrado': true});
                              },
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}