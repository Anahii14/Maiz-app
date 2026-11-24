import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../analysis/manager/analysis_manager.dart';
import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_dto.dart';
import '../config/chat_prompt.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_ai_client.dart';

class AiChatManager {
  AiChatManager({
    required AiChatService chatService,
    required PlantsManager plantsManager,
    required AnalysisManager analysisManager,
    ChatAiClient? aiClient,
  }) : _chatService = chatService,
       _plantsManager = plantsManager,
       _analysisManager = analysisManager,
       _aiClient = aiClient;

  final AiChatService _chatService;
  final PlantsManager _plantsManager;
  final AnalysisManager _analysisManager;

  /// IA real. Si es null (por ejemplo en las pruebas), se usan las
  /// respuestas básicas sin internet.
  final ChatAiClient? _aiClient;

  final messages = ValueNotifier<List<ChatMessage>>([
    ChatMessage(
      text:
          '¡Hola! 🌽 Soy tu asistente de maíz. Pregúntame sobre '
          'enfermedades de las hojas, riego, abono o plagas. Si eliges una '
          'planta arriba, te respondo según sus datos.',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ]);

  /// true mientras la IA prepara la respuesta ("escribiendo…").
  final isTyping = ValueNotifier<bool>(false);

  final selectedPlantId = ValueNotifier<String?>(null);

  ValueListenable<List<PlantEntry>> get plants => _plantsManager.plants;

  void selectPlant(String? plantId) {
    selectedPlantId.value = plantId;
  }

  PlantDto? get _selectedPlant {
    final plantId = selectedPlantId.value;
    if (plantId == null) return null;
    for (final entry in _plantsManager.plants.value) {
      if (entry.id == plantId) return entry.dto;
    }
    return null;
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isTyping.value) return;

    // Historial ANTES de este mensaje (para la memoria de la IA).
    final history = [
      for (final m in messages.value) ChatTurn(text: m.text, isUser: m.isUser),
    ];
    final recent = history.length > ChatAiConfig.historyMessages
        ? history.sublist(history.length - ChatAiConfig.historyMessages)
        : history;

    _add(ChatMessage(text: trimmed, isUser: true, timestamp: DateTime.now()));
    isTyping.value = true;

    final plant = _selectedPlant;
    final analyses = _analysisManager.analyses.value.map((e) => e.dto).toList();

    try {
      final client = _aiClient;
      if (client == null) throw StateError('IA no configurada');

      final context = _chatService.buildContext(
        plant: plant,
        recentAnalyses: analyses,
      );
      final prompt = context.isEmpty ? trimmed : '$context\nPregunta: $trimmed';

      final buffer = StringBuffer();
      var started = false;
      await for (final piece in client.reply(
        history: recent,
        message: prompt,
      )) {
        buffer.write(piece);
        final reply = ChatMessage(
          text: buffer.toString(),
          isUser: false,
          timestamp: DateTime.now(),
        );
        if (!started) {
          started = true;
          _add(reply);
        } else {
          _replaceLast(reply);
        }
      }
      if (!started) throw StateError('respuesta vacía');
    } catch (e) {
      debugPrint('[CHAT IA] error: $e');
      // Respaldo sin internet: siempre hay una respuesta.
      final basic = _chatService.generateResponse(
        userMessage: trimmed,
        plant: plant,
        recentAnalyses: analyses,
      );
      final last = messages.value.last;
      final reply = ChatMessage(
        text: _aiClient == null
            ? basic
            : '${aiErrorMessage(e)} Te dejo una respuesta básica:\n\n$basic',
        isUser: false,
        timestamp: DateTime.now(),
      );
      // Si la IA alcanzó a escribir algo, se reemplaza ese texto a medias.
      if (!last.isUser) {
        _replaceLast(reply);
      } else {
        _add(reply);
      }
    } finally {
      isTyping.value = false;
    }
  }

  /// Explica en palabras simples por qué no respondió la IA.
  @visibleForTesting
  static String aiErrorMessage(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('attestation') || t.contains('app check')) {
      return 'Este celular todavía no está autorizado para usar la IA '
          '(falta registrarlo en Firebase App Check).';
    }
    if (t.contains('quota') || t.contains('429') || t.contains('exhausted')) {
      return 'La IA recibió demasiadas preguntas. Intenta en unos minutos.';
    }
    if (e is TimeoutException) {
      return 'La IA tardó demasiado en responder.';
    }
    return 'No pude conectarme con la IA (revisa tu internet).';
  }

  void _add(ChatMessage m) => messages.value = [...messages.value, m];

  void _replaceLast(ChatMessage m) {
    final list = [...messages.value];
    list[list.length - 1] = m;
    messages.value = list;
  }

  void dispose() {
    messages.dispose();
    isTyping.dispose();
    selectedPlantId.dispose();
  }
}
