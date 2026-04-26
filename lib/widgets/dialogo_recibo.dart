import 'package:flutter/material.dart';
import '../models/item_venta.dart'; // Importamos tu modelo para leer los items correctamente

class DialogoRecibo extends StatelessWidget {
  final Map<String, dynamic> venta;

  const DialogoRecibo({Key? key, required this.venta}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Usamos tu método inteligente que soporta JSON y el formato viejo (pipes)
    final String itemsRaw = venta['items'] ?? "";
    final List<ItemVenta> listaItems = ItemVenta.listaDesdeString(itemsRaw);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 50, color: Colors.blueGrey),
            const SizedBox(height: 10),
            Text("Ticket #${venta['folio_venta'] ?? venta['id']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(venta['fecha'].toString(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const Divider(thickness: 2),

            // LISTA DESGLOSADA DE PRODUCTOS
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: listaItems.length,
                itemBuilder: (context, i) {
                  final item = listaItems[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${item.cantidad}x ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Expanded(
                          child: Text(item.descripcion, style: const TextStyle(fontSize: 15)),
                        ),
                        Text(
                            "\$${(item.precio * item.cantidad).toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                    "\$${(venta['total'] as num).toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text("Cliente: ${venta['cliente'] ?? 'Mostrador'}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CERRAR")
            )
          ],
        ),
      ),
    );
  }
}