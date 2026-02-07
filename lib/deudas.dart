import 'package:flutter/material.dart';
import 'databases/debt_db.dart';
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
    List<String> listaItems = itemsRaw.split('|').where((e) => e.isNotEmpty).toList();
    TextEditingController abonoCtrl = TextEditingController();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Cuenta de: ${deudor['nombre']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Fecha último fiado: ${deudor['fecha_ultimo_fiado'].toString().split('.')[0]}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          content: SizedBox(
            width: 600, // Un poco más ancho para que quepa todo
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
                      String raw = listaItems[i];

                      // EXTRACCIÓN DE METADATOS (SKU, Precio, Costo) usando Regex simple
                      String sku = "";
                      String precio = "";
                      String costo = "";

                      final skuMatch = RegExp(r'\[SKU:(.*?)\]').firstMatch(raw);
                      if (skuMatch != null) sku = skuMatch.group(1) ?? "";

                      final precioMatch = RegExp(r'\[P:(.*?)\]').firstMatch(raw);
                      if (precioMatch != null) precio = precioMatch.group(1) ?? "";

                      final costoMatch = RegExp(r'\[C:(.*?)\]').firstMatch(raw);
                      if (costoMatch != null) costo = costoMatch.group(1) ?? "";

                      // Limpiar descripción (quitar los tags [..])
                      String descripcion = raw.replaceAll(RegExp(r'\[.*?\]'), '').trim();

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
                                  Text(descripcion, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  // Fila de metadatos (SKU, Precio, Costo)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (sku.isNotEmpty) _tag("SKU: $sku", Colors.blue),
                                      if (precio.isNotEmpty) _tag("Vendido: \$$precio", Colors.green),
                                      if (costo.isNotEmpty) _tag("Costo: \$$costo", Colors.grey),
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
                    const Text("DEUDA TOTAL:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("\$${deudor['total_deuda'].toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: abonoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Monto a Abonar/Pagar",
                      prefixText: "\$",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cerrar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colores.azulPrincipal, foregroundColor: Colors.white),
              onPressed: () async {
                double abono = double.tryParse(abonoCtrl.text) ?? 0;
                if (abono > 0) {
                  await DebtDB.instance.abonar(deudor['id'], abono);
                  _cargarDeudores();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abono registrado correctamente")));
                }
              },
              child: const Text("REGISTRAR ABONO"),
            )
          ],
        )
    );
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
        // Barra Superior
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.money_off, size: 28, color: Colors.red),
              const SizedBox(width: 10),
              const Text("Registro de Deudas (Fiado)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
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
                            Text("Último mov: ${d['fecha_ultimo_fiado'].toString().split(' ')[0]}", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("ADEUDO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("\$${d['total_deuda'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("Ver / Abonar"),
                        onPressed: () => _verDetalle(d),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue)
                        ),
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
}