import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'databases/history_db.dart';
import 'db_helper.dart'; // Importante para consultar el stock actual
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
          precio = double.tryParse(precioMatch.group(1)!.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        }

        String sku = "";
        final skuMatch = RegExp(r'\[SKU:(.*?)\]').firstMatch(linea);
        if (skuMatch != null) sku = skuMatch.group(1) ?? "";

        String descripcion = linea.replaceAll(RegExp(r'^\d+x'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();

        Producto pDummy = Producto(
            id: 0, codigo: "HIST", sku: sku, factura: "", descripcion: descripcion, marca: "",
            stock: 0, costo: 0, precio: precio, precioRappi: 0, borrado: false
        );
        itemsReconstruidos.add(ItemVenta(producto: pDummy, cantidad: cantidad));
      }

      await ImpresionTicket.imprimirTicket(items: itemsReconstruidos, total: total, recibido: recibido, cambio: cambio, folioVenta: folio);
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
              Text(DateFormat('MMMM yyyy', 'es_MX').format(_fechaActual).toUpperCase(),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colores.azulPrincipal)),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue), onPressed: () => _cambiarMes(1)),
              const SizedBox(width: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.today),
                label: const Text("Ir a Hoy"),
                onPressed: () => _cargarDatosMes(DateTime.now()),
              ),
              const Spacer(),
              _recordCard(),
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
        Expanded(child: _cargando ? const Center(child: CircularProgressIndicator()) : _buildCalendarioGrid()),
      ],
    );
  }

  Widget _recordCard() {
    return Container(
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
      semVenta += v; semGan += g;

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
        celdasFila = []; semVenta = 0; semGan = 0;
      }
    }
    return Column(children: filas);
  }

  Widget _buildCeldaDia(int dia, double venta, double ganancia) {
    bool esHoy = dia == DateTime.now().day && _fechaActual.month == DateTime.now().month && _fechaActual.year == DateTime.now().year;
    return Card(
      color: esHoy ? Colors.amber[50] : Colors.white,
      elevation: venta > 0 ? 2 : 0,
      margin: const EdgeInsets.all(2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: esHoy ? Colors.orange : Colors.grey.shade200)),
      child: InkWell(
        onTap: () => _abrirDetalleDia(dia),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dia.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: esHoy ? Colors.orange[800] : Colors.black)),
              if (venta > 0) ...[
                const Spacer(),
                Center(child: Text("\$${venta.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Center(child: Text("+\$${ganancia.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, color: Colors.green))),
                const Spacer(),
                const Align(alignment: Alignment.center, child: Icon(Icons.visibility, size: 14, color: Colors.blue))
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
                          labelColor: Colors.black, indicatorColor: Colores.azulPrincipal,
                          tabs: [
                            Tab(icon: Icon(Icons.inventory), text: "Resumen Productos (Lotes)"),
                            Tab(icon: Icon(Icons.receipt), text: "Bitácora de Tickets"),
                          ],
                        ),
                        Expanded(child: TabBarView(children: [_buildResumenProductos(tickets), _buildListaTickets(tickets)])),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _infoBox("COSTO TOTAL", tCosto, Colors.red),
                      const SizedBox(width: 30),
                      _infoBox("VENTA BRUTA", tVenta, Colors.black),
                      const SizedBox(width: 30),
                      const VerticalDivider(),
                      _infoBox("GANANCIA NETA", tVenta - tCosto, Colors.green),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
    );
  }

  Widget _infoBox(String titulo, double valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text("\$${valor.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // --- BITÁCORA DE TICKETS (CON SKU VISIBLE) ---
  Widget _buildListaTickets(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) return const Center(child: Text("Sin movimientos."));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      separatorBuilder: (c, i) => const Divider(),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final hora = t['fecha'].toString().split(' ')[1].substring(0, 5);
        List<String> itemsList = t['items'].toString().split('|');

        List<Widget> itemWidgets = itemsList.where((x) => x.isNotEmpty).map((item) {
          String sku = RegExp(r'\[SKU:(.*?)\]').firstMatch(item)?.group(1) ?? "N/A";
          String nombre = item.replaceAll(RegExp(r'\[.*?\]'), '').trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13), children: [
              const TextSpan(text: "• "),
              TextSpan(text: nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
              TextSpan(text: " [SKU: $sku]", style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold)),
            ])),
          );
        }).toList();

        return ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.receipt, color: Colors.white)),
          title: Text("Folio #${t['folio'] ?? t['id']}  •  $hora hrs", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 5), ...itemWidgets]),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("\$${t['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.print), onPressed: () => _reimprimir(t))
            ],
          ),
        );
      },
    );
  }

  // --- RESUMEN DE PRODUCTOS (Lotes, Finanzas y Stock Actual) ---
  Widget _buildResumenProductos(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) return const Center(child: Text("Sin ventas."));

    Map<String, dynamic> consolidado = {};
    for (var t in tickets) {
      for (String linea in (t['items'] ?? "").toString().split('|')) {
        if (linea.trim().isEmpty) continue;

        int cant = int.tryParse(RegExp(r'^(\d+)x').firstMatch(linea)?.group(1) ?? "1") ?? 1;
        double pUnit = double.tryParse(RegExp(r'\[P:(.*?)\]').firstMatch(linea)?.group(1)?.replaceAll(RegExp(r'[^0-9.]'), '') ?? "0") ?? 0;
        double cUnit = double.tryParse(RegExp(r'\[C:(.*?)\]').firstMatch(linea)?.group(1)?.replaceAll(RegExp(r'[^0-9.]'), '') ?? "0") ?? 0;
        String sku = RegExp(r'\[SKU:(.*?)\]').firstMatch(linea)?.group(1) ?? "";
        String nombre = linea.replaceAll(RegExp(r'^\d+x'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();

        String key = sku.isNotEmpty ? sku : nombre;
        if (consolidado.containsKey(key)) {
          consolidado[key]['cant'] += cant;
          consolidado[key]['bruto'] += (pUnit * cant);
          consolidado[key]['costo'] += (cUnit * cant);
        } else {
          consolidado[key] = {'nombre': nombre, 'sku': sku, 'cant': cant, 'bruto': (pUnit * cant), 'costo': (cUnit * cant)};
        }
      }
    }

    var lista = consolidado.values.toList()..sort((a, b) => b['bruto'].compareTo(a['bruto']));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: lista.length,
      itemBuilder: (ctx, i) {
        final item = lista[i];
        return FutureBuilder<Map<String, dynamic>?>(
          future: DBHelper.instance.getProductoPorCodigo(item['sku']),
          builder: (context, snap) {
            String stock = snap.hasData ? snap.data!['stock'].toString() : "...";
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Text("${item['cant']}")),
                title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _tag("SKU: ${item['sku']}", Colors.blue),
                        const SizedBox(width: 10),
                        _tag("STOCK ACTUAL: $stock", Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _miniDato("COSTO", item['costo'], Colors.red),
                        _miniDato("BRUTO", item['bruto'], Colors.black),
                        _miniDato("NETO", item['bruto'] - item['costo'], Colors.green),
                      ],
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

  Widget _tag(String txt, MaterialColor col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: col[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: col.shade100)),
    child: Text(txt, style: TextStyle(fontSize: 10, color: col[900], fontWeight: FontWeight.bold)),
  );

  Widget _miniDato(String lab, double val, Color col) => Padding(
    padding: const EdgeInsets.only(right: 15),
    child: RichText(text: TextSpan(style: const TextStyle(fontSize: 12), children: [
      TextSpan(text: "$lab: ", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      TextSpan(text: "\$${val.toStringAsFixed(2)}", style: TextStyle(color: col, fontWeight: FontWeight.bold)),
    ])),
  );
}