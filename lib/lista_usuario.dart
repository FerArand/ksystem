// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// //devuelve la colección de productos del usuario autenticado.
// CollectionReference<Map<String, dynamic>> coleccionProductosUsuario() {
//   final usuario = FirebaseAuth.instance.currentUser;
//
// //lanza excepción si no hay usuario
//   if (usuario == null) {
//     throw FirebaseAuthException(
//       code: 'no-user',
//       message: 'No hay usuario autenticado.',
//     );
//   }
//
//   return FirebaseFirestore.instance
//       .collection('usuarios')
//       .doc(usuario.uid)
//       .collection('productos');
// }
