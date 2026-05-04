import 'package:flutter/material.dart';
import 'databases/debt_db.dart';
import 'models/item_venta.dart';

import 'databases/history_db.dart';
import 'Utils/impresion_ticket.dart';
import 'package:intl/intl.dart';

class Deudas extends StatefulWidget {
  const Deudas({Key? key}) : super(key: key);

  @override
  State<Deudas> createState() => _DeudasState();
}

class _DeudasState extends State<Deudas> {
  List<Map<String, dynamic>> _deudores = [];
  String _query = "";
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDeudores();
  }

  Future<void> _cargarDeudores() async {
    setState(() => _cargando = true);
    final datos = await DebtDB.instance.obtenerDeudores(_query);
    setState(() {
      _deudores = datos;
      _cargando = false;
    });
  }

  // Dialogo para ver detalle y abonar
  void _verDetalle(Map<String, dynamic> deudor) {
    String itemsRaw = deudor['items'] ?? "";
    // Parseamos directo a la lista de objetos
    final listaItems = ItemVenta.listaDesdeString(itemsRaw);
    final TextEditingController abonoCtrl = TextEditingController();

    showDialog(
        context: context,
        builder: (ctx) => LayoutBuilder(
          builder: (context, constraints) {
            bool isSmall = constraints.maxWidth < 650;
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cuenta de: ${deudor['nombre']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Fecha último fiado: ${deudor['fecha_ultimo_fiado'].toString().split('.')[0]}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const Text("Productos Pendientes:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.grey[50]
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemCount: listaItems.length,
                          itemBuilder: (c, i) {
                            final item = listaItems[i]; // Ya es un objeto real

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.circle, size: 6, color: Colors.red),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${item.cantidad}x ${item.descripcion}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            if (item.sku.isNotEmpty) _tag("SKU: ${item.sku}", Colors.blue),
                                            if (item.precio > 0) _tag("Total: \$${item.precio}", Colors.green),
                                            if (item.costo > 0) _tag("Mínimo aceptable: \$${item.costo}", Colors.grey),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("TOTAL ADEUDADO:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("\$${deudor['total_deuda'].toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: abonoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: "Monto a Pagar",
                            prefixText: "\$",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white
                        ),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cerrar")),
                if (!isSmall)
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text("TICKET DE DEUDA"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () {
                    ImpresionTicket.imprimirTicketAbono(
                      nombreDeudor: deudor['nombre'],
                      items: listaItems,
                      montoAbonado: 0, // Solo impresión de consulta
                      deudaAnterior: deudor['total_deuda'],
                      saldoRestante: deudor['total_deuda'],
                    );
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    double abono = double.tryParse(abonoCtrl.text) ?? 0;
                    if (abono > 0) {
                      final deudaPrevia = deudor['total_deuda'] as double;
                      final saldoRestante = deudaPrevia - abono;

                      // 1. Registrar abono en la base de datos de deudas
                      await DebtDB.instance.abonar(deudor['id'], abono);

                      // 2. Registrar el ingreso en el calendario (HistoryDB)
                      final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                      
                      // RECUPERAR ITEMS PARA EL HISTORIAL (Para que la reimpresión sea exacta)
                      String itemsDeuda = deudor['items'] ?? '[]';

                      await HistoryDB.instance.registrarVenta(
                        fecha: fecha,
                        total: abono,
                        costoTotal: 0, // No es venta de stock nuevo, es cobro de deuda
                        items: itemsDeuda, 
                        recibido: abono,
                        cambio: 0,
                        cliente: 'Abono a deuda de: ${deudor['nombre']}'
                      );

                      // 3. Generar Ticket de Abono
                      await ImpresionTicket.imprimirTicketAbono(
                        nombreDeudor: deudor['nombre'],
                        items: listaItems,
                        montoAbonado: abono,
                        deudaAnterior: deudaPrevia,
                        saldoRestante: saldoRestante < 0 ? 0 : saldoRestante,
                      );

                      if (!mounted) return;

                      _cargarDeudores();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Pago registrado")),
                      );
                    }
                  },
                  child: const Text("REGISTRAR PAGO"),
                )
              ],
            );
          }
        )
    ).then((_) => abonoCtrl.dispose()); // Aquí evitamos la fuga de memoria
  }

  Widget _tag(String texto, MaterialColor colorBase) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: colorBase[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorBase.shade100)
      ),
      child: Text(texto,
          style: TextStyle(fontSize: 10, color: colorBase[800], fontWeight: FontWeight.bold)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmall = constraints.maxWidth < 700;
        return Column(
          children: [
            // Barra Superior
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: isSmall
                  ? Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.money_off, size: 28, color: Colors.red),
                            const SizedBox(width: 10),
                            const Text("Deudas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          decoration: const InputDecoration(hintText: "Buscar deudor...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
                          onChanged: (v) {
                            _query = v;
                            _cargarDeudores();
                          },
                        )
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.money_off, size: 28, color: Colors.red),
                        const SizedBox(width: 10),
                        const Text("Control de Deudas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(hintText: "Buscar deudor...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                            onChanged: (v) {
                              _query = v;
                              _cargarDeudores();
                            },
                          ),
                        )
                      ],
                    ),
            ),

            // Lista de Tarjetas
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _deudores.isEmpty
                  ? const Center(child: Text("No hay deudas pendientes.", style: TextStyle(fontSize: 18, color: Colors.grey)))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _deudores.length,
                itemBuilder: (ctx, i) {
                  final d = _deudores[i];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.red[50],
                            radius: isSmall ? 20 : 25,
                            child: Text(d['nombre'][0].toString().toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: isSmall ? 16 : 20)),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['nombre'], style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.bold)),
                                Text("Último mov: ${d['fecha_ultimo_fiado'].toString().split(' ')[0]}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("ADEUDO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text("\$${d['total_deuda'].toStringAsFixed(2)}", style: TextStyle(fontSize: isSmall ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                          if (!isSmall) ...[
                            const SizedBox(width: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text("Detalles"),
                              onPressed: () => _verDetalle(d),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue)
                              ),
                            )
                          ] else 
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Colors.blue),
                              onPressed: () => _verDetalle(d),
                            )
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        );
      }
    );
  }
}