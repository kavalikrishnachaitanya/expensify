// File generated for Firebase configuration
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
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAlT_f5fxrCSbGoMoI4NhmazPaIfW9Ceoo',
    appId: '1:782208796750:web:fad9f3ff51730a9b941b1f',
    messagingSenderId: '782208796750',
    projectId: 'expensify-505418',
    authDomain: 'expensify-505418.firebaseapp.com',
    storageBucket: 'expensify-505418.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlT_f5fxrCSbGoMoI4NhmazPaIfW9Ceoo',
    appId: '1:782208796750:android:fad9f3ff51730a9b941b1f',
    messagingSenderId: '782208796750',
    projectId: 'expensify-505418',
    storageBucket: 'expensify-505418.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBpfWF1eEFhoMptbwXakU3SN2CHq6Q6IFk',
    appId: '1:782208796750:ios:79a6e38b3fc7ad8e941b1f',
    messagingSenderId: '782208796750',
    projectId: 'expensify-505418',
    storageBucket: 'expensify-505418.firebasestorage.app',
    iosClientId: '782208796750-g35qpti1fddarssf9is1gv391n33of23.apps.googleusercontent.com',
    iosBundleId: 'com.example.expenses',
  );
}
