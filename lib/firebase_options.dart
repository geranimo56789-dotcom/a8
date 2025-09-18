import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC2kZjQtro_hKd-TZRBTlXfqE9Fj4_PqUA',
    appId: '1:507455941575:web:bc7e4d925c9c497cf3c7e2',
    messagingSenderId: '507455941575',
    projectId: 'var6-51392',
    authDomain: 'var6-51392.firebaseapp.com',
    storageBucket: 'var6-51392.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2kZjQtro_hKd-TZRBTlXfqE9Fj4_PqUA',
    appId: '1:507455941575:android:bc7e4d925c9c497cf3c7e2',
    messagingSenderId: '507455941575',
    projectId: 'var6-51392',
    storageBucket: 'var6-51392.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC2kZjQtro_hKd-TZRBTlXfqE9Fj4_PqUA',
    appId: '1:507455941575:ios:bc7e4d925c9c497cf3c7e2',
    messagingSenderId: '507455941575',
    projectId: 'var6-51392',
    storageBucket: 'var6-51392.firebasestorage.app',
    iosClientId: '507455941575-bc7e4d925c9c497cf3c7e2.apps.googleusercontent.com',
    iosBundleId: 'com.example.myApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC2kZjQtro_hKd-TZRBTlXfqE9Fj4_PqUA',
    appId: '1:507455941575:ios:bc7e4d925c9c497cf3c7e2',
    messagingSenderId: '507455941575',
    projectId: 'var6-51392',
    storageBucket: 'var6-51392.firebasestorage.app',
    iosClientId: '507455941575-bc7e4d925c9c497cf3c7e2.apps.googleusercontent.com',
    iosBundleId: 'com.example.myApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC2kZjQtro_hKd-TZRBTlXfqE9Fj4_PqUA',
    appId: '1:507455941575:web:bc7e4d925c9c497cf3c7e2',
    messagingSenderId: '507455941575',
    projectId: 'var6-51392',
    storageBucket: 'var6-51392.firebasestorage.app',
  );
}
