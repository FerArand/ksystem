// import 'package:firebase_auth/firebase_auth.dart';
//
// //devuelve el usuario actual o null si no hay sesión
// User? usuarioActualONulo() => FirebaseAuth.instance.currentUser;
//
// //devuelve el usuario actual o lanza una excepción si no hay sesión
// User usuarioActualOExcepcion() {
//   final usuario = FirebaseAuth.instance.currentUser;
//
//   if (usuario == null) {
//     throw FirebaseAuthException(
//       code: 'no-user',
//       message: 'No hay un usuario autenticado.',
//     );
//   }
//   return usuario;
// }