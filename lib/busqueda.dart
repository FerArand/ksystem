// import 'models/producto.dart';
//
// class Busqueda {
//   //minúsculas y sin espacios sobrantes
//   static String _normalizar(String valor) => valor.toLowerCase().trim();
//
//   //devuelve una lista de productos que coinciden por factura o descripción
//   static List<Producto> filtrarPorFacturaODescripcion(
//       List<Producto> todos,
//       String query,
//       ) {
//     final q = _normalizar(query);
//     if (q.isEmpty) return [];
//
//     return todos.where((p) {
//       final fac = p.factura.toLowerCase();
//       final desc = p.descripcion.toLowerCase();
//       return fac.contains(q) || desc.contains(q);
//     }).toList();
//   }
//
//   //devuelve un producto que coincida lo mejor posible con la factura o descripción
//   static Producto? encontrarUnoPorFacturaODescripcion(
//       List<Producto> todos,
//       String query,
//       ) {
//     final q = _normalizar(query);
//     if (q.length < 2) return null; //evita búsquedas con un solo caracter
//
//     final filtrados = filtrarPorFacturaODescripcion(todos, q);
//     if (filtrados.isEmpty) return null;
//
//     // 1) Coincidencia por número de factura
//     final exacto = filtrados.where((p) => p.factura.toLowerCase() == q).toList();
//     if (exacto.isNotEmpty) return exacto.first;
//
//     // 2) Coincidencia donde la factura empieza con...
//     final inicia = filtrados.where((p) => p.factura.toLowerCase().startsWith(q)).toList();
//     if (inicia.isNotEmpty) return inicia.first;
//
//     // 3) De lo contrario, el primer filtrado (descripcion o factura contiene)
//     return filtrados.first;
//   }
// }