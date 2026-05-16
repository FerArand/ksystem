import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../constants/colores.dart';
import '../Utils/formatters.dart';

class ProductCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(int)? onStockChange;
  final bool alertStock;

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
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Círculo con Inicial
            CircleAvatar(
              backgroundColor: alertStock ? Colors.red[100] : Colores.azulPrincipal.withOpacity(0.1),
              child: Text(
                producto.descripcion.isNotEmpty ? producto.descripcion[0].toUpperCase() : '?',
                style: TextStyle(
                  color: alertStock ? Colors.red : Colores.azulPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 15),

            // Información Central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.descripcion,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _infoTag("SKU: ${producto.sku}", Colors.blueGrey),
                      _infoTag("Venta: ${Formatters.formatearMoneda(producto.precio)}", Colors.green),
                      if (producto.ubicacion.isNotEmpty) _infoTag("Ubicación: ${producto.ubicacion}", Colors.orange),
                    ],
                  ),
                ],
              ),
            ),

            // Control de Stock
            if (onStockChange != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => onStockChange!(-1),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      "${producto.stock}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: alertStock ? Colors.red : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () => onStockChange!(1),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              )
            else
              Text(
                "Stock: ${producto.stock}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: alertStock ? Colors.red : Colors.black,
                ),
              ),

            const SizedBox(width: 10),

            // Acciones
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}