// Configuración de Firebase leída desde variables de entorno.
//
// Los valores NO están escritos en el código. Se pasan al compilar con:
//   flutter run --dart-define-from-file=.env.json
// Copia `.env.example.json` a `.env.json` y rellénalo (ese archivo no se sube a git).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  static FirebaseOptions get currentPlatform {
    if (_projectId.isEmpty) {
      throw StateError(
        'Falta la configuración de Firebase. Ejecuta la app con '
        '--dart-define-from-file=.env.json (ver .env.example.json).',
      );
    }
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        // Windows usa la configuración de la app web.
        return web;
      default:
        throw UnsupportedError(
          'Firebase no está configurado para $defaultTargetPlatform. '
          'Registra la app en el proyecto Firebase y agrégala aquí.',
        );
    }
  }

  static FirebaseOptions get web => const FirebaseOptions(
        apiKey: _webApiKey,
        appId: _webAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: _authDomain,
        storageBucket: _storageBucket,
      );

  static FirebaseOptions get android => const FirebaseOptions(
        apiKey: _androidApiKey,
        appId: _androidAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
      );
}
