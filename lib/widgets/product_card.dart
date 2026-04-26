import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../constants/colores.dart';

class ProductCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(int)? onStockChange;
  final bool alertStock; // Para cambiar el color a rojo en 'Agotados'

  const ProductCard({
    Key? key,
    required this.producto,
    this.onEdit,
    this.onDelete,
    this.onStockChange,
    this.alertStock = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // FILA 1: DATOS PRINCIPALES
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(producto.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("Código: ${producto.codigo} | SKU: ${producto.sku}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      Text("Marca: ${producto.marca} | Factura: ${producto.factura}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text("\$${producto.precio.toStringAsFixed(2)}", style: const TextStyle(color: Colores.azulCielo, fontWeight: FontWeight.bold, fontSize: 20)),
                    const Text("P. Público", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              ],
            ),
            const Divider(),

            // FILA 2: CONTROLES Y ACCIONES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // BOTONES DE ACCIÓN (Editar / Eliminar)
                Row(
                  children: [
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        tooltip: "Editar",
                        onPressed: onEdit,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Eliminar",
                        onPressed: onDelete,
                      ),
                  ],
                ),

                // CONTROL DE STOCK RÁPIDO
                if (onStockChange != null)
                  Container(
                    decoration: BoxDecoration(
                        color: alertStock ? Colors.red[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: alertStock ? Colors.red.shade200 : Colors.grey.shade300)
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.red, size: 20),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          onPressed: () => onStockChange!(-1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                              "${producto.stock}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: alertStock ? Colors.red : Colors.black
                              )
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green, size: 20),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          onPressed: () => onStockChange!(1),
                        ),
                      ],
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}