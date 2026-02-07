import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'databases/history_db.dart';
import 'constants/colores.dart';
import 'Utils/impresion_ticket.dart';
import 'models/producto.dart';
import 'venta.dart'; // Para ItemVenta

class CalendarioVentas extends StatefulWidget {
  const CalendarioVentas({Key? key}) : super(key: key);

  @override
  State<CalendarioVentas> createState() => _CalendarioVentasState();
}

class _CalendarioVentasState extends State<CalendarioVentas> {
  DateTime _fechaActual = DateTime.now();
  Map<int, Map<String, double>> _datosDias = {};
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

    final ventas = await HistoryDB.instance.obtenerVentasPorMes(fecha.month, fecha.year);

    Map<int, Map<String, double>> temp = {};
    double maxVenta = 0;
    int diaMejor = 0;

    for (var v in ventas) {
      String fechaStr = v['fecha_dia'];
      int dia = int.parse(fechaStr.split('-')[2]);
      double total = v['total_venta'] ?? 0.0;
      double costo = v['total_costo'] ?? 0.0;

      temp[dia] = {
        'venta': total,
        'costo': costo,
        'ganancia': total - costo
      };

      if (total > maxVenta) {
        maxVenta = total;
        diaMejor = dia;
      }
    }

    setState(() {
      _datosDias = temp;
      _mejorProductoMes = maxVenta > 0 ? "Día récord: $diaMejor" : "Sin ventas";
      _datoDestacado = "\$${maxVenta.toStringAsFixed(2)}";
      _fechaActual = fecha;
      _cargando = false;
    });
  }

  void _cambiarMes(int delta) {
    DateTime nueva = DateTime(_fechaActual.year, _fechaActual.month + delta, 1);
    _cargarDatosMes(nueva);
  }

  // --- REIMPRIMIR ---
  Future<void> _reimprimir(Map<String, dynamic> ticketData) async {
    try {
      double total = (ticketData['total'] is int) ? (ticketData['total'] as int).toDouble() : ticketData['total'];
      double recibido = ticketData['recibido'] != null
          ? ((ticketData['recibido'] is int) ? (ticketData['recibido'] as int).toDouble() : ticketData['recibido'])
          : total;
      double cambio = ticketData['cambio'] != null
          ? ((ticketData['cambio'] is int) ? (ticketData['cambio'] as int).toDouble() : ticketData['cambio'])
          : 0.0;

      int folio = ticketData['folio'] ?? ticketData['id'] ?? 0;
      String itemsString = ticketData['items'] ?? "";

      List<ItemVenta> itemsReconstruidos = [];
      List<String> lineas = itemsString.split('|');

      for (String linea in lineas) {
        if (linea.trim().isEmpty) continue;

        int cantidad = 1;
        final cantMatch = RegExp(r'^(\d+)x').firstMatch(linea.trim());
        if (cantMatch != null) cantidad = int.tryParse(cantMatch.group(1)!) ?? 1;

        double precio = 0.0;
        final precioMatch = RegExp(r'\[P:(.*?)\]').firstMatch(linea);
        if (precioMatch != null) {
          String pStr = precioMatch.group(1)!.replaceAll(RegExp(r'[^0-9.]'), '');
          precio = double.tryParse(pStr) ?? 0.0;
        }

        String sku = "";
        final skuMatch = RegExp(r'\[SKU:(.*?)\]').firstMatch(linea);
        if (skuMatch != null) sku = skuMatch.group(1) ?? "";

        String descripcion = linea
            .replaceAll(RegExp(r'^\d+x'), '')
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .trim();

        Producto pDummy = Producto(
            id: 0, codigo: "HIST", sku: sku, factura: "", descripcion: descripcion, marca: "",
            stock: 0, costo: 0, precio: precio, precioRappi: 0, borrado: false
        );

        itemsReconstruidos.add(ItemVenta(producto: pDummy, cantidad: cantidad));
      }

      await ImpresionTicket.imprimirTicket(
          items: itemsReconstruidos,
          total: total,
          recibido: recibido,
          cambio: cambio,
          folioVenta: folio
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket enviado a la impresora")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // HEADER
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.blue), onPressed: () => _cambiarMes(-1)),
              Text(
                  DateFormat('MMMM yyyy', 'es_MX').format(_fechaActual).toUpperCase(),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colores.azulPrincipal)
              ),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue), onPressed: () => _cambiarMes(1)),
              const SizedBox(width: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.today),
                label: const Text("Ir a Hoy"),
                onPressed: () {
                  if (_fechaActual.month != DateTime.now().month) {
                    _cargarDatosMes(DateTime.now());
                  }
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.orange),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_mejorProductoMes, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(_datoDestacado, style: TextStyle(color: Colors.grey[800], fontSize: 12)),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),

        // DÍAS SEMANA
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'TOTAL'].map((d) => Expanded(
                flex: d == 'TOTAL' ? 2 : 1,
                child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])))
            )).toList(),
          ),
        ),

        // GRID CALENDARIO
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _buildCalendarioGrid(),
        ),
      ],
    );
  }

  Widget _buildCalendarioGrid() {
    int year = _fechaActual.year;
    int month = _fechaActual.month;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    int firstWeekday = DateTime(year, month, 1).weekday;
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    List<Widget> filas = [];
    List<Widget> celdasFila = [];

    for (int i = 0; i < offset; i++) {
      celdasFila.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey[100]!)))));
    }

    double semVenta = 0, semGan = 0;

    for (int dia = 1; dia <= daysInMonth; dia++) {
      double v = _datosDias[dia]?['venta'] ?? 0;
      double g = _datosDias[dia]?['ganancia'] ?? 0;
      semVenta += v;
      semGan += g;

      celdasFila.add(Expanded(child: _buildCeldaDia(dia, v, g)));

      if ((dia + offset) % 7 == 0 || dia == daysInMonth) {
        while (celdasFila.length < 7) {
          celdasFila.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey[100]!)))));
        }

        celdasFila.add(Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("\$${semVenta.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Text("G: \$${semGan.toStringAsFixed(0)}", style: TextStyle(fontSize: 11, color: Colors.green[800])),
              ],
            ),
          ),
        ));

        filas.add(Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: celdasFila)));
        celdasFila = [];
        semVenta = 0; semGan = 0;
      }
    }

    return Column(children: filas);
  }

  Widget _buildCeldaDia(int dia, double venta, double ganancia) {
    bool esHoy = dia == DateTime.now().day && _fechaActual.month == DateTime.now().month && _fechaActual.year == DateTime.now().year;
    bool tieneVenta = venta > 0;

    return Card(
      color: esHoy ? Colors.amber[50] : Colors.white,
      elevation: tieneVenta ? 2 : 0,
      margin: const EdgeInsets.all(2),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: esHoy ? Colors.orange : Colors.grey.shade200)
      ),
      child: InkWell(
        onTap: () => _abrirDetalleDia(dia),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dia.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: esHoy ? Colors.orange[800] : Colors.black)),
              if (tieneVenta) ...[
                const Spacer(),
                Center(child: Text("\$${venta.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Center(child: Text("+\$${ganancia.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, color: Colors.green))),
                const Spacer(),
                Align(alignment: Alignment.center, child: Icon(Icons.visibility, size: 16, color: Colors.blue[300]))
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _abrirDetalleDia(int dia) async {
    String fechaYmd = "${_fechaActual.year}-${_fechaActual.month.toString().padLeft(2,'0')}-${dia.toString().padLeft(2,'0')}";
    List<Map<String, dynamic>> tickets = await HistoryDB.instance.obtenerVentasPorDia(fechaYmd);

    double tVenta = 0, tCosto = 0;
    for (var t in tickets) {
      tVenta += (t['total'] ?? 0.0);
      tCosto += (t['costo_total'] ?? 0.0);
    }

    showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: 900,
            height: 700,
            child: Column(
              children: [
                // HEADER GRIS OSCURO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colores.grisOscuro, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Detalle del $dia de ${DateFormat('MMMM').format(_fechaActual)}", style: const TextStyle(color: Colors.white, fontSize: 20)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))
                    ],
                  ),
                ),

                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colores.azulPrincipal,
                          tabs: [
                            Tab(icon: Icon(Icons.inventory), text: "Resumen Productos"),
                            Tab(icon: Icon(Icons.receipt), text: "Bitácora de Tickets"),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildResumenProductos(tickets),
                              _buildListaTickets(tickets),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // FOOTER TOTALES (Aquí estaba el error de _infoBox)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _infoBox("COSTO", tCosto, Colors.red),
                      const SizedBox(width: 20),
                      _infoBox("VENTA TOTAL", tVenta, Colors.black),
                      const SizedBox(width: 20),
                      Container(width: 2, height: 30, color: Colors.grey),
                      const SizedBox(width: 20),
                      _infoBox("GANANCIA", tVenta - tCosto, Colors.green),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
    );
  }

  // --- FUNCIÓN RECUPERADA PARA ELIMINAR EL ERROR ROJO ---
  Widget _infoBox(String titulo, double valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text("\$${valor.toStringAsFixed(2)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // --- BITÁCORA LIMPIA Y MINIMALISTA (CON SKU VISIBLE) ---
  Widget _buildListaTickets(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) return const Center(child: Text("Sin movimientos."));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      separatorBuilder: (c,i) => const Divider(),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final folioReal = t['folio'] ?? t['id'] ?? 'S/N';
        final hora = t['fecha'].toString().split(' ')[1].substring(0,5);

        // Parsear items para mostrar SKU
        String rawItems = t['items'].toString();
        List<String> itemsList = rawItems.split('|');
        List<Widget> itemWidgets = [];

        for(String item in itemsList) {
          if(item.isEmpty) continue;
          String sku = "";
          // Extraer SKU del texto guardado
          final skuMatch = RegExp(r'\[SKU:(.*?)\]').firstMatch(item);
          if (skuMatch != null) sku = skuMatch.group(1) ?? "";

          // Limpiar nombre quitando etiquetas [..]
          String nombre = item.replaceAll(RegExp(r'\[.*?\]'), '').trim();

          itemWidgets.add(
              RichText(
                  text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        const TextSpan(text: "• "),
                        TextSpan(text: nombre),
                        // SKU VISIBLE AQUÍ
                        if(sku.isNotEmpty)
                          TextSpan(text: "  [SKU:$sku]", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ]
                  )
              )
          );
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colores.azulCielo.withOpacity(0.1),
            child: Icon(Icons.receipt_long, color: Colores.azulCielo),
          ),
          title: Text("Folio #$folioReal  •  $hora hrs", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              ...itemWidgets
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("\$${t['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 15),
              IconButton(
                icon: const Icon(Icons.print, color: Colors.grey),
                onPressed: () => _reimprimir(t),
                tooltip: "Reimprimir",
              )
            ],
          ),
        );
      },
    );
  }

  // --- RESUMEN DE PRODUCTOS (Consolidado) ---
  Widget _buildResumenProductos(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) return const Center(child: Text("Sin productos vendidos."));

    Map<String, dynamic> consolidado = {};

    for (var t in tickets) {
      String raw = t['items'] ?? "";
      List<String> items = raw.split('|');

      for (String linea in items) {
        if (linea.trim().isEmpty) continue;

        int cantidad = 1;
        final cantMatch = RegExp(r'^(\d+)x').firstMatch(linea.trim());
        if (cantMatch != null) cantidad = int.tryParse(cantMatch.group(1)!) ?? 1;

        double precioUnitario = 0.0;
        final precioMatch = RegExp(r'\[P:(.*?)\]').firstMatch(linea);
        if (precioMatch != null) {
          String cleanPrice = precioMatch.group(1)!.replaceAll(RegExp(r'[^0-9.]'), '');
          precioUnitario = double.tryParse(cleanPrice) ?? 0.0;
        }

        String sku = "";
        final skuMatch = RegExp(r'\[SKU:(.*?)\]').firstMatch(linea);
        if (skuMatch != null) sku = skuMatch.group(1) ?? "";

        String nombre = linea
            .replaceAll(RegExp(r'^\d+x'), '')
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .trim();

        String key = "$nombre-$sku";

        if (consolidado.containsKey(key)) {
          consolidado[key]['cantidad'] += cantidad;
          consolidado[key]['total'] += (precioUnitario * cantidad);
        } else {
          consolidado[key] = {
            'nombre': nombre,
            'sku': sku,
            'cantidad': cantidad,
            'total': (precioUnitario * cantidad)
          };
        }
      }
    }

    List<dynamic> listaConsolidada = consolidado.values.toList();
    listaConsolidada.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      separatorBuilder: (c, i) => const Divider(),
      itemCount: listaConsolidada.length,
      itemBuilder: (ctx, i) {
        final p = listaConsolidada[i];
        return ListTile(
          leading: Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Text("${p['cantidad']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
          ),
          title: Text(p['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: p['sku'].isNotEmpty
              ? Text("SKU: ${p['sku']}", style: TextStyle(color: Colors.grey[600], fontSize: 12))
              : null,
          trailing: Text("\$${p['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        );
      },
    );
  }
}