import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'databases/history_db.dart';
import 'db_helper.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'models/pedido.dart';
import 'factura_form.dart';
import 'models/item_venta.dart' as modelo;
import 'databases/app_database.dart';
import 'Utils/formatters.dart';

class CalendarioVentas extends StatefulWidget {
  const CalendarioVentas({Key? key}) : super(key: key);

  @override
  State<CalendarioVentas> createState() => _CalendarioVentasState();
}

class _CalendarioVentasState extends State<CalendarioVentas> {
  DateTime _fechaActual = DateTime.now();
  Map<String, Map<String, double>> _datosDias = {}; // Cambiado a String (YYYY-MM-DD)
  int _totalDiasGrid = 35; // Por defecto 5 semanas

  // Datos estadísticos
  String _mejorProductoMes = "Calculando...";
  String _datoDestacado = "...";

  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosMes(_fechaActual);
  }

  Future<void> _cargarDatosMes(DateTime fecha) async {
    setState(() { _cargando = true; _datosDias.clear(); });

    // 1. CALCULAR RANGO DEL CALENDARIO (Para semanas completas)
    int year = fecha.year;
    int month = fecha.month;
    DateTime primerDiaMes = DateTime(year, month, 1);
    int offset = primerDiaMes.weekday == 7 ? 0 : primerDiaMes.weekday;
    DateTime inicioCalendario = primerDiaMes.subtract(Duration(days: offset));

    // CALCULAR FILAS NECESARIAS (5 o 6 semanas)
    int diasEnMes = DateTime(year, month + 1, 0).day;
    int totalDiasNecesarios = offset + diasEnMes;
    int calculoGrid = totalDiasNecesarios > 35 ? 42 : 35;

    DateTime finCalendario = inicioCalendario.add(Duration(days: calculoGrid - 1));

    String inicioStr = DateFormat('yyyy-MM-dd').format(inicioCalendario);
    String finStr = DateFormat('yyyy-MM-dd').format(finCalendario);

    // 2. OBTENER RESUMEN POR RANGO
    final ventas = await HistoryDB.instance.obtenerVentasRango(inicioStr, finStr);

    Map<String, Map<String, double>> temp = {};
    double maxVenta = 0;
    String diaMejor = "";

    for (var v in ventas) {
      String fechaStr = v['fecha_dia'];
      double total = v['total_venta'] ?? 0.0;
      double costo = v['total_costo'] ?? 0.0;

      temp[fechaStr] = {
        'venta': total,
        'costo': costo,
        'ganancia': total - costo
      };

      // El récord sigue siendo solo del mes actual para el "Día récord"
      if (fechaStr.startsWith(DateFormat('yyyy-MM').format(fecha))) {
        if (total > maxVenta) {
          maxVenta = total;
          diaMejor = fechaStr.split('-')[2];
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _datosDias = temp;
      _mejorProductoMes = maxVenta > 0 ? "Día récord: $diaMejor" : "Sin ventas";
      _datoDestacado = Formatters.formatearMoneda(maxVenta);
      _fechaActual = fecha;
      _totalDiasGrid = calculoGrid;
      _cargando = false;
    });
  }

  void _cambiarMes(int delta) {
    DateTime nueva = DateTime(_fechaActual.year, _fechaActual.month + delta, 1);
    _cargarDatosMes(nueva);
  }

  void _mostrarDialogoDevolucion(Map<String, dynamic> ticketData) async {
    final String itemsString = ticketData['items'] ?? "[]";
    final List<modelo.ItemVenta> itemsOriginales = modelo.ItemVenta.listaDesdeString(itemsString);
    
    // Mapa para rastrear cuántos se van a devolver de cada uno
    // Key: index o descripción+sku para mayor seguridad
    Map<int, int> cantidadesDevolver = {};
    for(int i=0; i<itemsOriginales.length; i++) {
      cantidadesDevolver[i] = 0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setInnerState) {
          // Calcular el total a devolver en tiempo real
          double totalADevolver = 0;
          for (int i = 0; i < itemsOriginales.length; i++) {
            totalADevolver += (itemsOriginales[i].precio * cantidadesDevolver[i]!);
          }

          return AlertDialog(
            title: Text("Devolución - Folio #${ticketData['folio_venta']}"),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Selecciona la cantidad de productos a devolver:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: itemsOriginales.length,
                      itemBuilder: (c, i) {
                        final item = itemsOriginales[i];
                        return ListTile(
                          title: Text(item.descripcion, style: const TextStyle(fontSize: 14)),
                          subtitle: Text("Original: ${item.cantidad} • Precio: ${Formatters.formatearMoneda(item.precio)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: cantidadesDevolver[i]! > 0 
                                    ? () => setInnerState(() => cantidadesDevolver[i] = cantidadesDevolver[i]! - 1) 
                                    : null,
                              ),
                              Text("${cantidadesDevolver[i]}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: cantidadesDevolver[i]! < item.cantidad 
                                    ? () => setInnerState(() => cantidadesDevolver[i] = cantidadesDevolver[i]! + 1) 
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total a reintegrar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          Formatters.formatearMoneda(totalADevolver),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: totalADevolver == 0 
                    ? null 
                    : () async {
                        Navigator.pop(ctx);
                        await _ejecutarDevolucion(ticketData, itemsOriginales, cantidadesDevolver);
                      },
                child: const Text("Confirmar Devolución"),
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> _ejecutarDevolucion(Map<String, dynamic> ticketData, List<modelo.ItemVenta> itemsOriginales, Map<int, int> cantidadesDevolver) async {
    setState(() => _cargando = true);
    try {
      List<modelo.ItemVenta> itemsRestantes = [];
      List<modelo.ItemVenta> itemsDevueltosEfectivos = [];
      double nuevoTotal = 0;
      double nuevoCosto = 0;

      for (int i = 0; i < itemsOriginales.length; i++) {
        final item = itemsOriginales[i];
        int devueltos = cantidadesDevolver[i]!;
        int quedan = item.cantidad - devueltos;

        if (devueltos > 0) {
          // Devolver al stock
          await DBHelper.instance.updateStock(item.sku, devueltos);
          itemsDevueltosEfectivos.add(modelo.ItemVenta(
            sku: item.sku,
            descripcion: item.descripcion,
            cantidad: devueltos,
            precio: item.precio,
            costo: item.costo
          ));
        }

        if (quedan > 0) {
          itemsRestantes.add(modelo.ItemVenta(
            sku: item.sku,
            descripcion: item.descripcion,
            cantidad: quedan,
            precio: item.precio,
            costo: item.costo
          ));
          nuevoTotal += (item.precio * quedan);
          nuevoCosto += (item.costo * quedan);
        }
      }

      String folioOriginalStr = ticketData['folio_venta'].toString();
      String nuevoFolio = folioOriginalStr.endsWith('M') ? folioOriginalStr : "${folioOriginalStr}M";
      String nuevosItemsJson = modelo.ItemVenta.listaAJson(itemsRestantes);
      
      // Mapear devueltos para el registro detallado
      List<Map<String, dynamic>> devueltosDetalle = itemsDevueltosEfectivos.map((e) => e.toJson()).toList();

      await HistoryDB.instance.actualizarVentaModificada(
        id: ticketData['id'],
        nuevoTotal: nuevoTotal,
        nuevoCosto: nuevoCosto,
        nuevosItems: nuevosItemsJson,
        itemsDevueltos: devueltosDetalle,
        nuevoFolioDisplay: nuevoFolio
      );

      // Recargar datos para ver reflejado el cambio
      await _cargarDatosMes(_fechaActual);

      if (!mounted) return;
      
      // Ofrecer reimpresión
      final nuevaVentaData = Map<String, dynamic>.from(ticketData);
      nuevaVentaData['total'] = nuevoTotal;
      nuevaVentaData['costo_total'] = nuevoCosto;
      nuevaVentaData['items'] = nuevosItemsJson;
      nuevaVentaData['folio_venta'] = nuevoFolio;

      // Imprimir directamente
      await _reimprimir(nuevaVentaData, itemsDevueltos: itemsDevueltosEfectivos);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Devolución Exitosa. Imprimiendo ticket #$nuevoFolio..."),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error en devolución: $e")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reimprimir(Map<String, dynamic> ticketData, {List<modelo.ItemVenta>? itemsDevueltos}) async {
    try {
      final String cliente = ticketData['cliente']?.toString() ?? "";
      
      // Cargar detalles reales de la base de datos para mostrar devoluciones profesionales
      List<modelo.ItemVenta> itemsActivos = [];
      List<modelo.ItemVenta> itemsDevueltosReal = itemsDevueltos ?? [];
      
      if (itemsDevueltos == null) {
        final detalles = await HistoryDB.instance.obtenerDetallesVenta(ticketData['id']);
        if (detalles.isNotEmpty) {
          for (var d in detalles) {
            final item = modelo.ItemVenta.fromJson(d);
            if (d['estado'] == 'devuelto') {
              itemsDevueltosReal.add(item);
            } else {
              itemsActivos.add(item);
            }
          }
        } else {
          // Fallback al JSON de la cabecera si no hay detalles (ventas viejas)
          itemsActivos = _reconstruirItems(ticketData);
        }
      } else {
        itemsActivos = _reconstruirItems(ticketData);
      }

      if (cliente.startsWith('Apartado de:') || cliente.startsWith('Liquidación de apartado:')) {
        final String nombre = cliente.contains('Apartado de:') 
            ? cliente.replaceFirst('Apartado de: ', '').trim()
            : cliente.replaceFirst('Liquidación de apartado: ', '').trim();
            
        final bool isLiquidacion = cliente.startsWith('Liquidación de apartado:');
        final String itemsString = ticketData['items'] ?? "[]";
        final dynamic itemsJson = jsonDecode(itemsString);
        final String productoNombre = itemsJson.isNotEmpty ? itemsJson[0]['descripcion'].toString().replaceFirst('APARTADO: ', '') : "Producto";
        final String sku = itemsJson.isNotEmpty ? itemsJson[0]['sku'].toString() : "N/A";
        final double montoPagado = (ticketData['total'] as num).toDouble();
        final double costo = (ticketData['costo_total'] as num).toDouble();
        
        // Intentamos buscar el pedido en la base de datos para obtener datos completos (precio normal, etc)
        final db = await AppDatabase.instance.database;
        final res = await db.query('pedidos', where: 'cliente_nombre = ? AND producto_nombre = ?', whereArgs: [nombre, productoNombre]);
        
        Pedido pedido;
        if (res.isNotEmpty) {
          pedido = Pedido.desdeMapa(res.first);
        } else {
          // Si no existe, creamos un dummy con lo que tenemos
          pedido = Pedido(
            clienteNombre: nombre,
            clienteContacto: "N/A",
            productoNombre: productoNombre,
            productoSku: sku,
            precioNormal: montoPagado,
            precioApartado: montoPagado,
            abonoInicial: isLiquidacion ? 0 : montoPagado,
            totalPagado: isLiquidacion ? montoPagado : montoPagado,
            costo: costo,
            descuento: 0,
            fechaCreacion: ticketData['fecha'],
            estado: isLiquidacion ? 'entregado' : 'pendiente',
          );
        }

        await ImpresionTicket.imprimirTicketPedido(
          pedido: pedido,
          montoPagadoMomento: montoPagado,
          recibido: (ticketData['recibido'] as num?)?.toDouble() ?? montoPagado,
          cambio: (ticketData['cambio'] as num?)?.toDouble() ?? 0,
          isLiquidacion: isLiquidacion,
          isCopy: true,
        );
        return;
      }

      if (cliente.startsWith('Abono a deuda de:')) {
        final String nombre = cliente.replaceFirst('Abono a deuda de: ', '').trim();
        final String itemsString = ticketData['items'] ?? "[]";
        final items = modelo.ItemVenta.listaDesdeString(itemsString);
        final double montoAbonado = (ticketData['total'] as num).toDouble();
        
        final double recibido = ticketData['recibido'] != null 
            ? (ticketData['recibido'] as num).toDouble() 
            : montoAbonado;
        final double cambio = ticketData['cambio'] != null 
            ? (ticketData['cambio'] as num).toDouble() 
            : 0.0;

        // Buscamos si el deudor aún existe para mostrar saldo real
        final db = await AppDatabase.instance.database;
        final res = await db.query('deudores', where: 'nombre = ?', whereArgs: [nombre]);

        double saldoRestante = 0;
        double deudaAnterior = montoAbonado;

        if (res.isNotEmpty) {
          saldoRestante = (res.first['total_deuda'] as num).toDouble();
          deudaAnterior = saldoRestante + montoAbonado;
        }

        await ImpresionTicket.imprimirTicketAbono(
          nombreDeudor: nombre,
          items: items,
          montoAbonado: montoAbonado,
          deudaAnterior: deudaAnterior,
          saldoRestante: saldoRestante,
          recibido: recibido,
          cambio: cambio,
          isCopy: true,
        );
        return;
      }

      double total = (ticketData['total'] is int) ? (ticketData['total'] as int).toDouble() : ticketData['total'];
      double recibido = ticketData['recibido'] != null
          ? ((ticketData['recibido'] is int) ? (ticketData['recibido'] as int).toDouble() : ticketData['recibido'])
          : total;
      double cambio = ticketData['cambio'] != null
          ? ((ticketData['cambio'] is int) ? (ticketData['cambio'] as int).toDouble() : ticketData['cambio'])
          : 0.0;
      dynamic folio = ticketData['folio_venta'] ?? ticketData['id'] ?? 0;
      String fechaOriginal = ticketData['fecha'] ?? "";

      await ImpresionTicket.imprimirTicket(
          items: itemsActivos,
          total: total,
          recibido: recibido,
          cambio: cambio,
          folioVenta: folio,
          fechaOriginal: fechaOriginal,
          isCopy: true,
          itemsDevueltos: itemsDevueltosReal.isEmpty ? null : itemsDevueltosReal,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  List<modelo.ItemVenta> _reconstruirItems(Map<String, dynamic> ticketData) {
    String itemsString = ticketData['items'] ?? "";
    return modelo.ItemVenta.listaDesdeString(itemsString);
  }

  Future<void> _abrirFacturaDesdeHistorial(Map<String, dynamic> ticketData) async {
    try {
      final itemsReconstruidos = _reconstruirItems(ticketData);
      double total = (ticketData['total'] is int) ? (ticketData['total'] as int).toDouble() : ticketData['total'];
      double recibido = ticketData['recibido'] != null
          ? ((ticketData['recibido'] is int) ? (ticketData['recibido'] as int).toDouble() : ticketData['recibido'])
          : total;
      double cambio = ticketData['cambio'] != null
          ? ((ticketData['cambio'] is int) ? (ticketData['cambio'] as int).toDouble() : ticketData['cambio'])
          : 0.0;
      dynamic folio = ticketData['folio_venta'] ?? ticketData['id'] ?? 0;
      String fechaOriginal = ticketData['fecha'] ?? "";

      final pdfBytes = await ImpresionTicket.generarPdfTicket(
          items: itemsReconstruidos,
          total: total,
          recibido: recibido,
          cambio: cambio,
          folioVenta: folio,
          fechaOriginal: fechaOriginal
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FacturaForm(ventaId: folio, ticketPdf: pdfBytes)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al generar factura: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          bool isSmall = constraints.maxWidth < 900;
          return Column(
            children: [
              // --- ENCABEZADO UNIFICADO ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: const BoxDecoration(
                  color: Colores.calendario,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.white, size: 28),
                    const SizedBox(width: 15),
                    const Text("CALENDARIO DE VENTAS", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const Spacer(),
                    if (!isSmall) ...[
                      _recordCard(),
                    ]
                  ],
                ),
              ),

              // HEADER CONTROLES
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colores.calendario, size: 20),
                              onPressed: () => _cambiarMes(-1),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: Text(
                            DateFormat('MMMM yyyy', 'es_MX').format(_fechaActual).toUpperCase(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colores.calendario),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, color: Colores.calendario, size: 20),
                                onPressed: () => _cambiarMes(1),
                              ),
                              const Spacer(),
                              if (isSmall) _recordCard(compact: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.today, size: 18),
                          label: const Text("HOY"),
                          style: OutlinedButton.styleFrom(foregroundColor: Colores.calendario, side: const BorderSide(color: Colores.calendario)),
                          onPressed: () => _cargarDatosMes(DateTime.now()),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text("BUSCAR FOLIO"),
                          style: OutlinedButton.styleFrom(foregroundColor: Colores.calendario, side: const BorderSide(color: Colores.calendario)),
                          onPressed: _mostrarBuscadorFolio,
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.analytics, size: 18),
                          label: const Text("RESUMEN MENSUAL"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colores.calendario, foregroundColor: Colors.white, elevation: 2),
                          onPressed: _mostrarResumenMensual,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // DÍAS SEMANA
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'TOTAL SEM'].map((d) => Expanded(
                      flex: d == 'TOTAL SEM' ? 2 : 1,
                      child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: isSmall ? 10 : 12)))
                  )).toList(),
                ),
              ),
              Expanded(child: _cargando ? const Center(child: CircularProgressIndicator(color: Colores.calendario)) : _buildCalendarioGrid(isSmall: isSmall)),
            ],
          );
        }
    );
  }

  Widget _recordCard({bool compact = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_mejorProductoMes, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text(_datoDestacado, style: TextStyle(color: Colors.grey[800], fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarioGrid({bool isSmall = false}) {
    int year = _fechaActual.year;
    int month = _fechaActual.month;
    DateTime primerDiaMes = DateTime(year, month, 1);
    int offset = primerDiaMes.weekday == 7 ? 0 : primerDiaMes.weekday;
    DateTime fechaInicio = primerDiaMes.subtract(Duration(days: offset));

    List<Widget> filas = [];
    List<Widget> celdasFila = [];
    double semVenta = 0, semGan = 0;

    for (int i = 0; i < _totalDiasGrid; i++) {
      DateTime diaActual = fechaInicio.add(Duration(days: i));
      String ymd = DateFormat('yyyy-MM-dd').format(diaActual);

      double v = _datosDias[ymd]?['venta'] ?? 0;
      double g = _datosDias[ymd]?['ganancia'] ?? 0;
      semVenta += v; semGan += g;

      celdasFila.add(Expanded(child: _buildCeldaDia(diaActual, v, g, isSmall: isSmall)));

      if ((i + 1) % 7 == 0) {
        // --- CELDA TOTAL SEMANAL ---
        celdasFila.add(Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Total", style: TextStyle(fontSize: isSmall ? 10 : 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Text(Formatters.formatearMonedaCompacta(semVenta),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: isSmall ? 14 : 20, color: Colors.blue)),
                Text("G: ${Formatters.formatearMonedaCompacta(semGan)}",
                    style: TextStyle(fontSize: isSmall ? 11 : 14, fontWeight: FontWeight.bold, color: Colors.green[800])),
              ],
            ),
          ),
        ));
        filas.add(Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: celdasFila)));
        celdasFila = []; semVenta = 0; semGan = 0;
      }
    }
    return Column(children: filas);
  }

  Widget _buildCeldaDia(DateTime fecha, double venta, double ganancia, {bool isSmall = false}) {
    bool esMesActual = fecha.month == _fechaActual.month;
    bool esHoy = fecha.day == DateTime.now().day && fecha.month == DateTime.now().month && fecha.year == DateTime.now().year;

    BoxDecoration decoration;
    if (esHoy) {
      decoration = BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange, width: isSmall ? 1 : 2)
      );
    } else if (venta > 0) {
      decoration = BoxDecoration(
          color: esMesActual ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: esMesActual ? Colors.grey.shade300 : Colors.grey.shade200)
      );
    } else {
      decoration = BoxDecoration(
          color: esMesActual ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: esMesActual ? Colors.grey.shade100 : Colors.transparent)
      );
    }

    return Opacity(
      opacity: esMesActual ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: decoration,
        child: InkWell(
          onTap: () => _abrirDetalleDia(fecha),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                    fecha.day.toString(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 12 : 14,
                        color: esHoy ? Colors.orange[900] : (esMesActual ? Colors.grey[700] : Colors.grey[400])
                    )
                ),
                if (venta > 0) ...[
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Center(
                      child: Text(Formatters.formatearMonedaCompacta(venta),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: isSmall ? 16 : 22, color: Colors.black87)),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Center(
                      child: Text("+${Formatters.formatearMonedaCompacta(ganancia)}",
                          style: TextStyle(fontSize: isSmall ? 12 : 15, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Icon(Icons.visibility, size: isSmall ? 10 : 14, color: Colors.grey[400]),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirDetalleDia(DateTime fecha, {int initialTab = 0, String? highlightFolio}) async {
    String fechaYmd = DateFormat('yyyy-MM-dd').format(fecha);
    List<Map<String, dynamic>> tickets = await HistoryDB.instance.obtenerVentasPorDia(fechaYmd);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _DetalleDiaDialogContent(
        fecha: fecha,
        tickets: tickets,
        initialTab: initialTab,
        highlightFolio: highlightFolio,
        onFactura: _abrirFacturaDesdeHistorial,
        onReimprimir: _reimprimir,
        onDevolucion: _mostrarDialogoDevolucion,
        buildResumenProductos: _buildResumenProductos,
        buildListaTickets: _buildListaTickets,
        infoBox: _infoBox,
      ),
    );
  }

  void _mostrarResumenMensual() async {
    setState(() => _cargando = true);
    final db = await AppDatabase.instance.database;
    final mesStr = _fechaActual.month.toString().padLeft(2, '0');
    final anioStr = _fechaActual.year.toString();

    final tickets = await db.query('ventas_historial',
        where: "fecha LIKE ? AND es_activo = 1",
        whereArgs: ['$anioStr-$mesStr%'],
        orderBy: 'fecha DESC');

    double tVenta = 0, tCosto = 0;
    for (var t in tickets) {
      tVenta += (t['total'] as num).toDouble();
      tCosto += (t['costo_total'] as num).toDouble();
    }

    if (!mounted) return;
    setState(() => _cargando = false);

    showDialog(
        context: context,
        builder: (ctx) => LayoutBuilder(
            builder: (context, constraints) {
              // Lógica de móvil comentada para priorizar vista de Tablet/Escritorio
              // bool isMobile = constraints.maxWidth < 700;
              bool isMobile = false;
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: SizedBox(
                  width: 1000, height: 800,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colores.azulPrincipal, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("Resumen - ${DateFormat('MMMM yyyy').format(_fechaActual).toUpperCase()}", style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 20), overflow: TextOverflow.ellipsis)),
                            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))
                          ],
                        ),
                      ),
                      Expanded(child: _buildResumenProductos(tickets)),
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[100],
                        child: isMobile
                            ? Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _infoBox("COSTO TOTAL", tCosto, Colors.red, isMobile),
                              _infoBox("VENTA TOTAL", tVenta, Colors.black, isMobile),
                            ]),
                            const Divider(),
                            _infoBox("GANANCIA TOTAL", tVenta - tCosto, Colors.green, isMobile),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _infoBox("COSTO TOTAL", tCosto, Colors.red),
                            const SizedBox(width: 30),
                            _infoBox("VENTA TOTAL", tVenta, Colors.black),
                            const SizedBox(width: 30),
                            const VerticalDivider(),
                            _infoBox("GANANCIA TOTAL", tVenta - tCosto, Colors.green),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
        )
    );
  }

  void _mostrarBuscadorFolio() {
    showDialog(
      context: context,
      builder: (ctx) => _BuscadorFolioDialog(
        onSearch: (v) => _ejecutarBusquedaFolio(v, ctx),
      ),
    );
  }

  Future<void> _ejecutarBusquedaFolio(String query, BuildContext dialogCtx) async {
    String cleanQuery = query.trim().toUpperCase();
    if (cleanQuery.isEmpty) return;

    final venta = await HistoryDB.instance.buscarVentaPorFolio(cleanQuery);

    if (!mounted) return;

    if (venta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Folio no encontrado"), backgroundColor: Colors.red),
      );
      return;
    }

    // Si lo encontró, cerramos el buscador
    if (dialogCtx.mounted) {
      Navigator.pop(dialogCtx);
    }

    // Parsear fecha de la venta (YYYY-MM-DD ...)
    DateTime fechaVenta = DateTime.parse(venta['fecha']);

    // 1. Navegar al mes si es distinto
    if (fechaVenta.year != _fechaActual.year || fechaVenta.month != _fechaActual.month) {
      await _cargarDatosMes(DateTime(fechaVenta.year, fechaVenta.month, 1));
      // Actualizamos _fechaActual manualmente por si el setState no ha terminado
      if (mounted) {
        setState(() {
          _fechaActual = DateTime(fechaVenta.year, fechaVenta.month, 1);
        });
      }
    }

    // 2. Abrir detalle del día en la pestaña de tickets (index 1)
    if (mounted) {
      _abrirDetalleDia(fechaVenta, initialTab: 1, highlightFolio: cleanQuery);
    }
  }

  Widget _infoBox(String titulo, double valor, Color color, [bool small = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(titulo, style: TextStyle(fontSize: small ? 9 : 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(Formatters.formatearMoneda(valor), style: TextStyle(fontSize: small ? 18 : 22, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // --- BITÁCORA DE TICKETS ---
  Widget _buildListaTickets(List<Map<String, dynamic>> tickets, bool isMobile, {ScrollController? scrollCtrl, String? highlightFolio}) {
    if (tickets.isEmpty) return const Center(child: Text("No hay ventas registradas"));
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(10),
      separatorBuilder: (c, i) => const Divider(),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final String folioActual = (t['folio_venta'] ?? t['id']).toString();
        final bool isHighlighted = highlightFolio != null && folioActual == highlightFolio;
        
        final hora = t['fecha'].toString().split(' ')[1].substring(0, 5);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: HistoryDB.instance.obtenerDetallesVenta(t['id']),
          builder: (context, snapshot) {
            List<Widget> itemWidgets = [];
            
            if (t['cliente'].toString().startsWith('Abono a deuda de:')) {
              itemWidgets = [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(t['cliente'], style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ];
            } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final detalles = snapshot.data!;
              itemWidgets = detalles.take(isMobile ? 3 : 100).map((d) {
                bool esDevuelto = d['estado'] == 'devuelto';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Text("${d['cantidad']}x ${d['descripcion']}", 
                        style: TextStyle(
                          fontSize: 12,
                          decoration: esDevuelto ? TextDecoration.lineThrough : null,
                          color: esDevuelto ? Colors.red[300] : Colors.black87
                        ), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      if (esDevuelto) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red[200]!)),
                          child: const Text("DEVUELTO", style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                        )
                      ]
                    ],
                  ),
                );
              }).toList();
              if (isMobile && detalles.length > 3) {
                itemWidgets.add(Text("... y ${detalles.length - 3} más", style: const TextStyle(fontSize: 10, color: Colors.grey)));
              }
            } else {
              // Fallback para ventas viejas
              final itemsParseados = modelo.ItemVenta.listaDesdeString(t['items'] ?? "");
              itemWidgets = itemsParseados.take(isMobile ? 2 : 100).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text("${item.cantidad}x ${item.descripcion}", style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList();
              if (isMobile && itemsParseados.length > 2) {
                itemWidgets.add(Text("... y ${itemsParseados.length - 2} más", style: const TextStyle(fontSize: 10, color: Colors.grey)));
              }
            }

            return Container(
              decoration: isHighlighted ? BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(8)
              ) : null,
              child: ListTile(
                leading: isMobile ? null : const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.receipt, color: Colors.white)),
                title: Text("Folio #$folioActual • $hora hrs", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: itemWidgets),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Formatters.formatearMoneda(t['total'] ?? 0.0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.description, color: Colores.azulPrincipal, size: 20),
                      onPressed: () => _abrirFacturaDesdeHistorial(t),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, size: 20),
                      onPressed: () => _reimprimir(t),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.assignment_return, color: Colors.red, size: 20),
                      onPressed: () => _mostrarDialogoDevolucion(t),
                      visualDensity: VisualDensity.compact,
                      tooltip: "Devolución",
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- RESUMEN DE PRODUCTOS ---
  Widget _buildResumenProductos(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) return const Center(child: Text("Sin datos"));

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _obtenerListaConsolidada(tickets),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colores.azulPrincipal));
        }
        
        if (snapshot.hasError) {
          return Center(child: Text("Error al cargar resumen: ${snapshot.error}"));
        }

        final lista = snapshot.data ?? [];
        if (lista.isEmpty) return const Center(child: Text("Sin datos"));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: lista.length,
          itemBuilder: (ctx, i) {
            final item = lista[i];

            if (item['es_abono'] == true) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.payments, color: Colors.white)
                  ),
                  title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("INGRESO POR ABONO: ${Formatters.formatearMoneda(item['bruto'])}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                ),
              );
            }

            return FutureBuilder<Map<String, dynamic>?>(
              future: _buscarProductoLive(item['nombre'], item['sku_historico']),
              builder: (context, snap) {

                String stock = "...";
                String skuFinal = item['sku_historico'];
                double costoFinal = 0.0;
                double precioPublico = 0.0;

                if (snap.hasData && snap.data != null) {
                  final prodDB = snap.data!;
                  stock = prodDB['stock'].toString();
                  precioPublico = (prodDB['precio'] as num).toDouble();

                  if (skuFinal.isEmpty || skuFinal == "N/A") {
                    skuFinal = prodDB['sku'] ?? prodDB['codigo'] ?? "N/A";
                  }

                  if ((item['costo_acumulado'] as double) > 0) {
                    costoFinal = item['costo_acumulado'];
                  } else {
                    double costoUnitarioReal = (prodDB['costo'] as num).toDouble();
                    costoFinal = costoUnitarioReal * (item['cant'] as int);
                  }
                } else {
                  costoFinal = item['costo_acumulado'];
                }

                double ventaFinal = (item['bruto'] as double);
                if (ventaFinal == 0 && precioPublico > 0) {
                  ventaFinal = precioPublico * (item['cant'] as int);
                }

                double ganancia = ventaFinal - costoFinal;
                int cantDev = item['cant_devuelta'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Colores.azulPrincipal,
                        child: Text("${item['cant']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ),
                    title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _tag("SKU: $skuFinal", Colors.blue),
                            const SizedBox(width: 10),
                            _tag("AÚN QUEDAN: $stock", int.tryParse(stock) != null && int.parse(stock) < 5 ? Colors.red : Colors.orange),
                            if (cantDev > 0) ...[
                              const SizedBox(width: 10),
                              _tag("DEVUELTOS: $cantDev", Colors.red),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _miniDato("COSTO", costoFinal, Colors.red),
                              _miniDato("VENTA", ventaFinal, Colors.black),
                              _miniDato("GANANCIA", ganancia, Colors.green),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _obtenerListaConsolidada(List<Map<String, dynamic>> tickets) async {
    Map<String, dynamic> consolidado = {};
    Map<String, dynamic> abonos = {};

    for (var t in tickets) {
      if (t['cliente'].toString().startsWith('Abono a deuda de:')) {
        String concepto = t['cliente'];
        if (abonos.containsKey(concepto)) {
          abonos[concepto]['bruto'] += (t['total'] as num).toDouble();
        } else {
          abonos[concepto] = {
            'nombre': concepto,
            'bruto': (t['total'] as num).toDouble(),
            'es_abono': true
          };
        }
        continue;
      }

      // Cargar detalles reales para incluir devoluciones con etiqueta
      final detalles = await HistoryDB.instance.obtenerDetallesVenta(t['id']);
      
      if (detalles.isNotEmpty) {
        for (var d in detalles) {
          String key = "${d['descripcion']}_${d['sku']}";
          bool esDevuelto = d['estado'] == 'devuelto';

          if (consolidado.containsKey(key)) {
            consolidado[key]['cant'] += d['cantidad'];
            if (!esDevuelto) {
              consolidado[key]['bruto'] += (d['precio'] * d['cantidad']);
              consolidado[key]['costo_acumulado'] += (d['costo'] * d['cantidad']);
            } else {
              consolidado[key]['cant_devuelta'] = (consolidado[key]['cant_devuelta'] ?? 0) + d['cantidad'];
            }
          } else {
            consolidado[key] = {
              'nombre': d['descripcion'],
              'sku_historico': d['sku'],
              'cant': d['cantidad'],
              'cant_devuelta': esDevuelto ? d['cantidad'] : 0,
              'bruto': esDevuelto ? 0.0 : (d['precio'] * d['cantidad']),
              'costo_acumulado': esDevuelto ? 0.0 : (d['costo'] * d['cantidad'])
            };
          }
        }
      } else {
        // Fallback para ventas antiguas sin tabla de detalles
        final itemsParseados = modelo.ItemVenta.listaDesdeString(t['items'] ?? "");
        for (var item in itemsParseados) {
          String key = "${item.descripcion}_${item.sku}";
          if (consolidado.containsKey(key)) {
            consolidado[key]['cant'] += item.cantidad;
            consolidado[key]['bruto'] += (item.precio * item.cantidad);
            consolidado[key]['costo_acumulado'] += (item.costo * item.cantidad);
          } else {
            consolidado[key] = {
              'nombre': item.descripcion,
              'sku_historico': item.sku,
              'cant': item.cantidad,
              'bruto': (item.precio * item.cantidad),
              'costo_acumulado': (item.costo * item.cantidad)
            };
          }
        }
      }
    }

    final List<Map<String, dynamic>> lista = [
      ...consolidado.values.map((e) => Map<String, dynamic>.from(e)),
      ...abonos.values.map((e) => Map<String, dynamic>.from(e)),
    ];
    lista.sort((a, b) => (b['bruto'] as num).compareTo(a['bruto'] as num));
    return lista;
  }

  Future<Map<String, dynamic>?> _buscarProductoLive(String nombre, String? sku) async {
    if (sku != null && sku.isNotEmpty && sku != "N/A") {
      var res = await DBHelper.instance.getProductoPorCodigo(sku);
      if (res != null) return res;
    }
    var resultados = await DBHelper.instance.buscarProductos(nombre);
    if (resultados.isNotEmpty) {
      return resultados.first;
    }
    return null;
  }

  Widget _tag(String txt, MaterialColor col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: col[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: col.shade200)),
    child: Text(txt, style: TextStyle(fontSize: 10, color: col[900], fontWeight: FontWeight.bold)),
  );

  Widget _miniDato(String lab, double val, Color col) => Padding(
    padding: const EdgeInsets.only(right: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lab, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(Formatters.formatearMoneda(val), style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    ),
  );
}

class _BuscadorFolioDialog extends StatefulWidget {
  final Function(String) onSearch;
  const _BuscadorFolioDialog({Key? key, required this.onSearch}) : super(key: key);

  @override
  State<_BuscadorFolioDialog> createState() => _BuscadorFolioDialogState();
}

class _BuscadorFolioDialogState extends State<_BuscadorFolioDialog> {
  late TextEditingController _folioCtrl;

  @override
  void initState() {
    super.initState();
    _folioCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Ingresa el Folio de Ticket"),
      content: TextField(
        controller: _folioCtrl,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: "Número de Folio",
          hintText: "Ej. 217 o 217M",
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => widget.onSearch(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () => widget.onSearch(_folioCtrl.text),
          child: const Text("Buscar"),
        ),
      ],
    );
  }
}

class _DetalleDiaDialogContent extends StatefulWidget {
  final DateTime fecha;
  final List<Map<String, dynamic>> tickets;
  final int initialTab;
  final String? highlightFolio;
  final Function(Map<String, dynamic>) onFactura;
  final Function(Map<String, dynamic>) onReimprimir;
  final Function(Map<String, dynamic>) onDevolucion;
  final Widget Function(List<Map<String, dynamic>>) buildResumenProductos;
  final Widget Function(List<Map<String, dynamic>>, bool, {ScrollController? scrollCtrl, String? highlightFolio}) buildListaTickets;
  final Widget Function(String, double, Color, [bool]) infoBox;

  const _DetalleDiaDialogContent({
    required this.fecha,
    required this.tickets,
    required this.initialTab,
    this.highlightFolio,
    required this.onFactura,
    required this.onReimprimir,
    required this.onDevolucion,
    required this.buildResumenProductos,
    required this.buildListaTickets,
    required this.infoBox,
  });

  @override
  State<_DetalleDiaDialogContent> createState() => _DetalleDiaDialogContentState();
}

class _DetalleDiaDialogContentState extends State<_DetalleDiaDialogContent> {
  late ScrollController _ticketScrollCtrl;

  @override
  void initState() {
    super.initState();
    _ticketScrollCtrl = ScrollController();
    if (widget.highlightFolio != null) {
      _autoScroll();
    }
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      int index = widget.tickets.indexWhere((t) => (t['folio_venta'] ?? t['id']).toString() == widget.highlightFolio);
      if (index != -1) {
        double offset = index * 73.0;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _ticketScrollCtrl.hasClients) {
            _ticketScrollCtrl.animateTo(
              offset,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuart,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ticketScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double tVenta = 0, tCosto = 0;
    for (var t in widget.tickets) {
      tVenta += (t['total'] ?? 0.0);
      tCosto += (t['costo_total'] ?? 0.0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = false; // Priorizamos vista Desktop
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: SizedBox(
            width: 1000, height: 800,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colores.grisOscuro,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Desglose del ${DateFormat('dd MMMM yyyy').format(widget.fecha)}",
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 20),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    initialIndex: widget.initialTab,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: Colors.black,
                          indicatorColor: Colores.azulPrincipal,
                          tabs: [
                            Tab(icon: const Icon(Icons.inventory), text: isMobile ? "Prods" : "Productos Vendidos"),
                            Tab(icon: const Icon(Icons.receipt), text: isMobile ? "Tickets" : "Reimpresión de Tickets"),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              widget.buildResumenProductos(widget.tickets),
                              widget.buildListaTickets(
                                widget.tickets,
                                isMobile,
                                scrollCtrl: _ticketScrollCtrl,
                                highlightFolio: widget.highlightFolio,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      widget.infoBox("COSTO", tCosto, Colors.red),
                      const SizedBox(width: 30),
                      widget.infoBox("LIQUIDEZ", tVenta, Colors.black),
                      const SizedBox(width: 30),
                      const VerticalDivider(),
                      widget.infoBox("GANANCIA", tVenta - tCosto, Colors.green),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

