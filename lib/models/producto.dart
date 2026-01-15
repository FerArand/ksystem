class Producto {
  String id;
  String factura;
  String descripcion;
  String marca;
  double costo;
  double precio;
  double precioRappi;
  int stock;
  bool borrado;

  Producto({
    required this.id,
    required this.factura,
    required this.descripcion,
    required this.marca,
    required this.costo,
    required this.precio,
    required this.precioRappi,
    required this.stock,
    required this.borrado,
  });

  factory Producto.desdeMapa(Map<String, dynamic> data, String documentId) {
    return Producto(
      id: documentId,
      factura: data['factura'] ?? '',
      descripcion: data['descripcion'] ?? '',
      marca: data['marca'] ?? '',
      costo: (data['costo'] as num?)?.toDouble() ?? 0.0,
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      precioRappi: (data['precioRappi'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      borrado: data['borrado'] ?? false,
    );
  }

  Map<String, dynamic> aMapa() {
    return {
      'factura': factura,
      'descripcion': descripcion,
      'marca': marca,
      'costo': costo,
      'precio': precio,
      'precioRappi': precioRappi,
      'stock': stock,
      'borrado': borrado,
    };
  }
}