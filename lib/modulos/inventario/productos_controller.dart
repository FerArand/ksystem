import 'package:flutter/material.dart';
import '../../db_helper.dart';
import '../../models/producto.dart';

class ProductosController extends ChangeNotifier {
  List<Producto> listaProductos = [];
  bool cargando = true;
  String query = '';

  ProductosController() {
    cargarProductos();
  }

  /// Carga el catálogo aplicando filtrado multicriterio (RF-02) y límite en memoria (RNF-04)
  Future<void> cargarProductos([String? nuevaQuery]) async {
    if (nuevaQuery != null) {
      query = nuevaQuery;
    }
    cargando = true;
    notifyListeners();

    try {
      listaProductos = await DBHelper.instance.buscarProductosMulticriterio(
        query,
        limite: 100,
      );
    } catch (e) {
      debugPrint('[ProductosController] Error al cargar productos: $e');
      listaProductos = [];
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  /// Actualiza existencias soportando unidades enteras y fracciones decimales a granel (RF-16)
  Future<void> modificarStock(Producto p, num cantidad) async {
    await DBHelper.instance.updateStock(p.codigo, cantidad);
    p.stock = double.parse((p.stock + cantidad.toDouble()).toStringAsFixed(4));
    notifyListeners();
  }

  /// Ejecuta la baja lógica (borrado = 1) para preservar la integridad del historial (RF-01)
  Future<void> borrarProducto(int id) async {
    await DBHelper.instance.deleteProducto(id);
    await cargarProductos();
  }

  /// Asocia o actualiza el código de barras de un producto existente (RF-03)
  Future<void> vincularCodigo(int idProducto, String nuevoCodigo) async {
    await DBHelper.instance.vincularCodigo(idProducto, nuevoCodigo);
    await cargarProductos();
  }
}