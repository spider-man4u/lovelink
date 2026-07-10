import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux',
        );
      default:
        throw UnsupportedError('Not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCQ3T0tHndXiUDXhfdXgrY8bqfJHGVzc0E',
    appId: '1:1065740283116:web:YOUR_WEB_APP_ID',
    messagingSenderId: '1065740283116',
    projectId: 'lovelink-2ecce',
    authDomain: 'lovelink-2ecce.firebaseapp.com',
    storageBucket: 'lovelink-2ecce.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQ3T0tHndXiUDXhfdXgrY8bqfJHGVzc0E',
    appId: '1:1065740283116:android:23561a3ea9131071ac09c9',
    messagingSenderId: '1065740283116',
    projectId: 'lovelink-2ecce',
    storageBucket: 'lovelink-2ecce.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQ3T0tHndXiUDXhfdXgrY8bqfJHGVzc0E',
    appId: '1:1065740283116:ios:da21914c46e375f4ac09c9',
    messagingSenderId: '1065740283116',
    projectId: 'lovelink-2ecce',
    storageBucket: 'lovelink-2ecce.firebasestorage.app',
    iosBundleId: 'com.lovelink.lovelink',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCQ3T0tHndXiUDXhfdXgrY8bqfJHGVzc0E',
    appId: '1:1065740283116:ios:da21914c46e375f4ac09c9',
    messagingSenderId: '1065740283116',
    projectId: 'lovelink-2ecce',
    storageBucket: 'lovelink-2ecce.firebasestorage.app',
    iosBundleId: 'com.lovelink.lovelink',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCQ3T0tHndXiUDXhfdXgrY8bqfJHGVzc0E',
    appId: '1:1065740283116:web:YOUR_WEB_APP_ID',
    messagingSenderId: '1065740283116',
    projectId: 'lovelink-2ecce',
    authDomain: 'lovelink-2ecce.firebaseapp.com',
    storageBucket: 'lovelink-2ecce.firebasestorage.app',
  );
}
