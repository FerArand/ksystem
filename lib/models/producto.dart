class Producto {
  int? id;
  String? uuid;
  String codigo;
  String sku;
  String factura;
  String ubicacion;
  String descripcion;
  String marca;
  double costo;
  double precio;
  double precioRappi;
  double stock; // Soporta enteros y decimales para venta a granel (RF-16)
  bool esGranel;
  bool borrado; // Bool en Dart para compatibilidad total con product_form_dialog.dart
  String? updatedAt;

  Producto({
    this.id,
    this.uuid,
    required this.codigo,
    this.sku = '',
    this.factura = '',
    this.ubicacion = '',
    required this.descripcion,
    this.marca = '',
    required this.costo,
    required this.precio,
    this.precioRappi = 0.0,
    required num stock,
    this.esGranel = false,
    this.borrado = false,
    this.updatedAt,
  }) : stock = stock.toDouble();

  factory Producto.desdeMapa(Map<String, dynamic> map) {
    final rawBorrado = map['borrado'];
    final bool estaBorrado = rawBorrado == 1 || rawBorrado == true;

    final rawGranel = map['es_granel'];
    final bool granelActivo = rawGranel == 1 || rawGranel == true;

    return Producto(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      codigo: (map['codigo'] ?? '').toString(),
      sku: (map['sku'] ?? '').toString(),
      factura: (map['factura'] ?? '').toString(),
      ubicacion: (map['ubicacion'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      marca: (map['marca'] ?? '').toString(),
      costo: (map['costo'] as num?)?.toDouble() ?? 0.0,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      precioRappi: (map['precioRappi'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
      esGranel: granelActivo,
      borrado: estaBorrado,
      updatedAt: map['updated_at'] as String?,
    );
  }

  factory Producto.fromMap(Map<String, dynamic> map) => Producto.desdeMapa(map);

  Map<String, dynamic> aMapa() {
    return {
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      'codigo': codigo,
      'sku': sku,
      'factura': factura,
      'ubicacion': ubicacion,
      'descripcion': descripcion,
      'marca': marca,
      'costo': costo,
      'precio': precio,
      'precioRappi': precioRappi,
      'stock': stock,
      'es_granel': esGranel ? 1 : 0,
      'borrado': borrado ? 1 : 0,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => aMapa();

  String get stockFormateado {
    if (!esGranel && stock == stock.roundToDouble()) {
      return stock.toInt().toString();
    }
    return stock == stock.roundToDouble()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(2);
  }
}