import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'databases/recent_db.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'widgets/product_form_dialog.dart'; // <--- ÚNICO CAMBIO: Importar el formulario

class NuevoIngreso extends StatefulWidget {
  const NuevoIngreso({Key? key}) : super(key: key);

  @override
  State<NuevoIngreso> createState() => _NuevoIngresoState();
}

class _NuevoIngresoState extends State<NuevoIngreso> {
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();
  List<Producto> _agregadosRecientemente = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarMemoriaReciente();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_scannerFocus);
    });
  }

  // --- CARGA DE DATOS (Recientes) ---
  Future<void> _cargarMemoriaReciente() async {
    final codigos = await RecentDB.instance.obtenerCodigosRecientes();
    List<Producto> recuperados = [];

    for (String codigo in codigos) {
      final data = await DBHelper.instance.getProductoPorCodigo(codigo);
      if (data != null) {
        recuperados.add(Producto.desdeMapa(data));
      }
    }

    if (mounted) {
      setState(() {
        _agregadosRecientemente = recuperados;
        _cargando = false;
      });
    }
  }

  Future<void> _registrarEnMemoria(String codigo) async {
    await RecentDB.instance.agregarReciente(codigo);
  }

  // --- ESCÁNER ---
  Future<void> _procesarCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    codigo = codigo.trim();

    final data = await DBHelper.instance.getProductoPorCodigo(codigo);

    if (data != null) {
      // YA EXISTE -> SUMAR STOCK
      await DBHelper.instance.updateStock(codigo, 1);
      await _registrarEnMemoria(codigo);

      final pBD = Producto.desdeMapa(data);
      pBD.stock += 1;
      _actualizarListaVisual(pBD);
      _notificar("Stock +1: ${pBD.descripcion}");
    } else {
      // NO EXISTE -> VINCULAR O CREAR
      _mostrarDialogoVinculacion(codigo);
    }

    _scannerController.clear();
    _scannerFocus.requestFocus();
  }

  void _actualizarListaVisual(Producto p) {
    setState(() {
      _agregadosRecientemente.removeWhere((e) => e.codigo == p.codigo);
      _agregadosRecientemente.insert(0, p);
    });
  }

  Future<void> _modificarStock(Producto p, int cantidad) async {
    await DBHelper.instance.updateStock(p.codigo, cantidad);
    final data = await DBHelper.instance.getProductoPorCodigo(p.codigo);
    if (data != null) {
      final actualizado = Producto.desdeMapa(data);
      _actualizarListaVisual(actualizado);
      await _registrarEnMemoria(p.codigo);
    }
  }

  Future<void> _eliminarProducto(Producto p) async {
    bool? confirma = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Eliminar Producto del Sistema?"),
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

  // --- AQUÍ ESTÁ EL CAMBIO: Usamos el Widget Unificado ---
  void _abrirFormularioProducto({required String codigoInicial, Producto? productoExistente}) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ProductFormDialog(
          codigoInicial: codigoInicial,
          productoExistente: productoExistente,
          onGuardado: (p) {
            _actualizarListaVisual(p);
            _notificar(productoExistente != null ? "Producto actualizado" : "Producto creado");
            _scannerFocus.requestFocus();
          },
        )
    );
  }

  Future<void> _mostrarDialogoVinculacion(String codigo) async {
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DialogoVincular(
          codigoEscaneado: codigo,
          onVincular: (p) async {
            await DBHelper.instance.vincularCodigo(p.id!, codigo);
            await DBHelper.instance.updateStock(codigo, 1);
            await _registrarEnMemoria(codigo);
            p.codigo = codigo; p.stock += 1;
            _actualizarListaVisual(p);
            Navigator.pop(context);
            _notificar("Vinculado correctamente");
          },
          onCrearNuevo: () {
            Navigator.pop(context);
            // Llamamos al formulario unificado
            _abrirFormularioProducto(codigoInicial: codigo);
          },
        )
    );
    _scannerFocus.requestFocus();
  }

  void _notificar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 1)));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _agregadosRecientemente.isEmpty
                ? const Center(child: Text("Sin actividad reciente.", style: TextStyle(color: Colors.grey, fontSize: 18)))
                : ListView.builder(
              itemCount: _agregadosRecientemente.length,
              itemBuilder: (context, index) {
                final p = _agregadosRecientemente[index];

                // --- ESTA ES LA TARJETA ORIGINAL QUE TE GUSTABA ---
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
                                  // Llamamos al nuevo dialogo unificado
                                  onPressed: () => _abrirFormularioProducto(codigoInicial: p.codigo, productoExistente: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: "Eliminar",
                                  onPressed: () => _eliminarProducto(p),
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
      ),
    );
  }
}

// --- DIALOGO DE VINCULACIÓN (Se mantiene igual que el original) ---
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