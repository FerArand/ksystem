import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return windows;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      default:
        return windows;
    }
  }

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyDqHMTivMlSQ43CKBnpPsSfZ9ZgLIvdCUg",
    appId: "1:345662108001:web:70c79690db33a3ad85d520",
    messagingSenderId: "345662108001",
    projectId: "ksystem-ktools",
    authDomain: "ksystem-ktools.firebaseapp.com",
    storageBucket: "ksystem-ktools.firebasestorage.app",
  );
}