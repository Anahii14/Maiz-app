import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/chat_prompt.dart';

/// Un mensaje anterior de la conversación (para que la IA tenga memoria).
class ChatTurn {
  final String text;
  final bool isUser;

  const ChatTurn({required this.text, required this.isUser});
}

/// Cliente de IA para el chat. Devuelve la respuesta en pedazos (stream)
/// para que el texto vaya apareciendo mientras la IA escribe.
abstract class ChatAiClient {
  Stream<String> reply({
    required List<ChatTurn> history,
    required String message,
  });
}

/// Texto que se agrega si la IA llegó al límite de largo.
const chatCutOffNote =
    '\n\n_(La respuesta era muy larga y se cortó. Escribe "continúa" '
    'para ver el resto.)_';

/// Gemini a través de **Firebase AI Logic**.
///
/// SEGURIDAD: aquí NO hay ninguna API key. La app habla con Firebase usando
/// la configuración normal del proyecto (la misma de Auth y Firestore), y es
/// Firebase quien llama a Gemini con la clave guardada en sus servidores.
/// Además, cada pedido lleva un token de App Check (ver firebase_initializer).
class GeminiChatClient implements ChatAiClient {
  GenerativeModel? _checked;
  GenerativeModel? _unchecked;

  /// Hasta cuándo se pregunta sin App Check, porque este celular no pudo
  /// obtener la prueba (no está registrado o Firebase lo frenó un rato).
  /// Pasado ese tiempo se vuelve a intentar con App Check.
  DateTime? _skipUntil;
  static const _retryAppCheckAfter = Duration(minutes: 10);

  bool get _skipAppCheck =>
      _skipUntil != null && DateTime.now().isBefore(_skipUntil!);

  /// FirebaseAI guarda una sola conexión por "app" de Firebase. Para poder
  /// preguntar SIN App Check se usa una segunda app con la misma
  /// configuración (si no, reutilizaría la conexión que sí lo pide).
  static Future<FirebaseApp> _appWithoutCheck() async {
    const name = 'ia-sin-app-check';
    for (final app in Firebase.apps) {
      if (app.name == name) return app;
    }
    return Firebase.initializeApp(name: name, options: Firebase.app().options);
  }

  GenerativeModel _build(FirebaseAppCheck? appCheck, {FirebaseApp? app}) =>
      FirebaseAI.googleAI(app: app, appCheck: appCheck).generativeModel(
        model: ChatAiConfig.model,
        systemInstruction: Content.system(chatSystemPrompt),
        generationConfig: GenerationConfig(
          maxOutputTokens: ChatAiConfig.maxOutputTokens,
          temperature: ChatAiConfig.temperature,
        ),
      );

  /// Con App Check (lo normal) o sin él si el celular no está registrado.
  /// Si en Firebase App Check está "aplicado" (obligatorio), la pregunta sin
  /// prueba se rechaza igual: la protección no se pierde. Si NO está
  /// aplicado, cualquier celular puede usar la IA sin registrar códigos.
  Future<GenerativeModel> _gemini() async {
    if (!_skipAppCheck) return _checked ??= _build(FirebaseAppCheck.instance);
    return _unchecked ??= _build(null, app: await _appWithoutCheck());
  }

  /// El error viene de App Check del celular (antes de llegar a Firebase).
  static bool _isLocalAppCheckError(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('firebase_app_check') || t.contains('attestation');
  }

  @override
  Stream<String> reply({
    required List<ChatTurn> history,
    required String message,
  }) async* {
    final contents = <Content>[
      for (final turn in _validHistory(history))
        turn.isUser
            ? Content.text(turn.text)
            : Content.model([TextPart(turn.text)]),
      Content.text(message),
    ];

    Future<Stream<GenerateContentResponse>> request() async => (await _gemini())
        .generateContentStream(contents)
        .timeout(ChatAiConfig.timeout);

    // Se lee la respuesta pedazo a pedazo. Si el PRIMER pedazo falla porque
    // este celular no tiene App Check, se repite una sola vez sin la prueba.
    var it = StreamIterator(await request());
    bool more;
    try {
      more = await it.moveNext();
    } catch (e) {
      if (_skipAppCheck || !_isLocalAppCheckError(e)) rethrow;
      debugPrint('[CHAT IA] celular sin App Check: se pregunta sin la prueba');
      _skipUntil = DateTime.now().add(_retryAppCheckAfter);
      await it.cancel();
      it = StreamIterator(await request());
      more = await it.moveNext();
    }

    FinishReason? finish;
    while (more) {
      final chunk = it.current;
      final candidates = chunk.candidates;
      if (candidates.isNotEmpty && candidates.first.finishReason != null) {
        finish = candidates.first.finishReason;
      }
      final text = chunk.text;
      if (text != null && text.isNotEmpty) yield text;
      more = await it.moveNext();
    }
    debugPrint('[CHAT IA] fin: $finish');
    if (finish == FinishReason.maxTokens) yield chatCutOffNote;
  }

  /// Gemini pide que la conversación empiece con el usuario y que los turnos
  /// se alternen: se quita el saludo inicial y se unen turnos repetidos.
  static List<ChatTurn> _validHistory(List<ChatTurn> history) {
    final out = <ChatTurn>[];
    for (final t in history) {
      if (t.text.trim().isEmpty) continue;
      if (out.isEmpty && !t.isUser) continue;
      if (out.isNotEmpty && out.last.isUser == t.isUser) {
        out[out.length - 1] = ChatTurn(
          text: '${out.last.text}\n\n${t.text}',
          isUser: t.isUser,
        );
      } else {
        out.add(t);
      }
    }
    return out;
  }
}
