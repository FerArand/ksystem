import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'Utils/formatters.dart';
import 'databases/history_db.dart';
import 'databases/debt_db.dart';
import 'widgets/product_form_dialog.dart';
import 'factura_form.dart';
import 'Utils/numeric_formatter.dart';
import 'models/item_venta.dart' as modelo;
import 'package:flutter/material.dart';

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

  // --- CALCULADORA DE CORTES ---
  final TextEditingController _calcBaseLen = TextEditingController();
  final TextEditingController _calcBasePrecio = TextEditingController();
  final TextEditingController _calcCorteLen = TextEditingController();
  double _calcResultado = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarCarritoCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  // --- PERSISTENCIA DEL CARRITO ---
  Future<void> _guardarCarritoCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cart_cache.json');

      List<Map<String, dynamic>> items = _carrito.map((e) => {
        'producto': e.producto.aMapa(),
        'cantidad': e.cantidad,
      }).toList();

      await file.writeAsString(jsonEncode(items));
    } catch (e) {
      debugPrint("Error guardando cache del carrito: $e");
    }
  }

  Future<void> _cargarCarritoCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cart_cache.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> json = jsonDecode(content);

        setState(() {
          _carrito.clear();
          for (var item in json) {
            _carrito.add(ItemVenta(
              producto: Producto.desdeMapa(item['producto']),
              cantidad: item['cantidad'],
            ));
          }
          _calcularTotal();
        });
      }
    } catch (e) {
      debugPrint("Error cargando cache del carrito: $e");
    }
  }

  void _calcularTotal() {
    double temp = 0.0;
    for (var item in _carrito) { temp += item.subtotal; }
    setState(() => _total = temp);
  }

  // Lógica de la calculadora "Regla de Tres"
  void _calcularReglaTres() {
    double baseLen = double.tryParse(_calcBaseLen.text) ?? 0;
    double basePrecio = double.tryParse(_calcBasePrecio.text) ?? 0;
    double corteLen = double.tryParse(_calcCorteLen.text) ?? 0;

    setState(() {
      if (baseLen > 0) {
        _calcResultado = (basePrecio * corteLen) / baseLen;
      } else {
        _calcResultado = 0.0;
      }
    });
  }

  Future<void> _escanearCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    final data = await DBHelper.instance.getProductoPorCodigo(codigo.trim());

    if (data != null) {
      final p = Producto.desdeMapa(data);
      _agregarItemLogica(p);
    } else {
      // MODIFICACIÓN: Abre directo el formulario sin preguntar
      _abrirFormularioCreacionDirecta(codigo.trim());
    }
    _codigoController.clear();
    // Recuperamos el foco (aunque el dialogo lo roba momentáneamente, esto ayuda al volver)
    _focusNode.requestFocus();
  }

  // Nueva función para abrir formulario directo
  Future<void> _abrirFormularioCreacionDirecta(String codigo) async {
    await showDialog(
        context: context,
        builder: (c) => ProductFormDialog(
            codigoInicial: codigo,
            onGuardado: (nuevoProducto) {
              _agregarItemLogica(nuevoProducto);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto agregado")));
            }
        )
    );
    _focusNode.requestFocus();
  }

  void _agregarItemLogica(Producto p) {
    // MODIFICACIÓN: Se eliminó la validación de stock <= 0
    int index = _carrito.indexWhere((item) => item.producto.id == p.id);
    setState(() {
      if (index != -1) {
        // MODIFICACIÓN: Se eliminó el límite de stock máximo
        _carrito[index].cantidad++;
      } else {
        _carrito.insert(0, ItemVenta(producto: p, cantidad: 1));
      }
      _calcularTotal();
    });
    _guardarCarritoCache();
  }

  void _cambiarCantidad(ItemVenta item, int delta) {
    setState(() {
      int nuevaCant = item.cantidad + delta;

      // MODIFICACIÓN: Se eliminó la validación de stock insuficiente
      if (nuevaCant < 1) {
        _carrito.remove(item);
      } else {
        item.cantidad = nuevaCant;
      }
      _calcularTotal();
    });
    _guardarCarritoCache();
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
              _guardarCarritoCache();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Se guardó correctamente.")));
            }
        )
    );
  }

  void _eliminarItem(ItemVenta item) {
    setState(() { _carrito.remove(item); _calcularTotal(); });
    _guardarCarritoCache();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _focusNode.dispose();
    _recibidoController.dispose();
    _calcBaseLen.dispose();
    _calcBasePrecio.dispose();
    _calcCorteLen.dispose();
    super.dispose();
  }

  // --- FINALIZAR VENTA MEJORADA ---
  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) return;
    if (_recibido < _total) {
      _alerta("Monto insuficiente", "El dinero recibido es menor al total.");
      return;
    }

    // 1. Preparar datos
    List<modelo.ItemVenta> itemsParaGuardar = _carrito.map((e) => modelo.ItemVenta(
      sku: e.producto.sku,
      descripcion: e.producto.descripcion,
      cantidad: e.cantidad,
      precio: e.producto.precio,
      costo: e.producto.costo,
    )).toList();

    String itemsResumenJson = modelo.ItemVenta.listaAJson(itemsParaGuardar);
    final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    double costoTotalVenta = 0.0;
    for (var item in _carrito) {
      costoTotalVenta += (item.producto.costo * item.cantidad);
    }

    // 2. UN SOLO REGISTRO (Aquí es donde estaba el error)
    // Ya no llamamos a DBHelper.insertVenta, vamos directo a HistoryDB
    int ventaId = await HistoryDB.instance.registrarVenta(
        fecha: fecha,
        total: _total,
        costoTotal: costoTotalVenta,
        items: itemsResumenJson,
        recibido: _recibido,
        cambio: (_recibido - _total),
        cliente: 'Mostrador'
    );

    // 3. Actualizar Stock
    for (var item in _carrito) {
      await DBHelper.instance.updateStock(item.producto.codigo, -item.cantidad);
    }

    // 4. Imprimir y Limpiar
    try {
      await ImpresionTicket.imprimirTicket(
          items: _carrito,
          total: _total,
          recibido: _recibido,
          cambio: (_recibido - _total),
          folioVenta: ventaId
      );
    } catch (e) {
      debugPrint("No se imprimió nada: $e");
    }

    if (!mounted) return;

    // GENERAR PDF PARA EL FORMULARIO (Si elige facturar)
    final ticketPdf = await ImpresionTicket.generarPdfTicket(
        items: _carrito,
        total: _total,
        recibido: _recibido,
        cambio: (_recibido - _total),
        folioVenta: ventaId
    );

    // PREGUNTA SI DESEA FACTURA
    await _preguntarFactura(ventaId, ticketPdf);

    _limpiarTodo();
  }

  Future<void> _preguntarFactura(int ventaId, List<int> ticketPdf) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Desea Factura?"),
        content: const Text("Se enviará la solicitud con los datos fiscales y una copia del ticket."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("NO", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FacturaForm(ventaId: ventaId, ticketPdf: ticketPdf)),
              );
            },
            child: const Text("SÍ, FACTURAR"),
          ),
        ],
      ),
    );
  }

  void _limpiarTodo() {
    setState(() { _carrito.clear(); _total = 0.0; _recibido = 0.0; _recibidoController.clear(); });
    _guardarCarritoCache();
    _focusNode.requestFocus();
  }

  // --- LÓGICA DE FIADO MEJORADA ---
  Future<void> _crearFiado() async {
    if (_carrito.isEmpty) return;

    // 1. Convertimos el carrito al formato JSON usando tu nueva clase
    List<modelo.ItemVenta> itemsParaGuardar = _carrito.map((e) => modelo.ItemVenta(
      sku: e.producto.sku,
      descripcion: e.producto.descripcion,
      cantidad: e.cantidad,
      precio: e.producto.precio,
      costo: e.producto.costo,
    )).toList();

    String itemsResumenJson = modelo.ItemVenta.listaAJson(itemsParaGuardar);

    // 2. Declaramos el controlador FUERA del diálogo para poder desecharlo
    final TextEditingController nombreDeudorCtrl = TextEditingController();

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Registro de Deuda"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ingrese el nombre del cliente."),
              const SizedBox(height: 10),
              TextField(
                controller: nombreDeudorCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: "Nombre del Cliente", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 10),
              const Text("A deber: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Formatters.formatearMoneda(_total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                ),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  String nombre = nombreDeudorCtrl.text.trim();
                  if (nombre.isEmpty) return;

                  // Usamos el JSON en lugar del string con pipes
                  await DebtDB.instance.actualizarDeuda(nombre, itemsResumenJson, _total);

                  // REGISTRO DE COSTO EN EL CALENDARIO PARA CONTABILIDAD
                  double costoTotalVenta = 0.0;
                  for (var item in _carrito) {
                    costoTotalVenta += (item.producto.costo * item.cantidad);
                  }
                  
                  final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                  
                  // Registramos una venta de "Fiado" con 0 liquidez pero con el costo total
                  // Esto permite que el calendario reste el costo de la ganancia del día
                  await HistoryDB.instance.registrarVenta(
                    fecha: fecha,
                    total: 0, // No hay ingreso de dinero aún
                    costoTotal: costoTotalVenta,
                    items: itemsResumenJson,
                    recibido: 0,
                    cambio: 0,
                    cliente: 'Venta a crédito (Fiado): $nombre'
                  );

                  for (var item in _carrito) {
                    await DBHelper.instance.updateStock(item.producto.codigo, -item.cantidad);
                  }

                  if (mounted) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _limpiarTodo();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Quedó a nombre de $nombre, consúltalo en el apartado!")));
                  }
                },
                child: const Text("Confirmar")
            )
          ],
        )
    );

    // 3. Prevenimos el Memory Leak
    nombreDeudorCtrl.dispose();
  }

  void _alerta(String t, String m) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(t), content: Text(m), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("OK"))]));
  }

  // --- WIDGET: CALCULADORA DE CORTES CENTRADA Y RESPONSIVA ---
  Widget _barraCalculadoraCortes(double maxWidth) {
    // Calculamos un factor de escala basado en el ancho disponible (máximo 1000px)
    // El factor bajará hasta 0.75 si el ancho es pequeño
    double factor = (maxWidth / 1000).clamp(0.75, 1.0);

    InputDecoration inputStyle(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14 * factor),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8 * factor, vertical: 8 * factor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
    );

    return Align(
      alignment: Alignment.bottomCenter, // Centrada
      child: Container(
        padding: EdgeInsets.all(12 * factor),
        margin: const EdgeInsets.only(top: 10),
        constraints: const BoxConstraints(maxWidth: 1000),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          spacing: 10 * factor,
          runSpacing: 10 * factor,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calculate, color: Colors.blue.shade700, size: 28 * factor),
                SizedBox(width: 10 * factor),
                Text("Si ", style: TextStyle(fontSize: 16 * factor)),
              ],
            ),

            SizedBox(
              width: 90 * factor,
              child: TextField(
                controller: _calcBaseLen,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14 * factor),
                decoration: inputStyle("Tramo"),
                onChanged: (_) => _calcularReglaTres(),
              ),
            ),

            Text("(CM, LTS, ETC.) vale \$", style: TextStyle(fontSize: 16 * factor)),

            SizedBox(
              width: 90 * factor,
              child: TextField(
                controller: _calcBasePrecio,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14 * factor),
                decoration: inputStyle("\$"),
                onChanged: (_) => _calcularReglaTres(),
              ),
            ),

            Text(", los ", style: TextStyle(fontSize: 16 * factor)),

            SizedBox(
              width: 90 * factor,
              child: TextField(
                controller: _calcCorteLen,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14 * factor),
                decoration: inputStyle("Corte"),
                onChanged: (_) => _calcularReglaTres(),
              ),
            ),

            Text("(CM, LTS, ETC.) valen: ", style: TextStyle(fontSize: 16 * factor)),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 12 * factor, vertical: 6 * factor),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                Formatters.formatearMoneda(_calcResultado),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * factor
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.refresh, color: Colors.grey, size: 22 * factor),
              tooltip: "Limpiar",
              onPressed: () {
                _calcBaseLen.clear();
                _calcBasePrecio.clear();
                _calcCorteLen.clear();
                _calcularReglaTres();
              },
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- ENCABEZADO UNIFICADO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(
            color: Colores.venta,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Row(
            children: [
              Icon(Icons.point_of_sale, color: Colors.white, size: 28),
              SizedBox(width: 15),
              Text("PUNTO DE VENTA", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // --- Z-PATTERN: BUSCAR Y ESCANEAR ARRIBA (PUNTOS FOCALES 1 Y 2) ---
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                            backgroundColor: Colores.venta,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: _abrirBusquedaManual,
                          icon: const Icon(Icons.search, size: 28),
                          label: const Text("BUSCAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
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
                              controller: _codigoController,
                              focusNode: _focusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: "Escanea código de barras AQUÍ",
                                prefixIcon: const Icon(Icons.qr_code_scanner, color: Colores.venta),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colores.venta, width: 2)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onSubmitted: (value) => _escanearCodigo(value),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- CARRITO (SOMBRA SOLICITADA) ---
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: _carrito.isEmpty
                                  ? const Center(child: Text("Carrito vacío", style: TextStyle(color: Colors.grey, fontSize: 20)))
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListView.separated(
                                        separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey[200]),
                                        itemCount: _carrito.length,
                                        itemBuilder: (context, index) {
                                          final item = _carrito[index];
                                          final p = item.producto;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            color: index % 2 == 0 ? Colors.blue[50]!.withValues(alpha: 0.2) : Colors.white,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Text(Formatters.formatearMoneda(p.precio), style: const TextStyle(color: Colores.venta, fontWeight: FontWeight.bold)),
                                                          const Text(" c/u", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                          const SizedBox(width: 15),
                                                          Icon(Icons.inventory_2_outlined, size: 14, color: p.stock <= 0 ? Colors.red : Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Text("Stock: ${p.stock}", style: TextStyle(color: p.stock <= 0 ? Colors.red : Colors.grey[700], fontSize: 12)),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                                  child: Row(
                                                    children: [
                                                      IconButton(icon: const Icon(Icons.remove, color: Colors.red, size: 20), onPressed: () => _cambiarCantidad(item, -1)),
                                                      Text("${item.cantidad}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                      IconButton(icon: const Icon(Icons.add, color: Colors.green, size: 20), onPressed: () => _cambiarCantidad(item, 1)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                SizedBox(
                                                  width: 100,
                                                  child: Text(Formatters.formatearMoneda(item.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colores.venta)),
                                                ),
                                                const SizedBox(width: 10),
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                                  onPressed: () => _editarProductoEnVenta(item),
                                                  tooltip: "Editar",
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () => _eliminarItem(item),
                                                  tooltip: "Eliminar",
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // --- RESUMEN DE COBRO (SOMBRA SOLICITADA) ---
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Card(
                                    color: Colors.grey[50],
                                    elevation: 8, // Sombra más pronunciada
                                    shadowColor: Colors.black26,
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const Text("Resumen", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                          const Divider(thickness: 2),
                                          const SizedBox(height: 10),
                                          Text("TOTAL A PAGAR", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(Formatters.formatearMoneda(_total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue)),
                                          ),
                                          const SizedBox(height: 30),
                                          TextField(
                                            controller: _recibidoController,
                                            inputFormatters: [ThousandsSeparatorInputFormatter()],
                                            decoration: const InputDecoration(labelText: "Dinero Recibido", prefixText: "\$", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(fontSize: 20),
                                            onChanged: (val) {
                                              setState(() {
                                                _recibido = ThousandsSeparatorInputFormatter.parse(val);
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
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(Formatters.formatearMoneda(_recibido - _total), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: (_recibido - _total) >= 0 ? Colors.green : Colors.red)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 25),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  SizedBox(
                                                    height: 60,
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colores.verde,
                                                        foregroundColor: Colors.white,
                                                        elevation: 4,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                      ),
                                                      onPressed: _finalizarVenta,
                                                      icon: const Icon(Icons.check_circle, size: 30),
                                                      label: const Text("COBRAR", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  SizedBox(
                                                    height: 40,
                                                    child: TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.red,
                                                        padding: EdgeInsets.zero,
                                                      ),
                                                      onPressed: _crearFiado,
                                                      icon: const Icon(Icons.person_add_alt_1, size: 20),
                                                      label: const Text("Fiado", style: TextStyle(fontWeight: FontWeight.bold)),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  if (_carrito.isNotEmpty)
                                                    SizedBox(
                                                      height: 50,
                                                      child: ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white,
                                                          elevation: 2,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                        ),
                                                        onPressed: _limpiarTodo,
                                                        icon: const Icon(Icons.delete_sweep),
                                                        label: const Text("VACIAR CARRITO", style: TextStyle(fontWeight: FontWeight.bold)),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini calculadora integrada y responsiva
                    _barraCalculadoraCortes(maxWidth),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
    if (query.length < 2) return; // Evitamos búsquedas con 1 sola letra

    // Reutilizamos la misma regla de negocio
    final lista = await DBHelper.instance.buscarParaSeleccionManual(query);

    if (mounted) {
      setState(() => _resultados = lista);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Buscar producto"),
      content: SizedBox(width: 600, height: 500, child: Column(children: [
        TextField(
            autofocus: true,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Escribe el nombre o SKU",
                border: OutlineInputBorder()
            ),
            onChanged: _buscar
        ),
        const SizedBox(height: 10),
        Expanded(child: ListView.separated(separatorBuilder: (c, i) => const Divider(), itemCount: _resultados.length, itemBuilder: (c, i) {
          final p = _resultados[i];
          return ListTile(
            title: Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${Formatters.formatearMoneda(p.precio)} | Stock: ${p.stock}"),
            trailing: ElevatedButton(child: const Text("Agregar"), onPressed: () => widget.onSeleccionado(p)),
          );
        }))
      ])),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar"))],
    );
  }
}