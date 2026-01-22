import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';

class NuevoIngreso extends StatefulWidget {
  const NuevoIngreso({Key? key}) : super(key: key);

  @override
  State<NuevoIngreso> createState() => _NuevoIngresoState();
}

class _NuevoIngresoState extends State<NuevoIngreso> {
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();

  // Lista inteligente: Solo un item por código, actualizamos su stock visualmente
  List<Producto> _agregadosRecientemente = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_scannerFocus);
    });
  }

  // --- LÓGICA DE ESCANEO ---
  Future<void> _procesarCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    codigo = codigo.trim();

    final data = await DBHelper.instance.getProductoPorCodigo(codigo);

    if (data != null) {
      // YA EXISTE EN BD -> SUMAR STOCK
      await DBHelper.instance.updateStock(codigo, 1);

      // Actualizar lista visual (Sin duplicar filas)
      final pBD = Producto.desdeMapa(data);
      pBD.stock += 1; // El dato de la BD venía antes de sumar, así que sumamos 1 visualmente

      _actualizarOInsertarEnLista(pBD);
      _notificar("Stock +1: ${pBD.descripcion}");
    } else {
      // NO EXISTE -> VINCULAR O CREAR
      _mostrarDialogoVinculacion(codigo);
    }

    _scannerController.clear();
    _scannerFocus.requestFocus();
  }

  // Lógica para no duplicar filas visuales
  void _actualizarOInsertarEnLista(Producto p) {
    setState(() {
      int index = _agregadosRecientemente.indexWhere((e) => e.codigo == p.codigo);
      if (index != -1) {
        // Si ya está en la lista, lo movemos al principio y actualizamos sus datos
        _agregadosRecientemente.removeAt(index);
        _agregadosRecientemente.insert(0, p);
      } else {
        // Si no está, lo ponemos al principio
        _agregadosRecientemente.insert(0, p);
      }
    });
  }

  // --- EDICIÓN Y ELIMINACIÓN RÁPIDA ---

  Future<void> _modificarStock(Producto p, int cantidad) async {
    await DBHelper.instance.updateStock(p.codigo, cantidad);
    // Recargar dato fresco de BD para asegurar sincronía
    final data = await DBHelper.instance.getProductoPorCodigo(p.codigo);
    if (data != null) {
      _actualizarOInsertarEnLista(Producto.desdeMapa(data));
    }
  }

  Future<void> _eliminarProducto(Producto p) async {
    bool? confirma = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Eliminar Producto?"),
          content: Text("Se borrará definitivamente: ${p.descripcion}"),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("Cancelar")),
            TextButton(onPressed: ()=>Navigator.pop(ctx, true), child: const Text("BORRAR", style: TextStyle(color: Colors.red))),
          ],
        )
    );

    if (confirma == true && p.id != null) {
      await DBHelper.instance.deleteProducto(p.id!);
      setState(() {
        _agregadosRecientemente.removeWhere((e) => e.id == p.id);
      });
      _notificar("Producto eliminado.");
    }
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // BARRA SUPERIOR
          TextField(
            controller: _scannerController,
            focusNode: _scannerFocus,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: "AÑADIR: Escanea para sumar, crear o editar",
                prefixIcon: Icon(Icons.qr_code_2, size: 30),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFE8F5E9)
            ),
            onSubmitted: _procesarCodigo,
          ),
          const SizedBox(height: 10),

          // LISTA DE PRODUCTOS
          Expanded(
            child: _agregadosRecientemente.isEmpty
                ? const Center(child: Text("Escanea productos para gestionar...", style: TextStyle(color: Colors.grey, fontSize: 18)))
                : ListView.builder(
              itemCount: _agregadosRecientemente.length,
              itemBuilder: (context, index) {
                final p = _agregadosRecientemente[index];
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
                        // FILA 2: CONTROLES
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // BOTONES EDICIÓN
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  tooltip: "Editar Datos",
                                  onPressed: () => _mostrarDialogoProducto(codigoInicial: p.codigo, productoExistente: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: "Eliminar",
                                  onPressed: () => _eliminarProducto(p),
                                ),
                              ],
                            ),
                            // CONTROL STOCK
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.shade300)
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: Colors.red),
                                    onPressed: () => _modificarStock(p, -1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text("${p.stock}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Colors.green),
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
      ),
    );
  }

  // --- DIÁLOGOS DE FLUJO ---

  Future<void> _mostrarDialogoVinculacion(String codigo) async {
    // (Mismo código de DialogoVinculacion que ya tienes, llamando a _mostrarDialogoProducto al final)
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DialogoVincular(
          codigoEscaneado: codigo,
          onVincular: (p) async {
            await DBHelper.instance.vincularCodigo(p.id!, codigo);
            await DBHelper.instance.updateStock(codigo, 1);
            p.codigo = codigo; p.stock += 1;
            _actualizarOInsertarEnLista(p);
            Navigator.pop(context);
            _notificar("Vinculado correctamente");
          },
          onCrearNuevo: () {
            Navigator.pop(context);
            _mostrarDialogoProducto(codigoInicial: codigo); // CREAR NUEVO
          },
        )
    );
    _scannerFocus.requestFocus();
  }

  // --- FORMULARIO MAESTRO (CREAR Y EDITAR) ---
  Future<void> _mostrarDialogoProducto({required String codigoInicial, Producto? productoExistente}) async {
    final bool esEdicion = productoExistente != null;

    final codigoController = TextEditingController(text: esEdicion ? productoExistente.codigo : codigoInicial);
    final descController = TextEditingController(text: esEdicion ? productoExistente.descripcion : "");
    final marcaController = TextEditingController(text: esEdicion ? productoExistente.marca : "");
    final costoController = TextEditingController(text: esEdicion ? productoExistente.costo.toString() : "");
    final skuController = TextEditingController(text: esEdicion ? productoExistente.sku : "");
    final facturaController = TextEditingController(text: esEdicion ? productoExistente.factura : "");
    final cantidadController = TextEditingController(text: esEdicion ? productoExistente.stock.toString() : "1");

    // Cálculo inverso para ganancia si es edición
    double gananciaInicial = 46.0; // Default
    if (esEdicion && productoExistente.costo > 0) {
      gananciaInicial = ((productoExistente.precio / productoExistente.costo) - 1) * 100;
    }
    final gananciaController = TextEditingController(text: gananciaInicial.toStringAsFixed(1));

    final ValueNotifier<double> precioCalculado = ValueNotifier(esEdicion ? productoExistente.precio : 0.0);
    final _formKey = GlobalKey<FormState>();

    void _calcular() {
      double c = double.tryParse(costoController.text) ?? 0;
      double g = double.tryParse(gananciaController.text) ?? 0;
      precioCalculado.value = c * (1 + (g / 100));
    }
    costoController.addListener(_calcular);
    gananciaController.addListener(_calcular);

    // Decoración helper
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
        title: Text(esEdicion ? "Editar Producto" : "Nuevo Producto"),
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
                        child: Text("Precio Público: \$${v.toStringAsFixed(2)}", textAlign: TextAlign.center, style: TextStyle(color: Colores.azulCielo, fontWeight: FontWeight.bold))
                    )),
                  ),
                  Row(children: [
                    Expanded(child: TextFormField(controller: skuController, decoration: decoracion("SKU (Opcional)"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: facturaController, decoration: decoracion("Factura (Opcional)"))),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(controller: cantidadController, decoration: decoracion("Inventario"), keyboardType: TextInputType.number),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colores.verde, foregroundColor: Colors.white),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                double costo = double.tryParse(costoController.text) ?? 0;
                double ganancia = double.tryParse(gananciaController.text) ?? 0;
                double pPublico = costo * (1 + (ganancia/100));
                int stock = int.tryParse(cantidadController.text) ?? 0;

                final prodEditado = Producto(
                    id: esEdicion ? productoExistente.id : null, // MANTENER ID SI ES EDICIÓN
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

                if (esEdicion) {
                  await DBHelper.instance.updateProducto(prodEditado.aMapa());
                  _notificar("Producto actualizado");
                } else {
                  await DBHelper.instance.insertProducto(prodEditado.aMapa());
                  _notificar("Producto creado");
                }

                // Recargar ID de BD si es nuevo para que los botones funcionen
                if(!esEdicion) {
                  final d = await DBHelper.instance.getProductoPorCodigo(prodEditado.codigo);
                  if(d!=null) prodEditado.id = d['id'];
                }

                _actualizarOInsertarEnLista(prodEditado);
                Navigator.pop(ctx);
                _scannerFocus.requestFocus();
              }
            },
            child: Text(esEdicion ? "ACTUALIZAR" : "GUARDAR"),
          )
        ],
      ),
    );
  }

  void _notificar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 1)));
}

// (Aquí abajo iría la clase DialogoVincular que ya tienes, no cambia)
class DialogoVincular extends StatefulWidget {
  final String codigoEscaneado;
  final Function(Producto) onVincular;
  final VoidCallback onCrearNuevo;

  const DialogoVincular({Key? key, required this.codigoEscaneado, required this.onVincular, required this.onCrearNuevo}) : super(key: key);

  @override
  State<DialogoVincular> createState() => _DialogoVincularState();
}

class _DialogoVincularState extends State<DialogoVincular> {
  List<Producto> _resultados = [];
  bool _buscando = false;
  final TextEditingController _searchCtrl = TextEditingController();

  Future<void> _buscar(String query) async {
    if (query.isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    final db = await DBHelper.instance.database;
    final res = await db.query(
        'productos',
        where: 'descripcion LIKE ? OR factura LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 20
    );
    setState(() {
      _resultados = res.map((e) => Producto.desdeMapa(e)).toList();
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("¿Qué producto es?"),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.amber[100],
              child: Row(children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text("El código '${widget.codigoEscaneado}' no existe. Busca abajo para vincularlo o crea uno nuevo."))
              ]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: "Buscar por Nombre o Factura...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: _buscar,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buscando
                  ? const Center(child: CircularProgressIndicator())
                  : _resultados.isEmpty
                  ? const Center(child: Text("Sin resultados. Si no aparece, es nuevo."))
                  : ListView.builder(
                itemCount: _resultados.length,
                itemBuilder: (ctx, i) {
                  final p = _resultados[i];
                  return ListTile(
                    title: Text(p.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text("Factura: ${p.factura} | Stock: ${p.stock}"),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colores.azulCielo),
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text("ES ESTE"),
                      onPressed: () => widget.onVincular(p),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCrearNuevo, child: const Text("No está en la lista: ES NUEVO")),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
      ],
    );
  }
}