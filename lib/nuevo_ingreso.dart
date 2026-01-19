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
  List<Producto> _agregadosRecientemente = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_scannerFocus);
    });
  }

  Future<void> _procesarCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    codigo = codigo.trim();

    // 1. Buscamos si el código EXACTO ya existe
    final data = await DBHelper.instance.getProductoPorCodigo(codigo);

    if (data != null) {
      // YA EXISTE -> Sumar Stock
      await DBHelper.instance.updateStock(codigo, 1);
      final p = Producto.desdeMapa(data);
      p.stock += 1; // Visual
      _agregarAListaReciente(p);
      _notificar("Stock +1 para ${p.descripcion}");
    } else {
      // NO EXISTE -> ABRIR VINCULADOR
      _mostrarDialogoVinculacion(codigo);
    }

    _scannerController.clear();
    _scannerFocus.requestFocus();
  }

  void _agregarAListaReciente(Producto p) {
    setState(() {
      _agregadosRecientemente.removeWhere((element) => element.id == p.id);
      _agregadosRecientemente.insert(0, p);
    });
  }

  // --- VENTANA DE VINCULACIÓN ---
  Future<void> _mostrarDialogoVinculacion(String codigoEscaneado) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Obliga a elegir una opción
      builder: (context) {
        return DialogoVincular(
          codigoEscaneado: codigoEscaneado,
          onVincular: (productoExistente) async {
            // Lógica "ES ESTE"
            await DBHelper.instance.vincularCodigo(productoExistente.id!, codigoEscaneado);
            // También sumamos 1 al stock porque se acaba de escanear
            await DBHelper.instance.updateStock(codigoEscaneado, 1);

            productoExistente.codigo = codigoEscaneado;
            productoExistente.stock += 1;

            _agregarAListaReciente(productoExistente);
            Navigator.pop(context);
            _notificar("¡Vinculado exitosamente! Código asignado.");
          },
          onCrearNuevo: () {
            // Lógica "ES NUEVO"
            Navigator.pop(context); // Cierra el vinculador
            _mostrarDialogoNuevoProducto(codigoEscaneado); // Abre el creador
          },
        );
      },
    );
    _scannerFocus.requestFocus();
  }

  // --- VENTANA DE CREACIÓN (CÓDIGO ANTERIOR) ---
  Future<void> _mostrarDialogoNuevoProducto(String codigoEscaneado) async {
    final descController = TextEditingController();
    final costoController = TextEditingController();
    final precioController = TextEditingController();
    final cantidadController = TextEditingController(text: "1");

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Crear Producto Completamente Nuevo"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Text("Código: $codigoEscaneado", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(controller: descController, decoration: const InputDecoration(labelText: "Descripción", border: OutlineInputBorder()), autofocus: true),
              const SizedBox(height: 10),
              TextField(controller: costoController, decoration: const InputDecoration(labelText: "Costo", border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: precioController, decoration: const InputDecoration(labelText: "Precio Público", border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: cantidadController, decoration: const InputDecoration(labelText: "Cantidad Inicial", border: OutlineInputBorder()), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (descController.text.isEmpty) return;
              double costo = double.tryParse(costoController.text) ?? 0;
              double precio = double.tryParse(precioController.text) ?? 0;
              int stock = int.tryParse(cantidadController.text) ?? 1;

              final nuevoProd = Producto(
                  codigo: codigoEscaneado,
                  factura: '',
                  descripcion: descController.text,
                  marca: '',
                  costo: costo,
                  precio: precio,
                  precioRappi: precio * 1.20,
                  stock: stock,
                  borrado: false
              );

              await DBHelper.instance.insertProducto(nuevoProd.aMapa());
              // Necesitamos recargar el ID generado, pero para visualización rápida:
              final data = await DBHelper.instance.getProductoPorCodigo(codigoEscaneado);
              if(data != null) _agregarAListaReciente(Producto.desdeMapa(data));

              Navigator.pop(context);
            },
            child: const Text("Guardar Nuevo"),
          )
        ],
      ),
    );
  }

  void _notificar(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj), duration: const Duration(milliseconds: 800)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _scannerController,
            focusNode: _scannerFocus,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: "ESCANEAR AQUÍ: Suma stock, vincula o crea nuevo",
                prefixIcon: Icon(Icons.qr_code_2, size: 30),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFE8F5E9)
            ),
            onSubmitted: _procesarCodigo,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _agregadosRecientemente.isEmpty
                ? const Center(child: Text("Escanea un producto para comenzar...", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: _agregadosRecientemente.length,
              itemBuilder: (context, index) {
                final p = _agregadosRecientemente[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colores.verde, child: Text("${p.stock}", style: const TextStyle(color: Colors.white))),
                    title: Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Código: ${p.codigo}"),
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

// --- WIDGET AUXILIAR: DIÁLOGO DE BÚSQUEDA ---
class DialogoVincular extends StatefulWidget {
  final String codigoEscaneado;
  final Function(Producto) onVincular;
  final VoidCallback onCrearNuevo;

  const DialogoVincular({
    Key? key,
    required this.codigoEscaneado,
    required this.onVincular,
    required this.onCrearNuevo
  }) : super(key: key);

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
    // Buscamos productos que NO tengan ese código (y opcionalmente filtramos los que ya tienen código real)
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
        width: 500, // Ancho fijo para escritorio
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.amber[100],
              child: Row(children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text("El código '${widget.codigoEscaneado}' no existe. Busca abajo para vincularlo a un producto existente."))
              ]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Buscar por Nombre o Factura...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
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
                  // Detectar si ya tiene código asignado (no empieza con NO_CODIGO)
                  bool tieneCodigoReal = !p.codigo.startsWith("NO_CODIGO");

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
        TextButton(
          onPressed: widget.onCrearNuevo,
          child: const Text("No está en la lista: ES NUEVO"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
      ],
    );
  }
}