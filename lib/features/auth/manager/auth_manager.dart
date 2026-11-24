import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/errors/exceptions.dart';
import '../../../_shared/services/interaction_manager.dart';
import '../../ai/manager/ai_chat_manager.dart';
import '../../ai/services/ai_chat_service.dart';
import '../../ai/services/chat_ai_client.dart';
import '../../analysis/manager/analysis_manager.dart';
import '../../analysis/services/analysis_data_source.dart';
import '../../camera/manager/camera_manager.dart';
import '../../camera/services/camera_service.dart';
import '../../plants/manager/plants_manager.dart';
import '../../plants/services/plants_data_source.dart';
import '../model/app_user.dart';
import '../model/login_request.dart';
import '../model/register_request.dart';
import '../services/firebase_auth_service.dart';

class AuthManager {
  AuthManager({required FirebaseAuthService authService})
    : _authService = authService;

  final FirebaseAuthService _authService;

  final _userState = ValueNotifier<AppUser?>(null);
  ValueListenable<AppUser?> get userState => _userState;

  StreamSubscription<User?>? _authSubscription;

  late final loginCommand = Command.createAsync<LoginRequest, AppUser>(
    (request) => _authService.login(
      email: request.email.trim(),
      // La contraseña NO se recorta: los espacios forman parte de ella.
      password: request.password,
    ),
    initialValue: AppUser.empty,
  );

  late final registerCommand = Command.createAsync<RegisterRequest, AppUser>((
    request,
  ) async {
    final user = await _authService.register(
      email: request.email.trim(),
      password: request.password,
      name: request.name.trim(),
    );
    // authStateChanges() se dispara antes de guardar el nombre, así que
    // actualizamos la sesión con el nombre correcto.
    await _ensureUserSession(user);
    return user;
  }, initialValue: AppUser.empty);

  late final resetPasswordCommand = Command.createAsync<String, bool>((
    email,
  ) async {
    await _authService.sendPasswordResetEmail(email);
    return true;
  }, initialValue: false);

  late final logoutCommand = Command.createAsyncNoParamNoResult(
    () => _authService.logout(),
  );

  Future<AuthManager> init() async {
    final interaction = di<InteractionManager>();
    loginCommand.errors.listen((error, _) {
      if (error == null) return;
      interaction.showSnackBar(_errorMessage(error), isError: true);
    });
    registerCommand.errors.listen((error, _) {
      if (error == null) return;
      interaction.showSnackBar(_errorMessage(error), isError: true);
    });
    resetPasswordCommand.errors.listen((error, _) {
      if (error == null) return;
      interaction.showSnackBar(_errorMessage(error), isError: true);
    });
    resetPasswordCommand.results.listen((result, _) {
      if (result.hasData && result.data == true) {
        interaction.showSnackBar(
          'Enlace de recuperación enviado. Revisa tu correo.',
        );
      }
    });

    _authSubscription = _authService.authStateChanges().listen((user) async {
      if (user == null) {
        await _clearUserSession();
        _userState.value = null;
        return;
      }
      await _ensureUserSession(_authService.mapUser(user));
    });

    final current = _authService.currentUser;
    if (current != null) {
      await _ensureUserSession(_authService.mapUser(current));
    }

    return this;
  }

  void dispose() {
    _authSubscription?.cancel();
    _userState.dispose();
  }

  // Cola para que abrir/cerrar la sesión nunca ocurra dos veces a la vez
  // (por ejemplo, authStateChanges y el registro llegan casi juntos).
  Future<void> _sessionQueue = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _sessionQueue.then((_) => action());
    _sessionQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _ensureUserSession(AppUser user) =>
      _enqueue(() => _openUserSession(user));

  Future<void> _clearUserSession() => _enqueue(_closeUserSession);

  Future<void> _openUserSession(AppUser user) async {
    if (di.isRegistered<AppUser>()) {
      final current = di<AppUser>();
      if (current.id == user.id) {
        if (current.name != user.name || current.email != user.email) {
          di.unregister<AppUser>();
          di.registerSingleton<AppUser>(user);
        }
        _userState.value = user;
        return;
      }
    }
    await _dropSessionScope();

    di.pushNewScope(scopeName: _sessionScope);

    di.registerSingleton<AppUser>(user);

    final plantsManager = await PlantsManager(
      user: user,
      service: di<PlantsDataSource>(),
    ).init();
    di.registerSingleton<PlantsManager>(
      plantsManager,
      dispose: (manager) => manager.dispose(),
    );

    final analysisManager = await AnalysisManager(
      userId: user.id,
      service: di<AnalysisDataSource>(),
      plantsManager: plantsManager,
    ).init();
    di.registerSingleton<AnalysisManager>(
      analysisManager,
      dispose: (manager) => manager.dispose(),
    );

    di.registerLazySingleton<CameraManager>(
      () => CameraManager(
        cameraService: di<CameraService>(),
        plantsManager: plantsManager,
        analysisManager: analysisManager,
      ),
    );

    di.registerLazySingleton<AiChatManager>(
      () => AiChatManager(
        chatService: di<AiChatService>(),
        plantsManager: plantsManager,
        analysisManager: analysisManager,
        aiClient: di.isRegistered<ChatAiClient>() ? di<ChatAiClient>() : null,
      ),
      dispose: (manager) => manager.dispose(),
    );

    _userState.value = user;
  }

  Future<void> _closeUserSession() async {
    await _dropSessionScope();
    _userState.value = null;
  }

  static const _sessionScope = 'user-session';

  /// Quita la zona de la sesión solo si existe (nunca la zona base de la app).
  Future<void> _dropSessionScope() async {
    if (di.hasScope(_sessionScope)) {
      await di.dropScope(_sessionScope);
    }
  }

  String _errorMessage(CommandError error) {
    final underlying = error.error;
    if (underlying is ServerException) return underlying.message;
    return underlying.toString();
  }
}
