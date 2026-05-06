import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDyURnZJ6DEFHW04R8lJvDIY9drPK8is6c',
    authDomain: 'cruchefangular.firebaseapp.com',
    projectId: 'cruchefangular',
    storageBucket: 'cruchefangular.firebasestorage.app',
    messagingSenderId: '451514637467',
    appId: '1:451514637467:web:a2393ca908935a637afa3e',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAv3Te9SUCh5R0iL189foEB-sBqic2-5r4',
    appId: '1:451514637467:android:fc1f8d1db4ce18fb7afa3e',
    messagingSenderId: '451514637467',
    projectId: 'cruchefangular',
    storageBucket: 'cruchefangular.firebasestorage.app',
  );
}
