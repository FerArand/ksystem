import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../db_helper.dart';
import '../databases/recent_db.dart';
import '../constants/colores.dart';

class ProductFormDialog extends StatefulWidget {
  final String? codigoInicial;
  final Producto? productoExistente;
  final Function(Producto) onGuardado;

  const ProductFormDialog({
    Key? key,
    this.codigoInicial,
    this.productoExistente,
    required this.onGuardado
  }) : super(key: key);

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController codigoController;
  late TextEditingController descController;
  late TextEditingController marcaController;
  late TextEditingController costoController;
  late TextEditingController precioController;
  late TextEditingController gananciaController;
  late TextEditingController skuController;
  late TextEditingController facturaController;
  late TextEditingController cantidadController;

  final FocusNode costoFocus = FocusNode();
  final FocusNode gananciaFocus = FocusNode();
  final FocusNode precioFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final p = widget.productoExistente;
    bool esEdicion = p != null;

    codigoController = TextEditingController(text: p?.codigo ?? widget.codigoInicial ?? "");
    descController = TextEditingController(text: p?.descripcion ?? "");
    marcaController = TextEditingController(text: p?.marca ?? "");
    costoController = TextEditingController(text: p?.costo.toString() ?? "");
    skuController = TextEditingController(text: p?.sku ?? "");
    facturaController = TextEditingController(text: p?.factura ?? "");
    cantidadController = TextEditingController(text: p?.stock.toString() ?? "1");

    double precioIni = p?.precio ?? 0.0;
    double gananciaIni = 46.0;
    if (esEdicion && p!.costo > 0) {
      gananciaIni = ((p.precio / p.costo) - 1) * 100;
    }

    gananciaController = TextEditingController(text: gananciaIni.toStringAsFixed(1));
    precioController = TextEditingController(text: precioIni.toStringAsFixed(2));

    costoController.addListener(_calcularPrecios);
    gananciaController.addListener(_calcularPrecios);
    precioController.addListener(_calcularPrecios);
  }

  void _calcularPrecios() {
    double costo = double.tryParse(costoController.text) ?? 0;
    if (costoFocus.hasFocus || gananciaFocus.hasFocus) {
      double ganancia = double.tryParse(gananciaController.text) ?? 0;
      double nuevoPrecio = costo * (1 + (ganancia / 100));
      if (precioController.text != nuevoPrecio.toStringAsFixed(2)) {
        precioController.text = nuevoPrecio.toStringAsFixed(2);
      }
    } else if (precioFocus.hasFocus) {
      double precio = double.tryParse(precioController.text) ?? 0;
      if (costo > 0) {
        double nuevaGanancia = ((precio / costo) - 1) * 100;
        gananciaController.text = nuevaGanancia.toStringAsFixed(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool esEdicion = widget.productoExistente != null;

    InputDecoration decoracion(String label, {bool obligatorio = false, String? suffix}) {
      return InputDecoration(
          label: RichText(text: TextSpan(text: label, style: const TextStyle(color: Colors.black87), children: obligatorio ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [])),
          suffixText: suffix, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
      );
    }
    String? validar(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;

    return AlertDialog(
      title: Text(esEdicion ? "Editar Producto" : "Nuevo Producto"),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: codigoController, decoration: decoracion("Código Barras", obligatorio: true), validator: validar),
                const SizedBox(height: 10),
                TextFormField(controller: descController, decoration: decoracion("Descripción", obligatorio: true), validator: validar, maxLines: 2),
                const SizedBox(height: 10),
                TextFormField(controller: marcaController, decoration: decoracion("Marca", obligatorio: true), validator: validar),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                      controller: costoController, focusNode: costoFocus,
                      decoration: decoracion("Costo", obligatorio: true, suffix: "\$"), keyboardType: TextInputType.number, validator: validar
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                      controller: gananciaController, focusNode: gananciaFocus,
                      decoration: decoracion("Margen", obligatorio: true, suffix: "%"), keyboardType: TextInputType.number, validator: validar
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                    controller: precioController, focusNode: precioFocus,
                    decoration: InputDecoration(
                        labelText: "Precio Público", filled: true, fillColor: Colors.blue[50],
                        border: const OutlineInputBorder(), suffixText: "\$",
                        labelStyle: TextStyle(color: Colores.azulPrincipal, fontWeight: FontWeight.bold)
                    ),
                    keyboardType: TextInputType.number, validator: validar,
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: skuController, decoration: decoracion("SKU (Opcional)"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: facturaController, decoration: decoracion("Factura (Opcional)"))),
                ]),
                const SizedBox(height: 10),
                TextFormField(controller: cantidadController, decoration: decoracion("Inventario"), keyboardType: TextInputType.number),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colores.verde, foregroundColor: Colors.white),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              double costo = double.tryParse(costoController.text) ?? 0;
              double pPublico = double.tryParse(precioController.text) ?? 0;
              int stock = int.tryParse(cantidadController.text) ?? 0;

              final prod = Producto(
                  id: widget.productoExistente?.id,
                  codigo: codigoController.text.trim(),
                  sku: skuController.text.trim(),
                  factura: facturaController.text.trim(),
                  marca: marcaController.text.trim(),
                  descripcion: descController.text.trim(),
                  costo: costo,
                  precio: pPublico,
                  precioRappi: double.parse((pPublico * 1.35).toStringAsFixed(2)),
                  stock: stock,
                  borrado: false
              );

              if (esEdicion) {
                await DBHelper.instance.updateProducto(prod.aMapa());
              } else {
                await DBHelper.instance.insertProducto(prod.aMapa());
              }
              await RecentDB.instance.agregarReciente(prod.codigo);

              // Si fue una inserción nueva, intentamos recuperar el ID
              if (!esEdicion) {
                final d = await DBHelper.instance.getProductoPorCodigo(prod.codigo);
                if(d!=null) prod.id = d['id'];
              }

              widget.onGuardado(prod);
              Navigator.pop(context);
            }
          },
          child: Text(esEdicion ? "ACTUALIZAR" : "GUARDAR"),
        )
      ],
    );
  }
}