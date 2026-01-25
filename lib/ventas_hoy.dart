import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'databases/history_db.dart';
import 'constants/colores.dart';

class VentasHoy extends StatefulWidget {
  const VentasHoy({Key? key}) : super(key: key);

  @override
  State<VentasHoy> createState() => _VentasHoyState();
}

class _VentasHoyState extends State<VentasHoy> {
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;

  // Estadísticas
  double _totalVentaBruta = 0.0;
  double _totalCosto = 0.0;
  double _gananciaNeta = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarVentasDelDia();
  }

  Future<void> _cargarVentasDelDia() async {
    setState(() => _cargando = true);

    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final datos = await HistoryDB.instance.obtenerVentasDelDia(hoy);

    double tBruta = 0;
    double tCosto = 0;

    for (var v in datos) {
      tBruta += (v['total'] as num).toDouble();
      tCosto += (v['costo_total'] ?? 0.0) as double;
    }

    if (mounted) {
      setState(() {
        _ventas = datos;
        _totalVentaBruta = tBruta;
        _totalCosto = tCosto;
        _gananciaNeta = tBruta - tCosto;
        _cargando = false;
      });
    }
  }

  Future<void> _asignarNombre(int id, String nombreActual) async {
    TextEditingController _ctrl = TextEditingController(text: nombreActual == "Cliente General" ? "" : nombreActual);
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Asignar Cliente al Ticket"),
          content: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Nombre del Cliente", border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () async {
                  String nombre = _ctrl.text.trim().isEmpty ? "Cliente General" : _ctrl.text.trim();
                  await HistoryDB.instance.asignarNombreCliente(id, nombre);
                  _cargarVentasDelDia();
                  Navigator.pop(ctx);
                },
                child: const Text("GUARDAR")
            )
          ],
        )
    );
  }

  // --- NUEVO: FUNCIÓN PARA VER RECIBO DETALLADO ---
  void _verReciboDetalle(Map<String, dynamic> venta) {
    // Convertimos la cadena "3x Cemento | 1x Llana" en una lista
    String itemsRaw = venta['items'] ?? "";
    List<String> listaItems = itemsRaw.split('|');

    showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long, size: 50, color: Colors.blueGrey),
                const SizedBox(height: 10),
                Text("Ticket #${venta['folio_venta']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(venta['fecha'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Divider(thickness: 2),

                // LISTA DESGLOSADA
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: listaItems.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text("• ${listaItems[i].trim()}", style: const TextStyle(fontSize: 16)),
                      );
                    },
                  ),
                ),

                const Divider(thickness: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("\$${venta['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 5),
                Text("Cliente: ${venta['cliente']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("CERRAR"))
              ],
            ),
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- ENCABEZA ---
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.today, size: 30, color: Colors.blueGrey),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Corte de Caja (Ventas del Día)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  // Aseguramos que la fecha se muestre bien
                  Text(DateFormat('EEEE d, MMMM yyyy', 'es_MX').format(DateTime.now()), style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarVentasDelDia, tooltip: "Actualizar")
            ],
          ),
        ),
        const Divider(height: 1),

        // --- LISTA ---
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _ventas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[300]), const Text("Aún no hay ventas hoy.")]))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _ventas.length,
            itemBuilder: (context, index) {
              final v = _ventas[index];
              DateTime fechaDt = DateTime.parse(v['fecha']);
              String hora = DateFormat('hh:mm a').format(fechaDt);

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // IZQUIERDA: FOLIO
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("#${v['folio_venta']}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.grey[300])),
                                Text(hora, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // CENTRO: RESUMEN (VISTA PREVIA CON PIPES)
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Resumen:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                Text(
                                    v['items'].toString(), // Se muestra con pipes | como pediste
                                    style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis
                                ),
                                const SizedBox(height: 5),
                                // BOTÓN VER RECIBO
                                InkWell(
                                  onTap: () => _verReciboDetalle(v),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.visibility, size: 16, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text("Ver Recibo Completo", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          // DERECHA: TOTAL
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("\$${v['total'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                const Text("Pagado", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const Divider(),
                      // PIE DE TARJETA
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 5),
                          Text(v['cliente'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () => _asignarNombre(v['id'], v['cliente']),
                            child: const Icon(Icons.edit, size: 16, color: Colors.orange),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // --- BARRA TOTALES ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[900]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _infoCaja("COSTO", _totalCosto, Colors.red[200]!),
              const SizedBox(width: 20),
              _infoCaja("GANANCIA BRUTA", _totalVentaBruta, Colors.white),
              const SizedBox(width: 20),
              Container(width: 1, height: 40, color: Colors.grey[700]),
              const SizedBox(width: 20),
              _infoCaja("GANANCIA NETA", _gananciaNeta, Colors.greenAccent, esGrande: true),
            ],
          ),
        )
      ],
    );
  }

  Widget _infoCaja(String titulo, double valor, Color color, {bool esGrande = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(titulo, style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
        Text("\$${valor.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: esGrande ? 24 : 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}