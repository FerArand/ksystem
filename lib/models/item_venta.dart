import 'dart:convert';

class ItemVenta {
  String sku;
  String codigo;
  String descripcion;
  double cantidad; // Soporta enteros y decimales (metros/kilos)
  double precio;
  double costo;
  bool esGranel;

  ItemVenta({
    required this.sku,
    this.codigo = '',
    required this.descripcion,
    required num cantidad,
    required this.precio,
    required this.costo,
    this.esGranel = false,
  }) : cantidad = cantidad.toDouble();

  double get subtotal => cantidad * precio;
  double get costoProporcional => cantidad * costo;

  factory ItemVenta.desdeMapa(Map<String, dynamic> map) {
    return ItemVenta(
      sku: (map['sku'] ?? 'N/A').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? 'Sin descripción').toString(),
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 1.0,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      costo: (map['costo'] as num?)?.toDouble() ?? 0.0,
      esGranel: map['es_granel'] == 1 || map['es_granel'] == true,
    );
  }

  factory ItemVenta.fromJson(Map<String, dynamic> json) => ItemVenta.desdeMapa(json);
  factory ItemVenta.fromMap(Map<String, dynamic> map) => ItemVenta.desdeMapa(map);

  Map<String, dynamic> aMapa() {
    return {
      'sku': sku,
      if (codigo.isNotEmpty) 'codigo': codigo,
      'descripcion': descripcion,
      'cantidad': (!esGranel && cantidad == cantidad.roundToDouble())
          ? cantidad.toInt()
          : double.parse(cantidad.toStringAsFixed(3)),
      'precio': precio,
      'costo': costo,
      'es_granel': esGranel ? 1 : 0,
    };
  }

  // Restaurado para compatibilidad con calendario_ventas.dart y venta.dart
  Map<String, dynamic> toJson() => aMapa();
  Map<String, dynamic> toMap() => aMapa();

  static List<ItemVenta> listaDesdeString(String rawJson) {
    if (rawJson.trim().isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson);
      final List<ItemVenta> resultado = [];
      for (final item in decoded) {
        if (item is Map) {
          resultado.add(
            ItemVenta.desdeMapa(Map<String, dynamic>.from(item)),
          );
        }
      }
      return resultado;
    } catch (_) {
      return [];
    }
  }

  static String listaAJson(List<ItemVenta> items) {
    return jsonEncode(items.map((e) => e.aMapa()).toList());
  }
}