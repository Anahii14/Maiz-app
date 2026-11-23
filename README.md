# AgroCare (mi_app)

App Flutter para detectar enfermedades del maíz. Usa Firebase (Authentication + Firestore)
en el proyecto **agrocare-maiz**.

## Configuración (una sola vez)

1. Copia `.env.example.json` a `.env.json` y rellena los valores
   (Consola Firebase > Configuración del proyecto > Tus apps). `.env.json` no se sube a git.
2. Para Android, descarga `google-services.json` de la app Android y ponlo en
   `android/app/google-services.json` (tampoco se sube a git).

## Ejecutar

```powershell
flutter run --dart-define-from-file=.env.json
```

En VS Code basta con pulsar *Run* (la configuración está en `.vscode/launch.json`).

## Instalar en un celular Android

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=.env.json
```

Copia al celular `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (casi todos los
celulares actuales; para equipos muy antiguos usa `app-armeabi-v7a-release.apk`) e instálalo.
O, con el celular conectado por USB y la depuración USB activada:

```powershell
flutter run --release --dart-define-from-file=.env.json
```

## Análisis de hojas (IA real, sin internet)

1. **Modelo:** `assets/models/modelo_plantas.tflite` + `assets/models/etiquetas.txt`
   (orden real: Hoja_sana, Mancha_Gris_de_la_Hoja, Mancha_de_Asfalto, Roya_del_Maíz).
   Entrada 224x224x3 float32 RGB en 0–255; salida softmax de 4 clases.
2. **Confianza < 70 %** → "No reconocido" (no se guarda en el historial).
3. **% afectado** (solo enfermedades): segmentación HSV de la hoja y de las manchas.
4. **Severidad:** < 10 % Leve · 10–30 % Moderada · > 30 % Severa.

Archivos para ajustar:

- Umbrales y rangos de color HSV: `lib/features/analysis/config/analysis_config.dart`
- Textos de recomendaciones: `lib/features/analysis/config/recommendations.dart`
- Nombres, colores e íconos de cada enfermedad: `lib/features/analysis/config/disease_catalog.dart`

Cada análisis guardado (`users/{uid}/analyses`) incluye: etiqueta, enfermedad, confianza,
% afectado, severidad, fecha del servidor y la foto reducida (JPEG ≤ 600 KB).

## Firebase

- Reglas de Firestore: `firestore.rules` (cada usuario solo accede a sus datos).
- Publicar reglas y config de Auth: `firebase.cmd deploy --only "auth,firestore"`
- Datos: `users/{uid}` (perfil), `users/{uid}/plants`, `users/{uid}/analyses`.
