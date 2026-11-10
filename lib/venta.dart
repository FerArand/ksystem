import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'Utils/formatters.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/dialogo_pago.dart';
import 'factura_form.dart';
import 'Utils/numeric_formatter.dart';
import 'models/item_venta.dart' as modelo;

class ItemVenta {
  Producto producto;
  double cantidad; // Soporta enteros y decimales para venta a granel (RF-16)

  ItemVenta({
    required this.producto,
    num cantidad = 1,
  }) : cantidad = cantidad.toDouble();

  double get subtotal => producto.precio * cantidad;
  double get costoProporcional => producto.costo * cantidad;
}

class Venta extends StatefulWidget {
  const Venta({Key? key}) : super(key: key);

  @override
  State< Venta > createState() => _VentaState();
}

class _VentaState extends State< Venta > {
  final List< ItemVenta > _carrito = [];
  final TextEditingController _codigoController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  double _total = 0.0;
  double _recibido = 0.0;
  final TextEditingController _recibidoController = TextEditingController();

  // Controladores para sincronización bidireccional de artículos a granel (RF-16)
  final Map< String, TextEditingController > _medidaGranelCtrl = {};
  final Map< String, TextEditingController > _importeGranelCtrl = {};
  bool _actualizandoGranelInterno = false;

  @override
  void initState() {
    super.initState();
    _cargarCarritoCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  bool _esProductoGranel(Producto p) =>
      p.esGranel || p.descripcion.toUpperCase().contains('(GRAN.)');

  String _llaveItemGranel(Producto p, int index) =>
      p.codigo.isNotEmpty ? p.codigo : '${p.sku}_$index';

  String _formatearCantidad(num valor) {
    final double d = valor.toDouble();
    return d == d.roundToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  void _limpiarControladoresGranel() {
    for (final c in _medidaGranelCtrl.values) {
      c.dispose();
    }
    for (final c in _importeGranelCtrl.values) {
      c.dispose();
    }
    _medidaGranelCtrl.clear();
    _importeGranelCtrl.clear();
  }

  // --- PERSISTENCIA DEL CARRITO ---
  Future< void > _guardarCarritoCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cart_cache.json');

      List< Map< String, dynamic > > items = _carrito
          .map((e) => {
        'producto': e.producto.aMapa(),
        'cantidad': e.cantidad,
      })
          .toList();

      await file.writeAsString(jsonEncode(items));
    } catch (e) {
      debugPrint("Error guardando cache del carrito: $e");
    }
  }

  Future< void > _cargarCarritoCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cart_cache.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final List< dynamic > json = jsonDecode(content);

        setState(() {
          _carrito.clear();
          _limpiarControladoresGranel();
          for (var item in json) {
            _carrito.add(ItemVenta(
              producto: Producto.desdeMapa(item['producto']),
              cantidad: (item['cantidad'] as num?)?.toDouble() ?? 1.0,
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
    for (var item in _carrito) {
      temp += item.subtotal;
    }
    setState(() => _total = temp);
  }

  Future< void > _escanearCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    final data = await DBHelper.instance.getProductoPorCodigo(codigo.trim());

    if (data != null) {
      final p = Producto.desdeMapa(data);
      _agregarItemLogica(p);
    } else {
      _abrirFormularioCreacionDirecta(codigo.trim());
    }
    _codigoController.clear();
    _focusNode.requestFocus();
  }

  Future< void > _abrirFormularioCreacionDirecta(String codigo) async {
    await showDialog(
      context: context,
      builder: (c) => ProductFormDialog(
        codigoInicial: codigo,
        onGuardado: (nuevoProducto) {
          _agregarItemLogica(nuevoProducto);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Producto agregado")),
          );
        },
      ),
    );
    _focusNode.requestFocus();
  }

  void _agregarItemLogica(Producto p) {
    int index = _carrito.indexWhere(
          (item) =>
      (p.id != null && item.producto.id == p.id) ||
          (p.codigo.isNotEmpty && item.producto.codigo == p.codigo),
    );
    setState(() {
      if (index != -1) {
        _carrito[index].cantidad = double.parse(
          (_carrito[index].cantidad + 1.0).toStringAsFixed(4),
        );
        if (_esProductoGranel(p)) {
          final String key = _llaveItemGranel(p, index);
          final double nuevaCant = _carrito[index].cantidad;
          _medidaGranelCtrl[key]?.text = _formatearCantidad(nuevaCant);
          _importeGranelCtrl[key]?.text = (nuevaCant * p.precio).toStringAsFixed(2);
        }
      } else {
        _carrito.insert(0, ItemVenta(producto: p, cantidad: 1.0));
      }
      _calcularTotal();
    });
    _guardarCarritoCache();
  }

  void _cambiarCantidad(ItemVenta item, int delta) {
    setState(() {
      double nuevaCant = item.cantidad + delta;

      if (nuevaCant < 1) {
        _carrito.remove(item);
      } else {
        item.cantidad = nuevaCant.roundToDouble();
      }
      _calcularTotal();
    });
    _guardarCarritoCache();
  }

  Future< void > _abrirBusquedaManual() async {
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

  Future< void > _editarProductoEnVenta(ItemVenta item, int index) async {
    showDialog(
      context: context,
      builder: (c) => ProductFormDialog(
        productoExistente: item.producto,
        onGuardado: (p) {
          setState(() {
            item.producto = p;
            final String key = _llaveItemGranel(p, index);
            if (_esProductoGranel(p)) {
              _medidaGranelCtrl[key]?.text = _formatearCantidad(item.cantidad);
              _importeGranelCtrl[key]?.text =
                  (item.cantidad * p.precio).toStringAsFixed(2);
            }
            _calcularTotal();
          });
          _guardarCarritoCache();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Se guardó correctamente.")),
          );
        },
      ),
    );
  }

  void _eliminarItem(ItemVenta item, int index) {
    final String key = _llaveItemGranel(item.producto, index);
    _medidaGranelCtrl.remove(key)?.dispose();
    _importeGranelCtrl.remove(key)?.dispose();
    setState(() {
      _carrito.removeAt(index);
      _calcularTotal();
    });
    _guardarCarritoCache();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _focusNode.dispose();
    _recibidoController.dispose();
    _limpiarControladoresGranel();
    super.dispose();
  }

  // --- WIDGET DE CONTROL EN RENGLÓN: ENTERO VS. GRANEL BIDIRECCIONAL (RF-16) ---
  Widget _buildControlesCantidad(ItemVenta item, int index) {
    final p = item.producto;

    // 1. Producto normal (entero): conserva los botones [- / +] originales
    if (!_esProductoGranel(p)) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.red, size: 20),
              onPressed: () => _cambiarCantidad(item, -1),
            ),
            Text(
              item.cantidad.toInt().toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.green, size: 20),
              onPressed: () => _cambiarCantidad(item, 1),
            ),
          ],
        ),
      );
    }

    // 2. Producto a granel: sincronización bidireccional Medida (m/kg) <-> Importe ($)
    final String key = _llaveItemGranel(p, index);
    final double precioUnitario = p.precio > 0 ? p.precio : 1.0;

    final ctrlMedida = _medidaGranelCtrl.putIfAbsent(
      key,
          () => TextEditingController(
        text: item.cantidad > 0 ? _formatearCantidad(item.cantidad) : '',
      ),
    );

    final ctrlImporte = _importeGranelCtrl.putIfAbsent(
      key,
          () => TextEditingController(
        text: item.cantidad > 0
            ? (item.cantidad * precioUnitario).toStringAsFixed(2)
            : '',
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 105,
          child: TextField(
            controller: ctrlMedida,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Medida (m/kg)',
              labelStyle: const TextStyle(fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) {
              if (_actualizandoGranelInterno) return;
              _actualizandoGranelInterno = true;

              final double medida =
                  double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
              final double importeCobro = medida * precioUnitario;

              setState(() {
                item.cantidad = double.parse(medida.toStringAsFixed(4));
                ctrlImporte.text =
                medida > 0 ? importeCobro.toStringAsFixed(2) : '';
                _calcularTotal();
              });
              _guardarCarritoCache();
              _actualizandoGranelInterno = false;
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.swap_horiz, color: Colores.venta, size: 18),
        ),
        SizedBox(
          width: 105,
          child: TextField(
            controller: ctrlImporte,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Importe (\$)',
              prefixText: '\$',
              labelStyle: const TextStyle(fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) {
              if (_actualizandoGranelInterno) return;
              _actualizandoGranelInterno = true;

              final double importe =
                  double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
              final double medidaCalculada = importe / precioUnitario;

              setState(() {
                item.cantidad = double.parse(medidaCalculada.toStringAsFixed(4));
                ctrlMedida.text =
                importe > 0 ? _formatearCantidad(medidaCalculada) : '';
                _calcularTotal();
              });
              _guardarCarritoCache();
              _actualizandoGranelInterno = false;
            },
          ),
        ),
      ],
    );
  }

  // --- FINALIZAR VENTA CON DIÁLOGO DE PAGO Y GRANEL (RF-07, RF-16, RF-19) ---
  Future< void > _finalizarVenta() async {
    if (_carrito.isEmpty) return;

    // 1. Validar que ningún producto a granel tenga cantidad 0
    final bool hayCantidadInvalida = _carrito.any((e) => e.cantidad <= 0.0001);
    if (hayCantidadInvalida) {
      _alerta(
        "Cantidad inválida",
        "Ingresa una medida o importe mayor a 0 en los productos a granel.",
      );
      return;
    }

    // 2. Mostrar ventana modal de selección y confirmación de método de pago (RF-19)
    final resultadoPago = await showDialog< ResultadoPago >(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogoPago(
        totalCobrar: _total,
        efectivoInicial: _recibido,
      ),
    );

    // Si el cajero cerró o canceló la ventana modal, la venta sigue abierta
    if (resultadoPago == null) return;

    final double recibidoFinal = resultadoPago.recibido;
    final double cambioFinal = resultadoPago.cambio;
    final String metodoPagoStr = resultadoPago.metodoPago;

    // 3. Preparar datos para guardar
    List< modelo.ItemVenta > itemsParaGuardar = _carrito
        .map((e) => modelo.ItemVenta(
      sku: e.producto.sku.isNotEmpty ? e.producto.sku : e.producto.codigo,
      codigo: e.producto.codigo,
      descripcion: e.producto.descripcion,
      cantidad: e.cantidad,
      precio: e.producto.precio,
      costo: e.producto.costo,
      esGranel: _esProductoGranel(e.producto),
    ))
        .toList();

    String itemsResumenJson = modelo.ItemVenta.listaAJson(itemsParaGuardar);
    final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    double costoTotalVenta = 0.0;
    for (var item in _carrito) {
      costoTotalVenta += (item.producto.costo * item.cantidad);
    }

    // 4. Registrar en base de datos local SQLite (con método de pago y costo proporcional)
    int ventaId = await DBHelper.instance.registrarVenta(
      fecha: fecha,
      total: _total,
      costoTotal: costoTotalVenta,
      items: itemsResumenJson,
      recibido: recibidoFinal,
      cambio: cambioFinal,
      cliente: 'Mostrador',
      metodoPago: metodoPagoStr,
    );

    // 5. Actualizar Stock (soporta descuento entero y decimal)
    for (var item in _carrito) {
      await DBHelper.instance.updateStock(item.producto.codigo, -item.cantidad);
    }

    // 6. Imprimir Ticket Térmico de 58 mm
    final itemsParaTicket = _carrito
        .map((e) => modelo.ItemVenta(
      sku: e.producto.codigo,
      codigo: e.producto.codigo,
      descripcion: e.producto.descripcion,
      cantidad: e.cantidad,
      precio: e.producto.precio,
      costo: e.producto.costo,
      esGranel: _esProductoGranel(e.producto),
    ))
        .toList();

    try {
      await ImpresionTicket.imprimirTicket(
        items: itemsParaTicket,
        total: _total,
        recibido: recibidoFinal,
        cambio: cambioFinal,
        folioVenta: ventaId,
        metodoPago: metodoPagoStr,
      );
    } catch (e) {
      debugPrint("No se imprimió nada: $e");
    }

    if (!mounted) return;

    // 7. Generar PDF para el formulario de factura
    final ticketPdf = await ImpresionTicket.generarPdfTicket(
      items: itemsParaTicket,
      total: _total,
      recibido: recibidoFinal,
      cambio: cambioFinal,
      folioVenta: ventaId,
      metodoPago: metodoPagoStr,
    );

    // Preguntar si desea factura
    await _preguntarFactura(ventaId, ticketPdf);

    _limpiarTodo();
  }

  Future< void > _preguntarFactura(int ventaId, List< int > ticketPdf) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Desea Factura?"),
        content: const Text(
          "Se enviará la solicitud con los datos fiscales y una copia del ticket.",
        ),
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
                MaterialPageRoute(
                  builder: (context) =>
                      FacturaForm(ventaId: ventaId, ticketPdf: ticketPdf),
                ),
              );
            },
            child: const Text("SÍ, FACTURAR"),
          ),
        ],
      ),
    );
  }

  void _limpiarTodo() {
    _limpiarControladoresGranel();
    setState(() {
      _carrito.clear();
      _total = 0.0;
      _recibido = 0.0;
      _recibidoController.clear();
    });
    _guardarCarritoCache();
    _focusNode.requestFocus();
  }

  // --- LÓGICA DE FIADO MEJORADA ---
  Future< void > _crearFiado() async {
    if (_carrito.isEmpty) return;

    final bool hayCantidadInvalida = _carrito.any((e) => e.cantidad <= 0.0001);
    if (hayCantidadInvalida) {
      _alerta(
        "Cantidad inválida",
        "Ingresa una medida o importe mayor a 0 en los productos a granel.",
      );
      return;
    }

    List< modelo.ItemVenta > itemsParaGuardar = _carrito
        .map((e) => modelo.ItemVenta(
      sku: e.producto.sku.isNotEmpty ? e.producto.sku : e.producto.codigo,
      codigo: e.producto.codigo,
      descripcion: e.producto.descripcion,
      cantidad: e.cantidad,
      precio: e.producto.precio,
      costo: e.producto.costo,
      esGranel: _esProductoGranel(e.producto),
    ))
        .toList();

    String itemsResumenJson = modelo.ItemVenta.listaAJson(itemsParaGuardar);

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
              decoration: const InputDecoration(
                labelText: "Nombre del Cliente",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "A deber: ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                Formatters.formatearMoneda(_total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              String nombre = nombreDeudorCtrl.text.trim();
              if (nombre.isEmpty) return;

              await DBHelper.instance.actualizarDeuda(
                nombre,
                itemsResumenJson,
                _total,
              );

              double costoTotalVenta = 0.0;
              for (var item in _carrito) {
                costoTotalVenta += (item.producto.costo * item.cantidad);
              }

              final fecha =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

              int ventaId = await DBHelper.instance.registrarVenta(
                fecha: fecha,
                total: 0,
                costoTotal: costoTotalVenta,
                items: itemsResumenJson,
                recibido: 0,
                cambio: 0,
                cliente: 'Venta a crédito (Fiado): $nombre',
                metodoPago: 'Crédito (Fiado)',
              );

              for (var item in _carrito) {
                await DBHelper.instance.updateStock(
                  item.producto.codigo,
                  -item.cantidad,
                );
              }

              try {
                final itemsDeudaParaTicket = _carrito
                    .map((e) => modelo.ItemVenta(
                  sku: e.producto.codigo,
                  codigo: e.producto.codigo,
                  descripcion: e.producto.descripcion,
                  cantidad: e.cantidad,
                  precio: e.producto.precio,
                  costo: e.producto.costo,
                  esGranel: _esProductoGranel(e.producto),
                ))
                    .toList();

                await ImpresionTicket.imprimirTicket(
                  items: itemsDeudaParaTicket,
                  total: _total,
                  recibido: 0,
                  cambio: 0,
                  folioVenta: ventaId,
                  nombreCliente: nombre,
                  metodoPago: 'Crédito (Fiado)',
                );
              } catch (e) {
                debugPrint("Error al imprimir ticket de deuda: $e");
              }

              if (mounted) {
                if (ctx.mounted) Navigator.pop(ctx);
                _limpiarTodo();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Quedó a nombre de $nombre, consúltalo en el apartado!",
                    ),
                  ),
                );
              }
            },
            child: const Text("Confirmar"),
          )
        ],
      ),
    );

    nombreDeudorCtrl.dispose();
  }

  void _alerta(String t, String m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.point_of_sale, color: Colors.white, size: 28),
              SizedBox(width: 15),
              Text(
                "PUNTO DE VENTA",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- Z-PATTERN: BUSCAR Y ESCANEAR ARRIBA ---
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        backgroundColor: Colores.venta,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _abrirBusquedaManual,
                      icon: const Icon(Icons.search, size: 28),
                      label: const Text(
                        "BUSCAR",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
                            prefixIcon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colores.venta,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colores.venta,
                                width: 2,
                              ),
                            ),
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
                      // --- CARRITO ---
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: _carrito.isEmpty
                              ? const Center(
                            child: Text(
                              "Carrito vacío",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                            ),
                          )
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              separatorBuilder: (ctx, i) => Divider(
                                height: 1,
                                color: Colors.grey[200],
                              ),
                              itemCount: _carrito.length,
                              itemBuilder: (context, index) {
                                final item = _carrito[index];
                                final p = item.producto;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  color: index % 2 == 0
                                      ? Colors.blue[50]!
                                      .withValues(alpha: 0.2)
                                      : Colors.white,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    p.descripcion,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                if (_esProductoGranel(p)) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration:
                                                    BoxDecoration(
                                                      color: Colors
                                                          .orange.shade50,
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(4),
                                                      border: Border.all(
                                                        color: Colors
                                                            .orange
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "GRANEL",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                        FontWeight.bold,
                                                        color: Colors
                                                            .orange
                                                            .shade900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  Formatters
                                                      .formatearMoneda(
                                                    p.precio,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colores.venta,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _esProductoGranel(p)
                                                      ? " por unidad/m/kg"
                                                      : " c/u",
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 15),
                                                Icon(
                                                  Icons
                                                      .inventory_2_outlined,
                                                  size: 14,
                                                  color: p.stock <= 0
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Stock: ${p.stockFormateado}",
                                                  style: TextStyle(
                                                    color: p.stock <= 0
                                                        ? Colors.red
                                                        : Colors.grey[700],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildControlesCantidad(item, index),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          Formatters.formatearMoneda(
                                            item.subtotal,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colores.venta,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.orange,
                                        ),
                                        onPressed: () =>
                                            _editarProductoEnVenta(
                                              item,
                                              index,
                                            ),
                                        tooltip: "Editar",
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _eliminarItem(item, index),
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

                      // --- RESUMEN DE COBRO ---
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Card(
                                color: Colors.grey[50],
                                elevation: 8,
                                shadowColor: Colors.black26,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        "Resumen",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Divider(thickness: 2),
                                      const SizedBox(height: 10),
                                      Text(
                                        "TOTAL A PAGAR",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          Formatters.formatearMoneda(_total),
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      TextField(
                                        controller: _recibidoController,
                                        inputFormatters: [
                                          ThousandsSeparatorInputFormatter()
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: "Dinero Recibido",
                                          prefixText: "\$",
                                          border: OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 20),
                                        onChanged: (val) {
                                          setState(() {
                                            _recibido =
                                                ThousandsSeparatorInputFormatter
                                                    .parse(val);
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        color: (_recibido - _total) >= 0
                                            ? Colors.green[50]
                                            : Colors.red[50],
                                        child: Column(
                                          children: [
                                            const Text(
                                              "Cambio",
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                Formatters.formatearMoneda(
                                                  _recibido - _total,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: (_recibido - _total) >= 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 25),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                            children: [
                                              SizedBox(
                                                height: 60,
                                                child: ElevatedButton.icon(
                                                  style:
                                                  ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                    Colores.verde,
                                                    foregroundColor:
                                                    Colors.white,
                                                    elevation: 4,
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                  onPressed: _finalizarVenta,
                                                  icon: const Icon(
                                                    Icons.check_circle,
                                                    size: 30,
                                                  ),
                                                  label: const Text(
                                                    "COBRAR",
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                    ),
                                                  ),
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
                                                  icon: const Icon(
                                                    Icons.person_add_alt_1,
                                                    size: 20,
                                                  ),
                                                  label: const Text(
                                                    "Fiado",
                                                    style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              if (_carrito.isNotEmpty)
                                                SizedBox(
                                                  height: 50,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                      Colors.red,
                                                      foregroundColor:
                                                      Colors.white,
                                                      elevation: 2,
                                                      shape:
                                                      RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(10),
                                                      ),
                                                    ),
                                                    onPressed: _limpiarTodo,
                                                    icon: const Icon(
                                                      Icons.delete_sweep,
                                                    ),
                                                    label: const Text(
                                                      "VACIAR CARRITO",
                                                      style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold,
                                                      ),
                                                    ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DialogoBusquedaVenta extends StatefulWidget {
  final Function(Producto) onSeleccionado;
  const DialogoBusquedaVenta({Key? key, required this.onSeleccionado})
      : super(key: key);

  @override
  State< DialogoBusquedaVenta > createState() => _DialogoBusquedaVentaState();
}

class _DialogoBusquedaVentaState extends State< DialogoBusquedaVenta > {
  List< Producto > _resultados = [];

  Future< void > _buscar(String query) async {
    if (query.length < 2) return;

    final lista = await DBHelper.instance.buscarParaSeleccionManual(query);

    if (mounted) {
      setState(() => _resultados = lista);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Buscar producto"),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Escribe el nombre o SKU",
                border: OutlineInputBorder(),
              ),
              onChanged: _buscar,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                separatorBuilder: (c, i) => const Divider(),
                itemCount: _resultados.length,
                itemBuilder: (c, i) {
                  final p = _resultados[i];
                  return ListTile(
                    title: Text(
                      p.descripcion,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${Formatters.formatearMoneda(p.precio)} | Stock: ${p.stockFormateado}",
                    ),
                    trailing: ElevatedButton(
                      child: const Text("Agregar"),
                      onPressed: () => widget.onSeleccionado(p),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        )
      ],
    );
  }
}