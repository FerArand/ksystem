import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'databases/debt_db.dart';
import 'models/item_venta.dart';

import 'databases/history_db.dart';
import 'Utils/impresion_ticket.dart';
import 'Utils/formatters.dart';
import 'Utils/numeric_formatter.dart';
import 'package:intl/intl.dart';
import 'constants/colores.dart';

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
    final TextEditingController recibidoCtrl = TextEditingController();
    double cambioCalculado = 0.0;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return LayoutBuilder(
              builder: (context, constraints) {
                bool isSmall = constraints.maxWidth < 650;
                
                void calcularCambio() {
                  double abono = ThousandsSeparatorInputFormatter.parse(abonoCtrl.text);
                  double recibido = ThousandsSeparatorInputFormatter.parse(recibidoCtrl.text);
                  setStateDialog(() {
                    cambioCalculado = (recibido - abono) > 0 ? (recibido - abono) : 0.0;
                  });
                }

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
                            height: 200,
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
                                                if (item.precio > 0) _tag("Total: ${Formatters.formatearMoneda(item.precio)}", Colors.green),
                                                if (item.costo > 0) _tag("Mínimo aceptable: ${Formatters.formatearMoneda(item.costo)}", Colors.grey),
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(Formatters.formatearMoneda(deudor['total_deuda']),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: StatefulBuilder(
                                  builder: (context, setStateRecibido) {
                                    return TextField(
                                      controller: recibidoCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                                      onChanged: (_) {
                                        calcularCambio();
                                      },
                                      decoration: InputDecoration(
                                          labelText: "Dinero Recibido",
                                          prefixText: "\$",
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Colors.white,
                                          errorText: (() {
                                            double abono = ThousandsSeparatorInputFormatter.parse(abonoCtrl.text);
                                            double recibido = ThousandsSeparatorInputFormatter.parse(recibidoCtrl.text);
                                            if (recibido < abono) return "Insuficiente";
                                            return null;
                                          })(),
                                          errorStyle: const TextStyle(color: Colors.red),
                                          focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                                          errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red))
                                      ),
                                    );
                                  }
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StatefulBuilder(
                                  builder: (context, setStateError) {
                                    return TextField(
                                      controller: abonoCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                                      onChanged: (val) {
                                        calcularCambio();
                                      },
                                      decoration: InputDecoration(
                                          labelText: "Monto a Abonar",
                                          prefixText: "\$",
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Colors.white,
                                          errorText: (() {
                                            double abono = ThousandsSeparatorInputFormatter.parse(abonoCtrl.text);
                                            double deudaTotal = (deudor['total_deuda'] as num).toDouble();
                                            if (abono <= 0) return "Monto inválido";
                                            if (abono > deudaTotal) return "Excede la deuda";
                                            return null;
                                          })(),
                                          errorStyle: const TextStyle(color: Colors.red),
                                          focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                                          errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red))
                                      ),
                                    );
                                  }
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(5)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("CAMBIO A ENTREGAR:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                Text(Formatters.formatearMoneda(cambioCalculado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                              ],
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
                        double abono = ThousandsSeparatorInputFormatter.parse(abonoCtrl.text);
                        double recibido = ThousandsSeparatorInputFormatter.parse(recibidoCtrl.text);
                        final deudaPrevia = (deudor['total_deuda'] as num).toDouble();

                        if (abono > 0 && abono <= deudaPrevia && recibido >= abono) {
                          final abonoAplicado = abono;
                          final saldoRestante = deudaPrevia - abonoAplicado;
                          
                          final cambioTotal = recibido - abono;
                          final recibidoTotal = recibido;

                          // 1. Registrar abono en la base de datos de deudas
                          await DebtDB.instance.abonar(deudor['id'], abonoAplicado);

                          // 2. Registrar el ingreso en el calendario (HistoryDB)
                          final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                          
                          // RECUPERAR ITEMS PARA EL HISTORIAL (Para que la reimpresión sea exacta)
                          String itemsDeuda = deudor['items'] ?? '[]';

                          await HistoryDB.instance.registrarVenta(
                            fecha: fecha,
                            total: abonoAplicado,
                            costoTotal: 0, // El costo ya se registró cuando se pidió el fiado
                            items: itemsDeuda, 
                            recibido: recibidoTotal,
                            cambio: cambioTotal,
                            cliente: 'Abono a deuda de: ${deudor['nombre']}'
                          );

                          // 3. Generar Ticket de Abono
                          if (mounted) {
                            await ImpresionTicket.imprimirTicketAbono(
                              nombreDeudor: deudor['nombre'],
                              items: listaItems,
                              montoAbonado: abonoAplicado,
                              deudaAnterior: deudaPrevia,
                              saldoRestante: saldoRestante < 0 ? 0 : saldoRestante,
                              recibido: recibidoTotal,
                              cambio: cambioTotal,
                            );
                          }

                          if (!mounted) return;

                          _cargarDeudores();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Pago registrado")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("REGISTRAR PAGO"),
                    )
                  ],
                );
              }
            );
          }
        )
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        abonoCtrl.dispose();
        recibidoCtrl.dispose();
      });
    }); // Aquí evitamos la fuga de memoria y el error de _dependents
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
    return Column(
      children: [
        // --- ENCABEZADO UNIFICADO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(
            color: Colores.deudas,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Row(
            children: [
              Icon(Icons.money_off, color: Colors.white, size: 28),
              const SizedBox(width: 15),
              const Text("CONTROL DE DEUDAS", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Z-PATTERN: ACCIÓN/BÚSQUEDA COMIENZA AQUÍ
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
                    decoration: InputDecoration(
                        hintText: "Buscar deudor por nombre...",
                        prefixIcon: const Icon(Icons.search, color: Colores.deudas),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colores.deudas, width: 2)),
                        filled: true,
                        fillColor: Colors.white,
                    ),
                    onChanged: (v) {
                      _query = v;
                      _cargarDeudores();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de Tarjetas
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: Colores.deudas))
              : _deudores.isEmpty
                  ? const Center(child: Text("No hay deudas pendientes.", style: TextStyle(fontSize: 18, color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _deudores.length,
                      itemBuilder: (ctx, i) {
                        final d = _deudores[i];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _verDetalle(d),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.red[50],
                                    radius: 25,
                                    child: Text(d['nombre'][0].toString().toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 20)),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(d['nombre'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text("Último movimiento: ${d['fecha_ultimo_fiado'].toString().split(' ')[0]}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text("ADEUDO TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      Text(Formatters.formatearMoneda(d['total_deuda']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        )
      ],
    );
  }
}