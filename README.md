# AgroCare (mi_app)

App Flutter para detectar enfermedades del maíz. Usa Firebase (Authentication + Firestore)
en el proyecto **agrocare-maiz-tesis**.

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

## Firebase

- Reglas de Firestore: `firestore.rules` (cada usuario solo accede a sus datos).
- Publicar reglas y config de Auth: `firebase.cmd deploy --only "auth,firestore"`
- Datos: `users/{uid}` (perfil), `users/{uid}/plants`, `users/{uid}/analyses`.
