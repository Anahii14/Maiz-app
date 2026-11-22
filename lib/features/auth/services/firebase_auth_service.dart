import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../_shared/errors/exceptions.dart';
import '../model/app_user.dart';

class FirebaseAuthService {
  final FirebaseAuth firebaseAuth;
  FirebaseFirestore? _firestore;

  // Firestore se obtiene solo cuando se usa (permite probar sin Firebase).
  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  FirebaseAuthService(this.firebaseAuth, [FirebaseFirestore? firestore])
      : _firestore = firestore;

  Stream<User?> authStateChanges() => firebaseAuth.authStateChanges();

  User? get currentUser => firebaseAuth.currentUser;

  AppUser mapUser(User user) {
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? user.email ?? 'Usuario',
    );
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw ServerException('No se pudo iniciar sesión.');
      }
      // Cuentas antiguas o registros que fallaron a medias pueden no tener
      // perfil en Firestore: lo creamos si falta (no bloquea el inicio).
      await _ensureProfile(user);
      return mapUser(user);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapError(e));
    }
  }

  Future<void> _ensureProfile(User user) async {
    try {
      final ref = firestore.collection('users').doc(user.uid);
      final snapshot = await ref.get();
      if (snapshot.exists) return;
      await ref.set({
        'name': (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!.trim()
            : (user.email ?? 'Usuario'),
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // El perfil es secundario: si falla, el usuario igual puede entrar.
    }
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw ServerException('No se pudo crear la cuenta.');
      }
      final cleanName = name.trim();
      await user.updateDisplayName(cleanName);
      try {
        await firestore.collection('users').doc(user.uid).set({
          'name': cleanName,
          'email': user.email ?? email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        // La cuenta ya existe en Authentication; al iniciar sesión se
        // volverá a intentar crear el perfil (ver _ensureProfile).
        throw ServerException(
          'Tu cuenta se creó, pero no se pudo guardar tu perfil '
          '(${e.code}). Intenta iniciar sesión de nuevo.',
        );
      }
      // Devolvemos el usuario con el nombre recién guardado
      // (user.displayName puede no estar actualizado todavía).
      return AppUser(id: user.uid, email: user.email ?? email, name: cleanName);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapError(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapError(e));
    }
  }

  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  String _mapError(FirebaseAuthException e) => mapFirebaseAuthError(e);
}

String mapFirebaseAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Correo inválido.';
    case 'missing-email':
      return 'Escribe tu correo electrónico.';
    case 'missing-password':
      return 'Escribe tu contraseña.';
    case 'channel-error':
      return 'Completa el correo y la contraseña.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-login-credentials':
      return 'Credenciales incorrectas.';
    case 'email-already-in-use':
      return 'Este correo ya está registrado.';
    case 'weak-password':
      return 'La contraseña debe tener al menos 6 caracteres.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión a internet. Revisa tu red.';
    case 'operation-not-allowed':
      return 'El registro con correo no está activado en Firebase.';
    case 'api-key-not-valid':
    case 'invalid-api-key':
    case 'app-not-authorized':
    case 'unauthorized-domain':
      return 'La configuración de Firebase no es válida para esta app.';
    default:
      return e.message ?? 'Error de autenticación.';
  }
}
