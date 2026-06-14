import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not configured for this project. Configure it with FlutterFire CLI if needed.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'This project is currently configured for Android only.',
        );
    }
  }

  static FirebaseOptions get android {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCB7eHWWJl8ROqRixgtpqDugCwD_Oi97_A',
      appId: '1:280202502782:android:05393df2acf4ea1fad6e2f',
      messagingSenderId: '280202502782',
      projectId: 'videomoney-efb89',
      storageBucket: 'videomoney-efb89.firebasestorage.app',
    );
  }
}
