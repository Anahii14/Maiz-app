import 'package:flutter/material.dart';

import '../../plants/manager/plants_manager.dart';
import '../manager/ai_chat_manager.dart';
import '../pages/ai_chat_page.dart';
import 'package:watch_it/watch_it.dart';

/// Botón verde flotante que abre el chat con IA a pantalla completa.
class FloatingAiChat extends StatelessWidget {
  /// Distancia extra desde abajo (por ejemplo, el alto de la barra inferior).
  final double bottomOffset;

  const FloatingAiChat({super.key, this.bottomOffset = 0});

  @override
  Widget build(BuildContext context) {
    // Evita mostrar el botón si la sesión todavía no está lista.
    if (!di.isRegistered<AiChatManager>() ||
        !di.isRegistered<PlantsManager>()) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    // Respeta la barra del sistema (gestos / botones de Android).
    final bottom = 16 + bottomOffset + MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        Positioned(
          right: 16,
          bottom: bottom,
          child: FloatingActionButton(
            heroTag: 'chat-ia',
            tooltip: 'Chat IA',
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AIChatPage())),
            child: const Icon(Icons.chat_rounded),
          ),
        ),
      ],
    );
  }
}
