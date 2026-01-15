import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Login extends StatelessWidget {
  const Login({Key? key}) : super(key: key);

  Future<void> _iniciarSesionConGoogle() async {
    final googleProvider = GoogleAuthProvider();
    await FirebaseAuth.instance.signInWithPopup(googleProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _iniciarSesionConGoogle,
          child: const Text('Iniciar sesión con Google'),
        ),
      ),
    );
  }
}