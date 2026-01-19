import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models/producto.dart';
import 'constants/colores.dart';

class NuevoIngreso extends StatefulWidget {
  const NuevoIngreso({Key? key}) : super(key: key);

  @override
  State<NuevoIngreso> createState() => _NuevoIngresoState();
}

class _NuevoIngresoState extends State<NuevoIngreso> {
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();

  // Lista temporal de lo añadido en esta sesión
  List<Producto> _agregadosRecientemente = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_scannerFocus);
    });
  }

  Future<void> _procesarCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    codigo = codigo.trim();

    final data = await DBHelper.instance.getProductoPorCodigo(codigo);

    if (data != null) {
      // CASO 1: YA EXISTE -> SUMAR 1 AL STOCK AUTOMÁTICAMENTE
      await DBHelper.instance.updateStock(codigo, 1);

      // Añadir a la lista visual de "Recientes"
      final p = Producto.desdeMapa(data);
      // Actualizamos el objeto con el stock nuevo
      p.stock += 1;

      setState(() {
        _agregadosRecientemente.insert(0, p);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Stock +1 para ${p.descripcion}"), duration: const Duration(milliseconds: 500)));

    } else {
      // CASO 2: NO EXISTE -> VENTANA "NUEVO!"
      _mostrarDialogoNuevoProducto(codigo);
    }

    _scannerController.clear();
    _scannerFocus.requestFocus();
  }

  Future<void> _mostrarDialogoNuevoProducto(String codigoEscaneado) async {
    final descController = TextEditingController();
    final costoController = TextEditingController();
    final precioController = TextEditingController();
    final cantidadController = TextEditingController(text: "1"); // Por defecto 1

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("¡Nuevo Producto Detectado!"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Código: $codigoEscaneado", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(controller: descController, decoration: const InputDecoration(labelText: "Descripción", border: OutlineInputBorder()), autofocus: true),
              const SizedBox(height: 10),
              TextField(controller: costoController, decoration: const InputDecoration(labelText: "Costo", border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: precioController, decoration: const InputDecoration(labelText: "Precio Público", border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: cantidadController, decoration: const InputDecoration(labelText: "Cantidad Inicial (Defecto: 1)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (descController.text.isEmpty || precioController.text.isEmpty) return;

              double costo = double.tryParse(costoController.text) ?? 0;
              double precio = double.tryParse(precioController.text) ?? 0;
              int stock = int.tryParse(cantidadController.text) ?? 1;

              final nuevoProd = Producto(
                  codigo: codigoEscaneado,
                  factura: '', // Se puede dejar vacío o pedir
                  descripcion: descController.text,
                  marca: '',
                  costo: costo,
                  precio: precio,
                  precioRappi: precio * 1.20, // Lógica ejemplo
                  stock: stock,
                  borrado: false
              );

              // GUARDAR EN BASE DE DATOS
              await DBHelper.instance.insertProducto(nuevoProd.aMapa());

              setState(() {
                _agregadosRecientemente.insert(0, nuevoProd);
              });

              Navigator.pop(context);
              _scannerFocus.requestFocus();
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  Future<void> _eliminarDeLista(Producto p) async {
    // Pregunta clave: ¿Solo restar stock o borrar de la faz de la tierra?
    // Lógica simple para el ejemplo: Restar 1 al stock si > 0.
    // Si el usuario quiere borrar el producto completamente porque se equivocó al crearlo:

    bool? borrarTodo = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Qué deseas hacer?"),
        content: Text("Producto: ${p.descripcion}"),
        actions: [
          TextButton(
              onPressed: () async {
                // Opción: Restar 1 al stock
                if (p.stock > 0) {
                  await DBHelper.instance.updateStock(p.codigo, -1);
                  setState(() {
                    p.stock--;
                    if(p.stock <= 0) _agregadosRecientemente.remove(p);
                  });
                }
                Navigator.pop(context, false);
              },
              child: const Text("Restar 1 (-1)")
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancelar
              child: const Text("No, cancela")
          ),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true), // BORRAR DEFINITIVO
              child: const Text("Tíralo (A la fosa)")
          ),
        ],
      ),
    );

    if (borrarTodo == true) {
      // Borrar de la BD
      // Necesitamos el ID, pero usaremos el codigo para buscar y borrar
      final data = await DBHelper.instance.getProductoPorCodigo(p.codigo);
      if (data != null) {
        await DBHelper.instance.deleteProducto(data['id']);
        setState(() {
          _agregadosRecientemente.remove(p);
        });
        _mostrarSnack("Este producto se irá a la fosa y no lo volverás a ver. (Eliminado)");
      }
    }
  }

  void _mostrarSnack(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _scannerController,
            focusNode: _scannerFocus,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: "AÑADIR: Escanea código para sumar stock o crear nuevo",
                prefixIcon: Icon(Icons.add_shopping_cart),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFE8F5E9) // Verde clarito
            ),
            onSubmitted: _procesarCodigo,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _agregadosRecientemente.isEmpty
                ? const Center(child: Text("¡No has agregado nada nuevo!", style: TextStyle(fontSize: 20, color: Colors.grey)))
                : ListView.builder(
              itemCount: _agregadosRecientemente.length,
              itemBuilder: (context, index) {
                final p = _agregadosRecientemente[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text("${p.stock}"), backgroundColor: Colores.verde, foregroundColor: Colors.white),
                    title: Text(p.descripcion),
                    subtitle: Text("Código: ${p.codigo}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _eliminarDeLista(p),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}