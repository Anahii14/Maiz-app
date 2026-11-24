import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/features/ai/manager/ai_chat_manager.dart';
import 'package:mi_app/features/ai/pages/ai_chat_page.dart';
import 'package:mi_app/features/ai/services/ai_chat_service.dart';
import 'package:mi_app/features/ai/services/chat_ai_client.dart';
import 'package:mi_app/features/analysis/manager/analysis_manager.dart';
import 'package:mi_app/features/auth/model/app_user.dart';
import 'package:mi_app/features/plants/manager/plants_manager.dart';

import '../helpers/in_memory_analysis_data_source.dart';
import '../helpers/in_memory_plants_data_source.dart';

/// IA de prueba: responde en pedazos y guarda lo que recibió.
class _FakeAi implements ChatAiClient {
  final List<String> pieces;
  final bool fail;
  List<ChatTurn>? lastHistory;
  String? lastMessage;
  Completer<void>? gate;

  _FakeAi(this.pieces, {this.fail = false});

  @override
  Stream<String> reply({
    required List<ChatTurn> history,
    required String message,
  }) async* {
    lastHistory = history;
    lastMessage = message;
    if (gate != null) await gate!.future;
    if (fail) throw Exception('sin internet');
    for (final p in pieces) {
      yield p;
    }
  }
}

void main() {
  const user = AppUser(id: 'u1', email: 'a@test.com', name: 'Test');
  late InMemoryPlantsDataSource plantsSource;
  late PlantsManager plants;
  late AnalysisManager analyses;

  setUp(() {
    plantsSource = InMemoryPlantsDataSource();
    plants = PlantsManager(user: user, service: plantsSource);
    analyses = AnalysisManager(
      userId: user.id,
      service: InMemoryAnalysisDataSource(),
      plantsManager: plants,
    );
  });

  tearDown(() => plantsSource.dispose());

  AiChatManager build(ChatAiClient? ai) => AiChatManager(
    chatService: AiChatService(),
    plantsManager: plants,
    analysisManager: analyses,
    aiClient: ai,
  );

  group('Chat con IA (caja blanca)', () {
    test('une los pedazos de la IA en UNA respuesta completa', () async {
      final ai = _FakeAi(['La roya ', 'se controla ', 'así: 1. Revisa.']);
      final chat = build(ai);
      await chat.sendMessage('¿Qué es la roya?');

      final msgs = chat.messages.value;
      expect(msgs.length, 3); // saludo + pregunta + respuesta
      expect(msgs[1].isUser, isTrue);
      expect(msgs.last.text, 'La roya se controla así: 1. Revisa.');
      expect(chat.isTyping.value, isFalse);
    });

    test(
      'envía el historial para que la IA recuerde la conversación',
      () async {
        final ai = _FakeAi(['Respuesta 1']);
        final chat = build(ai);
        await chat.sendMessage('Pregunta 1');
        await chat.sendMessage('Pregunta 2');

        final h = ai.lastHistory!;
        expect(h.map((t) => t.text), contains('Pregunta 1'));
        expect(h.map((t) => t.text), contains('Respuesta 1'));
        expect(h.last.isUser, isFalse);
        expect(ai.lastMessage, 'Pregunta 2');
      },
    );

    test(
      'muestra "escribiendo" mientras espera y no envía dos a la vez',
      () async {
        final ai = _FakeAi(['ok'])..gate = Completer<void>();
        final chat = build(ai);
        final first = chat.sendMessage('Hola');
        expect(chat.isTyping.value, isTrue);

        await chat.sendMessage('Otra'); // se ignora mientras escribe
        expect(chat.messages.value.where((m) => m.isUser).length, 1);

        ai.gate!.complete();
        await first;
        expect(chat.isTyping.value, isFalse);
      },
    );

    test('si la IA falla, responde igual con la ayuda básica', () async {
      final chat = build(_FakeAi([], fail: true));
      await chat.sendMessage('¿Cuándo debería regar?');

      final last = chat.messages.value.last;
      expect(last.isUser, isFalse);
      expect(last.text, contains('No pude conectarme con la IA'));
      expect(last.text, contains('riego'));
    });
  });

  test('explica por qué falló la IA en palabras simples', () {
    expect(
      AiChatManager.aiErrorMessage(Exception('403 App attestation failed.')),
      contains('no está autorizado'),
    );
    expect(
      AiChatManager.aiErrorMessage(Exception('429 RESOURCE_EXHAUSTED')),
      contains('demasiadas preguntas'),
    );
    expect(
      AiChatManager.aiErrorMessage(Exception('SocketException')),
      contains('revisa tu internet'),
    );
  });

  group('Formato de las respuestas', () {
    test('negritas y viñetas', () {
      final span = formatChatText(
        'Hola **agricultor**\n- Paso uno',
        const TextStyle(),
      );
      final plain = span.toPlainText();
      expect(plain, 'Hola agricultor\n•  Paso uno');
      final bold = span.children!.whereType<TextSpan>().firstWhere(
        (s) => s.text == 'agricultor',
      );
      expect(bold.style!.fontWeight, FontWeight.w800);
    });
  });
}
