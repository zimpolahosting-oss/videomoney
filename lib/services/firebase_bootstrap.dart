import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void>? _initFuture;

  static Future<void> ensureInitialized() {
    return _initFuture ??= _ensureInitialized();
  }

  static Future<void> _ensureInitialized() async {
    // If a Firebase app is already registered in the current isolate, do nothing.
    if (Firebase.apps.isNotEmpty) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return;
    } on FirebaseException catch (e) {
      // Some Android setups can auto-initialize the default app via native
      // providers before Flutter runs. In that case, attempting to initialize
      // again can throw a duplicate-app error. If so, proceed without failing.
      if (e.code == 'duplicate-app') {
        return;
      }
      rethrow;
    }
  }
}
