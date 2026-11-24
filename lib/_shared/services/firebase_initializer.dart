import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Cómo demuestra la app a Firebase que es la app real (App Check).
/// Protege la IA: sin esto, cualquiera con la configuración del proyecto
/// podría gastar tu cuota de Gemini.
///
/// Se elige al generar el APK:
///   --dart-define=APP_CHECK=debug  (por defecto) APK de prueba instalado a
///        mano. Cada celular crea un "código secreto de depuración" la primera
///        vez; hay que registrarlo en Firebase Console > App Check.
///   --dart-define=APP_CHECK=play   Para publicar en Google Play: usa Play
///        Integrity (no hay que registrar códigos).
class AppCheckConfig {
  AppCheckConfig._();

  static const mode = String.fromEnvironment(
    'APP_CHECK',
    defaultValue: 'debug',
  );

  static bool get usePlayIntegrity => mode == 'play';
}

class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) return; // la versión web no usa la IA
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AppCheckConfig.usePlayIntegrity
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        appleProvider: AppCheckConfig.usePlayIntegrity
            ? AppleProvider.appAttestWithDeviceCheckFallback
            : AppleProvider.debug,
      );
    } catch (e) {
      // Si falla, la app sigue funcionando; solo el chat usará la ayuda básica.
      debugPrint('[APP CHECK] no se pudo activar: $e');
    }
  }
}
