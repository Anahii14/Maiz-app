import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '_shared/services/interaction_manager.dart';
import 'features/ai/services/ai_chat_service.dart';
import 'features/ai/services/chat_ai_client.dart';
import 'features/analysis/services/analysis_data_source.dart';
import 'features/analysis/services/analysis_firestore_service.dart';
import 'features/analysis/services/disease_classifier.dart';
import 'features/analysis/services/leaf_analyzer.dart';
import 'features/analysis/recommendations/recommendations_data.dart';
import 'features/auth/manager/auth_manager.dart';
import 'features/auth/services/firebase_auth_service.dart';
import 'features/camera/services/camera_service.dart';
import 'features/plants/services/plants_data_source.dart';
import 'features/plants/services/plants_firestore_service.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerSingleton<InteractionManager>(InteractionManager());
  getIt.registerLazySingleton<FirebaseAuthService>(
    () =>
        FirebaseAuthService(FirebaseAuth.instance, FirebaseFirestore.instance),
  );
  getIt.registerLazySingleton<PlantsFirestoreService>(
    () => PlantsFirestoreService(FirebaseFirestore.instance),
  );
  getIt.registerLazySingleton<PlantsDataSource>(
    () => getIt<PlantsFirestoreService>(),
  );
  getIt.registerLazySingleton<AnalysisFirestoreService>(
    () => AnalysisFirestoreService(FirebaseFirestore.instance),
  );
  getIt.registerLazySingleton<AnalysisDataSource>(
    () => getIt<AnalysisFirestoreService>(),
  );
  // Modelo TFLite real (offline). Se carga la primera vez que se analiza.
  getIt.registerLazySingleton<LeafAnalyzer>(
    () => LeafAnalyzer(createDiseaseClassifier()),
  );
  // Textos y dosis de recomendaciones (recomendaciones.json, sin internet).
  getIt.registerLazySingleton<RecommendationsRepository>(
    () => RecommendationsRepository(),
  );
  getIt.registerLazySingleton<CameraService>(() => CameraService());
  getIt.registerLazySingleton<AiChatService>(
    () => AiChatService(repository: getIt<RecommendationsRepository>()),
  );
  // Chat con IA real (Gemini vía Firebase AI Logic; sin API key en la app).
  getIt.registerLazySingleton<ChatAiClient>(() => GeminiChatClient());
  getIt.registerLazySingletonAsync<AuthManager>(
    () => AuthManager(authService: getIt<FirebaseAuthService>()).init(),
    dispose: (manager) => manager.dispose(),
  );
}
