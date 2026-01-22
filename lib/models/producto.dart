class Producto {
  int? id;
  String codigo; // Código de Barras (Universal)
  String sku;    // Código Interno (Nuevo)
  String factura;
  String descripcion;
  String marca;
  double costo;
  double precio;
  double precioRappi;
  int stock;
  bool borrado;

  Producto({
    this.id,
    required this.codigo,
    required this.sku, // Nuevo
    required this.factura,
    required this.descripcion,
    required this.marca,
    required this.costo,
    required this.precio,
    required this.precioRappi,
    required this.stock,
    required this.borrado,
  });

  factory Producto.desdeMapa(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      codigo: map['codigo'] ?? '',
      sku: map['sku'] ?? '', // Nuevo
      factura: map['factura'] ?? '',
      descripcion: map['descripcion'] ?? '',
      marca: map['marca'] ?? '',
      costo: map['costo'] ?? 0.0,
      precio: map['precio'] ?? 0.0,
      precioRappi: map['precioRappi'] ?? 0.0,
      stock: map['stock'] ?? 0,
      borrado: (map['borrado'] == 1),
    );
  }

  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'codigo': codigo,
      'sku': sku, // Nuevo
      'factura': factura,
      'descripcion': descripcion,
      'marca': marca,
      'costo': costo,
      'precio': precio,
      'precioRappi': precioRappi,
      'stock': stock,
      'borrado': borrado ? 1 : 0,
    };
  }
}