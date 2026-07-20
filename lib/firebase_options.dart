// Konfigurasi Firebase untuk project "project-seblak-kacida".
// Nilai diambil dari android/app/google-services.json.
// ignore_for_file: type=lint
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
      throw UnsupportedError(
        'DefaultFirebaseOptions belum dikonfigurasi untuk web. '
        'Daftarkan app web di Firebase Console project-seblak-kacida, '
        'lalu jalankan FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk platform ini. '
          'Hanya Android yang terdaftar di project project-seblak-kacida. '
          'Daftarkan platform lain di Firebase Console jika diperlukan.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyALpZAWPZHdT3Gnf4E6hz7EQEpxRKBS3As',
    appId: '1:541009219366:android:211d28e5a35ed5550f3be7',
    messagingSenderId: '541009219366',
    projectId: 'project-seblak-kacida',
    storageBucket: 'project-seblak-kacida.firebasestorage.app',
  );
}
