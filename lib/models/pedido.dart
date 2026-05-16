class Pedido {
  int? id;
  String clienteNombre;
  String clienteContacto;
  String productoNombre;
  String productoSku;
  double precioNormal;
  double precioApartado;
  double abonoInicial;
  double totalPagado;
  double costo;
  double descuento;
  String fechaCreacion;
  String? fechaEntrega;
  String estado; // 'pendiente', 'entregado'

  Pedido({
    this.id,
    required this.clienteNombre,
    required this.clienteContacto,
    required this.productoNombre,
    required this.productoSku,
    required this.precioNormal,
    required this.precioApartado,
    required this.abonoInicial,
    required this.totalPagado,
    required this.costo,
    required this.descuento,
    required this.fechaCreacion,
    this.fechaEntrega,
    this.estado = 'pendiente',
  });

  factory Pedido.desdeMapa(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'],
      clienteNombre: map['cliente_nombre'] ?? '',
      clienteContacto: map['cliente_contacto'] ?? '',
      productoNombre: map['producto_nombre'] ?? '',
      productoSku: map['producto_sku'] ?? '',
      precioNormal: (map['precio_normal'] as num).toDouble(),
      precioApartado: (map['precio_apartado'] as num).toDouble(),
      abonoInicial: (map['abono_inicial'] as num).toDouble(),
      totalPagado: (map['total_pagado'] as num).toDouble(),
      costo: (map['costo'] as num).toDouble(),
      descuento: (map['descuento'] as num).toDouble(),
      fechaCreacion: map['fecha_creacion'] ?? '',
      fechaEntrega: map['fecha_entrega'],
      estado: map['estado'] ?? 'pendiente',
    );
  }

  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'cliente_nombre': clienteNombre,
      'cliente_contacto': clienteContacto,
      'producto_nombre': productoNombre,
      'producto_sku': productoSku,
      'precio_normal': precioNormal,
      'precio_apartado': precioApartado,
      'abono_inicial': abonoInicial,
      'total_pagado': totalPagado,
      'costo': costo,
      'descuento': descuento,
      'fecha_creacion': fechaCreacion,
      'fecha_entrega': fechaEntrega,
      'estado': estado,
    };
  }
}
