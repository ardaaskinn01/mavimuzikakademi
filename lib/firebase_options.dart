import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
    apiKey: 'AIzaSyDBidCldG33ZO9zag8sgHI6xDtDq9Sgl5c',
    appId: '1:1004299414872:web:9a1b22a8799a93e928c92d',
    messagingSenderId: '1004299414872',
    projectId: 'mavimuzikakademi-51e03',
    authDomain: 'mavimuzikakademi-51e03.firebaseapp.com',
    storageBucket: 'mavimuzikakademi-51e03.firebasestorage.app',
    measurementId: 'G-6HE242W7C6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCydPJu8s2KHww1Hph7JJ9Pc073Otgg0lg',
    appId: '1:1004299414872:android:11937aaae92da7bf28c92d',
    messagingSenderId: '1004299414872',
    projectId: 'mavimuzikakademi-51e03',
    storageBucket: 'mavimuzikakademi-51e03.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBQfOY8aDcIMNIY1rTwQOxixs_eQFI-ziw',
    appId: '1:1004299414872:ios:04097432785cbc6528c92d',
    messagingSenderId: '1004299414872',
    projectId: 'mavimuzikakademi-51e03',
    storageBucket: 'mavimuzikakademi-51e03.firebasestorage.app',
    iosBundleId: 'com.example.mavimuzikakademi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBQfOY8aDcIMNIY1rTwQOxixs_eQFI-ziw',
    appId: '1:1004299414872:ios:04097432785cbc6528c92d',
    messagingSenderId: '1004299414872',
    projectId: 'mavimuzikakademi-51e03',
    storageBucket: 'mavimuzikakademi-51e03.firebasestorage.app',
    iosBundleId: 'com.example.mavimuzikakademi',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDBidCldG33ZO9zag8sgHI6xDtDq9Sgl5c',
    appId: '1:1004299414872:web:5a2c873d5bca727028c92d',
    messagingSenderId: '1004299414872',
    projectId: 'mavimuzikakademi-51e03',
    authDomain: 'mavimuzikakademi-51e03.firebaseapp.com',
    storageBucket: 'mavimuzikakademi-51e03.firebasestorage.app',
    measurementId: 'G-HQ927H1324',
  );
}
