import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../db_helper.dart';
import '../constants/colores.dart';
import '../Utils/numeric_formatter.dart';

class ProductFormDialog extends StatefulWidget {
  final String? codigoInicial;
  final Producto? productoExistente;
  final Function(Producto) onGuardado;

  const ProductFormDialog({
    Key? key,
    this.codigoInicial,
    this.productoExistente,
    required this.onGuardado,
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
  late TextEditingController ubicacionController;
  late TextEditingController cantidadController;

  bool _esGranel = false;

  final FocusNode costoFocus = FocusNode();
  final FocusNode gananciaFocus = FocusNode();
  final FocusNode precioFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final p = widget.productoExistente;
    final bool esEdicion = p != null;
    _esGranel = p?.esGranel ?? false;

    codigoController = TextEditingController(
      text: p?.codigo ?? widget.codigoInicial ?? '',
    );
    descController = TextEditingController(text: p?.descripcion ?? '');
    marcaController = TextEditingController(text: p?.marca ?? '');
    costoController = TextEditingController(
      text: p != null ? ThousandsSeparatorInputFormatter.format(p.costo) : '',
    );
    skuController = TextEditingController(text: p?.sku ?? '');
    ubicacionController = TextEditingController(text: p?.ubicacion ?? '');
    cantidadController = TextEditingController(
      text: p != null
          ? ThousandsSeparatorInputFormatter.format(
        p.stock,
        isDecimal: _esGranel || p.stock != p.stock.roundToDouble(),
      )
          : '1',
    );

    final double precioIni = p?.precio ?? 0.0;
    double gananciaIni = 46.0;
    if (esEdicion && p.costo > 0) {
      gananciaIni = ((p.precio / p.costo) - 1) * 100;
    }

    gananciaController = TextEditingController(
      text: gananciaIni.toStringAsFixed(1),
    );
    precioController = TextEditingController(
      text: esEdicion ? ThousandsSeparatorInputFormatter.format(precioIni) : '0.00',
    );

    costoController.addListener(_calcularPrecios);
    gananciaController.addListener(_calcularPrecios);
    precioController.addListener(_calcularPrecios);
  }

  @override
  void dispose() {
    codigoController.dispose();
    descController.dispose();
    marcaController.dispose();
    costoController.dispose();
    precioController.dispose();
    gananciaController.dispose();
    skuController.dispose();
    ubicacionController.dispose();
    cantidadController.dispose();
    costoFocus.dispose();
    gananciaFocus.dispose();
    precioFocus.dispose();
    super.dispose();
  }

  void _calcularPrecios() {
    final double costo = ThousandsSeparatorInputFormatter.parse(costoController.text);
    if (costoFocus.hasFocus || gananciaFocus.hasFocus) {
      final double ganancia = double.tryParse(gananciaController.text) ?? 0;
      final double nuevoPrecio = costo * (1 + (ganancia / 100));
      final String nuevoPrecioStr = ThousandsSeparatorInputFormatter.format(nuevoPrecio);
      if (precioController.text != nuevoPrecioStr) {
        precioController.text = nuevoPrecioStr;
      }
    } else if (precioFocus.hasFocus) {
      final double precio = ThousandsSeparatorInputFormatter.parse(precioController.text);
      if (costo > 0) {
        final double nuevaGanancia = ((precio / costo) - 1) * 100;
        gananciaController.text = nuevaGanancia.toStringAsFixed(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.productoExistente != null;

    InputDecoration decoracion(String label, {bool obligatorio = false, String? suffix}) {
      return InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black87),
            children: obligatorio
                ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : [],
          ),
        ),
        suffixText: suffix,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
    }

    String? validar(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;

    return AlertDialog(
      title: Text(esEdicion ? 'Editar Producto' : 'Nuevo Producto'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codigoController,
                  decoration: decoracion('Código Barras', obligatorio: true),
                  validator: validar,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descController,
                  decoration: decoracion('Descripción', obligatorio: true),
                  validator: validar,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: marcaController,
                  decoration: decoracion('Marca', obligatorio: true),
                  validator: validar,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: costoController,
                        focusNode: costoFocus,
                        inputFormatters: [ThousandsSeparatorInputFormatter()],
                        decoration: decoracion('Costo Unitario', obligatorio: true, suffix: '\$'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: gananciaController,
                        focusNode: gananciaFocus,
                        decoration: decoracion('Margen', obligatorio: true, suffix: '%'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: precioController,
                        focusNode: precioFocus,
                        inputFormatters: [ThousandsSeparatorInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Precio Público',
                          filled: true,
                          fillColor: Colors.blue[50],
                          border: const OutlineInputBorder(),
                          suffixText: '\$',
                          labelStyle: const TextStyle(
                            color: Colores.azulPrincipal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validar,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: skuController,
                        decoration: decoracion('SKU (Opcional)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: ubicacionController,
                        decoration: decoracion('Ubicación en Anaquel (Opcional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: cantidadController,
                  decoration: decoracion(
                    _esGranel
                        ? 'Inventario disponible (Metros / Kilos - Admite decimales)'
                        : 'Inventario disponible (Unidades enteras)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    ThousandsSeparatorInputFormatter(isDecimal: _esGranel),
                  ],
                ),
                const SizedBox(height: 12),
                // RF-16: Casilla de verificación para modalidad de Venta a Granel
                Container(
                  decoration: BoxDecoration(
                    color: _esGranel ? Colors.deepPurple[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _esGranel ? Colors.deepPurple : Colors.grey.shade300,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      '¿Producto de Venta a Granel? (Metros / Kilos)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Habilita el cálculo bidireccional (Medida <-> Importe en \$) en el Punto de Venta y el descuento decimal de existencias.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _esGranel,
                    activeColor: Colors.deepPurple,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? val) {
                      setState(() {
                        _esGranel = val ?? false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colores.verde,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final double costo = ThousandsSeparatorInputFormatter.parse(costoController.text);
              final double pPublico = ThousandsSeparatorInputFormatter.parse(precioController.text);
              final double stock = ThousandsSeparatorInputFormatter.parse(cantidadController.text);

              final prod = Producto(
                id: widget.productoExistente?.id,
                uuid: widget.productoExistente?.uuid,
                codigo: codigoController.text.trim(),
                sku: skuController.text.trim(),
                factura: widget.productoExistente?.factura ?? '',
                ubicacion: ubicacionController.text.trim(),
                marca: marcaController.text.trim(),
                descripcion: descController.text.trim(),
                costo: costo,
                precio: pPublico,
                precioRappi: double.parse((pPublico * 1.35).toStringAsFixed(2)),
                stock: stock,
                esGranel: _esGranel,
                borrado: false,
              );

              if (esEdicion) {
                await DBHelper.instance.updateProducto(prod.aMapa());
              } else {
                await DBHelper.instance.insertProducto(prod.aMapa());
              }
              await DBHelper.instance.agregarReciente(prod.codigo);

              if (!esEdicion) {
                final d = await DBHelper.instance.getProductoPorCodigo(prod.codigo);
                if (d != null) prod.id = d['id'] as int?;
              }

              widget.onGuardado(prod);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Text(esEdicion ? 'ACTUALIZAR' : 'GUARDAR'),
        ),
      ],
    );
  }
}