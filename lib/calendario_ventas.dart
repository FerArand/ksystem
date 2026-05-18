import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'databases/history_db.dart';
import 'db_helper.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'models/producto.dart';
import 'models/pedido.dart';
import 'venta.dart';
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
  String _topProductoNombre = "---";
  int _topProductoCant = 0;

  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosMes(_fechaActual);
  }

  Future<void> _cargarDatosMes(DateTime fecha) async {
    setState(() { _cargando = true; _datosDias.clear(); _topProductoNombre = "---"; });

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

    // 3. OBTENER PRODUCTO TOP DEL MES
    final db = await AppDatabase.instance.database;
    final mesStr = fecha.month.toString().padLeft(2, '0');
    final anioStr = fecha.year.toString();

    final rawTickets = await db.query('ventas_historial',
        columns: ['items'],
        where: "fecha LIKE ? AND es_activo = 1",
        whereArgs: ['$anioStr-$mesStr%']);

    Map<String, int> conteoProductos = {};
    for (var t in rawTickets) {
      String itemsStr = t['items'] as String? ?? "";
      final listaItems = modelo.ItemVenta.listaDesdeString(itemsStr);

      for (var item in listaItems) {
        if (conteoProductos.containsKey(item.descripcion)) {
          conteoProductos[item.descripcion] = conteoProductos[item.descripcion]! + item.cantidad;
        } else {
          conteoProductos[item.descripcion] = item.cantidad;
        }
      }
    }

    String nombreTop = "Sin datos";
    int cantTop = 0;
    if (conteoProductos.isNotEmpty) {
      var sortedKeys = conteoProductos.keys.toList(growable: false)
        ..sort((k1, k2) => conteoProductos[k2]!.compareTo(conteoProductos[k1]!));
      if (sortedKeys.isNotEmpty) {
        nombreTop = sortedKeys.first;
        cantTop = conteoProductos[nombreTop]!;
      }
    }

    if (!mounted) return;

    setState(() {
      _datosDias = temp;
      _mejorProductoMes = maxVenta > 0 ? "Día récord: $diaMejor" : "Sin ventas";
      _datoDestacado = Formatters.formatearMoneda(maxVenta);
      _topProductoNombre = nombreTop;
      _topProductoCant = cantTop;
      _fechaActual = fecha;
      _totalDiasGrid = calculoGrid;
      _cargando = false;
    });
  }

  void _cambiarMes(int delta) {
    DateTime nueva = DateTime(_fechaActual.year, _fechaActual.month + delta, 1);
    _cargarDatosMes(nueva);
  }

  Future<void> _reimprimir(Map<String, dynamic> ticketData) async {
    try {
      final String cliente = ticketData['cliente']?.toString() ?? "";

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

      final itemsReconstruidos = _reconstruirItems(ticketData);
      double total = (ticketData['total'] is int) ? (ticketData['total'] as int).toDouble() : ticketData['total'];
      double recibido = ticketData['recibido'] != null
          ? ((ticketData['recibido'] is int) ? (ticketData['recibido'] as int).toDouble() : ticketData['recibido'])
          : total;
      double cambio = ticketData['cambio'] != null
          ? ((ticketData['cambio'] is int) ? (ticketData['cambio'] as int).toDouble() : ticketData['cambio'])
          : 0.0;
      int folio = ticketData['folio_venta'] ?? ticketData['id'] ?? 0;
      String fechaOriginal = ticketData['fecha'] ?? "";

      await ImpresionTicket.imprimirTicket(
          items: itemsReconstruidos,
          total: total,
          recibido: recibido,
          cambio: cambio,
          folioVenta: folio,
          fechaOriginal: fechaOriginal,
          isCopy: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  List<ItemVenta> _reconstruirItems(Map<String, dynamic> ticketData) {
    String itemsString = ticketData['items'] ?? "";
    final itemsParseados = modelo.ItemVenta.listaDesdeString(itemsString);
    List<ItemVenta> itemsReconstruidos = [];

    for (var item in itemsParseados) {
      Producto pDummy = Producto(
          id: 0, codigo: "HIST", sku: item.sku, factura: "", ubicacion: "", descripcion: item.descripcion, marca: "",
          stock: 0, costo: item.costo, precio: item.precio, precioRappi: 0, borrado: false
      );
      itemsReconstruidos.add(ItemVenta(producto: pDummy, cantidad: item.cantidad));
    }
    return itemsReconstruidos;
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
      int folio = ticketData['folio_venta'] ?? ticketData['id'] ?? 0;
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

  void _abrirDetalleDia(DateTime fecha, {int initialTab = 0}) async {
    String fechaYmd = DateFormat('yyyy-MM-dd').format(fecha);
    List<Map<String, dynamic>> tickets = await HistoryDB.instance.obtenerVentasPorDia(fechaYmd);

    double tVenta = 0, tCosto = 0;
    for (var t in tickets) {
      tVenta += (t['total'] ?? 0.0);
      tCosto += (t['costo_total'] ?? 0.0);
    }

    if (!mounted) return;

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
                        decoration: const BoxDecoration(color: Colores.grisOscuro, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("Desglose del ${DateFormat('dd MMMM yyyy').format(fecha)}", style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 20), overflow: TextOverflow.ellipsis)),
                            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))
                          ],
                        ),
                      ),
                      Expanded(
                        child: DefaultTabController(
                          length: 2,
                          initialIndex: initialTab,
                          child: Column(
                            children: [
                              TabBar(
                                labelColor: Colors.black, indicatorColor: Colores.azulPrincipal,
                                tabs: [
                                  Tab(icon: const Icon(Icons.inventory), text: isMobile ? "Prods" : "Productos Vendidos"),
                                  Tab(icon: const Icon(Icons.receipt), text: isMobile ? "Tickets" : "Reimpresión de Tickets"),
                                ],
                              ),
                              Expanded(child: TabBarView(children: [_buildResumenProductos(tickets), _buildListaTickets(tickets, isMobile)])),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[100],
                        child: isMobile
                            ? Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _infoBox("COSTO", tCosto, Colors.red, isMobile),
                              const SizedBox(width: 20),
                              _infoBox("LIQUIDEZ", tVenta, Colors.black, isMobile),
                            ]),
                            const Divider(),
                            _infoBox("GANANCIA", tVenta - tCosto, Colors.green, isMobile),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _infoBox("COSTO", tCosto, Colors.red),
                            const SizedBox(width: 30),
                            _infoBox("LIQUIDEZ", tVenta, Colors.black),
                            const SizedBox(width: 30),
                            const VerticalDivider(),
                            _infoBox("GANANCIA", tVenta - tCosto, Colors.green),
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
    final TextEditingController folioCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ingresa el Folio de Ticket"),
        content: TextField(
          controller: folioCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Número de Folio",
            hintText: "Ej. 217",
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => _ejecutarBusquedaFolio(v, ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => _ejecutarBusquedaFolio(folioCtrl.text, ctx),
            child: const Text("Buscar"),
          ),
        ],
      ),
    ).then((_) => folioCtrl.dispose());
  }

  Future<void> _ejecutarBusquedaFolio(String query, BuildContext dialogCtx) async {
    int? folio = int.tryParse(query);
    if (folio == null) return;

    final venta = await HistoryDB.instance.buscarVentaPorFolio(folio);

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
      _abrirDetalleDia(fechaVenta, initialTab: 1);
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
  Widget _buildListaTickets(List<Map<String, dynamic>> tickets, [bool isMobile = false]) {
    if (tickets.isEmpty) return const Center(child: Text("No hay ventas registradas"));
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      separatorBuilder: (c, i) => const Divider(),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final hora = t['fecha'].toString().split(' ')[1].substring(0, 5);

        final itemsParseados = modelo.ItemVenta.listaDesdeString(t['items'] ?? "");

        List<Widget> itemWidgets;

        if (t['cliente'].toString().startsWith('Abono a deuda de:')) {
          itemWidgets = [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t['cliente'], style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ];
        } else {
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

        return ListTile(
          leading: isMobile ? null : const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.receipt, color: Colors.white)),
          title: Text("Folio #${t['folio_venta'] ?? t['id']} • $hora hrs", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
              )
            ],
          ),
        );
      },
    );
  }

  // --- RESUMEN DE PRODUCTOS ---
  Widget _buildResumenProductos(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) return const Center(child: Text("Sin datos"));

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

      final itemsParseados = modelo.ItemVenta.listaDesdeString(t['items'] ?? "");

      for (var item in itemsParseados) {
        String key = item.descripcion;

        if (consolidado.containsKey(key)) {
          consolidado[key]['cant'] += item.cantidad;
          consolidado[key]['bruto'] += (item.precio * item.cantidad);
          consolidado[key]['costo_acumulado'] = (consolidado[key]['costo_acumulado'] ?? 0.0) + (item.costo * item.cantidad);
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

    var lista = consolidado.values.toList()..addAll(abonos.values.toList());
    lista.sort((a, b) => b['bruto'].compareTo(a['bruto']));

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
