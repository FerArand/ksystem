import 'dart:convert';

class ItemVenta {
  final String sku;
  final String descripcion;
  final int cantidad;
  final double precio;
  final double costo;

  const ItemVenta({
    required this.sku,
    required this.descripcion,
    required this.cantidad,
    required this.precio,
    required this.costo,
  });

  // De objeto Dart → Map para guardar en JSON
  Map<String, dynamic> toJson() => {
    'sku': sku,
    'descripcion': descripcion,
    'cantidad': cantidad,
    'precio': precio,
    'costo': costo,
  };

  // De Map (parseado del JSON) → objeto Dart
  factory ItemVenta.fromJson(Map<String, dynamic> json) => ItemVenta(
    sku:         json['sku']         ?? '',
    descripcion: json['descripcion'] ?? '',
    cantidad:    json['cantidad']    ?? 1,
    precio:      (json['precio']     ?? 0.0).toDouble(),
    costo:       (json['costo']      ?? 0.0).toDouble(),
  );

  // Convierte una lista de items a string JSON para guardar en BD
  static String listaAJson(List<ItemVenta> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  // Parsea el string JSON de la BD a lista de objetos
  // Maneja tanto el formato nuevo (JSON) como el viejo (pipes)
  // para compatibilidad durante la transición
  static List<ItemVenta> listaDesdeString(String raw) {
    if (raw.isEmpty) return [];

    // Detectar si es JSON nuevo o pipe-separated viejo
    if (raw.trimLeft().startsWith('[')) {
      try {
        final lista = jsonDecode(raw) as List;
        return lista.map((e) => ItemVenta.fromJson(e)).toList();
      } catch (_) {
        return [];
      }
    }

    // Fallback: parsear formato viejo con pipes
    // Esto cubre filas que no migraron correctamente
    return raw.split('|')
        .where((s) => s.isNotEmpty)
        .map((s) {
      final skuMatch    = RegExp(r'\[SKU:(.*?)\]').firstMatch(s);
      final precioMatch = RegExp(r'\[P:(.*?)\]').firstMatch(s);
      final costoMatch  = RegExp(r'\[C:(.*?)\]').firstMatch(s);
      final cantMatch   = RegExp(r'^(\d+)x').firstMatch(s.trim());
      final descripcion = s.replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'^\d+x'), '').trim();
      return ItemVenta(
        sku:         skuMatch?.group(1)    ?? '',
        descripcion: descripcion,
        cantidad:    int.tryParse(cantMatch?.group(1) ?? '1') ?? 1,
        precio:      double.tryParse(precioMatch?.group(1) ?? '0') ?? 0,
        costo:       double.tryParse(costoMatch?.group(1)  ?? '0') ?? 0,
      );
    }).toList();
  }
}