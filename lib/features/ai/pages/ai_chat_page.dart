import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/theme/corn_palette.dart';
import '../../plants/model/plant_dto.dart';
import '../manager/ai_chat_manager.dart';
import '../services/ai_chat_service.dart';

/// Chat con IA a pantalla completa.
class AIChatPage extends WatchingStatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _suggestions = [
    '¿Cómo está mi planta?',
    '¿Cómo reconozco la roya?',
    '¿Qué hago con la mancha gris?',
    '¿Cada cuánto riego mi maíz?',
    '¿Cómo abono mi maíz?',
    '¿Cómo prevengo enfermedades?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    di<AiChatManager>().sendMessage(text);
    _input.clear();
    _toBottom();
  }

  /// La lista está invertida: la posición 0 es el último mensaje.
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!di.isRegistered<AiChatManager>()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final manager = di<AiChatManager>();
    final messages = watchValue((AiChatManager m) => m.messages);
    final typing = watchValue((AiChatManager m) => m.isTyping);
    final plants = watchValue((AiChatManager m) => m.plants);
    final selectedPlantId = watchValue((AiChatManager m) => m.selectedPlantId);

    // Cada vez que llega un mensaje o un pedazo de respuesta, baja al final.
    registerHandler(
      select: (AiChatManager m) => m.messages,
      handler: (_, _, _) => _toBottom(),
    );

    // "Escribiendo…" solo hasta que aparece el primer pedazo de respuesta.
    final showTyping = typing && messages.isNotEmpty && messages.last.isUser;
    final items = messages.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6EF),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            _BotAvatar(size: 38),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente de maíz',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  'Con inteligencia artificial',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _PlantSelector(
            plants: plants,
            selectedId: selectedPlantId,
            onSelect: manager.selectPlant,
          ),
          const Divider(height: 1),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: items.length + (showTyping ? 1 : 0),
                itemBuilder: (_, i) {
                  if (showTyping) {
                    if (i == 0) return const _TypingBubble();
                    i -= 1;
                  }
                  return _MessageBubble(message: items[i]);
                },
              ),
            ),
          ),
          _SuggestionsRow(
            suggestions: _suggestions,
            enabled: !typing,
            onTap: _send,
          ),
          _InputBar(controller: _input, enabled: !typing, onSend: _send),
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  final double size;

  const _BotAvatar({this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [CornPalette.goldLight, CornPalette.gold],
        ),
      ),
      child: Icon(
        Icons.eco_rounded,
        size: size * 0.58,
        color: CornPalette.leafDark,
      ),
    );
  }
}

/// Fila compacta para elegir sobre qué planta se pregunta.
class _PlantSelector extends StatelessWidget {
  final List<PlantEntry> plants;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _PlantSelector({
    required this.plants,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? id, IconData icon) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selectedId == id,
        onSelected: (_) => onSelect(id),
        showCheckmark: false,
        selectedColor: CornPalette.leafLight.withValues(alpha: 0.3),
      ),
    );

    return Container(
      color: Colors.white,
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          chip('Pregunta general', null, Icons.forum_rounded),
          for (final p in plants) chip(p.dto.name, p.id, Icons.grass_rounded),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: user ? CornPalette.leaf : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(user ? 18 : 4),
          bottomRight: Radius.circular(user ? 4 : 18),
        ),
        boxShadow: user
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            formatChatText(
              message.text,
              TextStyle(
                fontSize: 15.5,
                height: 1.4,
                color: user ? Colors.white : const Color(0xFF1F2A1F),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _time(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: user ? Colors.white70 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[const _BotAvatar(), const SizedBox(width: 6)],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Convierte el formato simple de la IA en texto con estilo:
/// **negrita**, _cursiva_, viñetas "- " / "* " y títulos "#".
TextSpan formatChatText(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  final inline = RegExp(r'\*\*(.+?)\*\*|(?<![\w])_(.+?)_(?![\w])');
  for (var li = 0; li < lines.length; li++) {
    var line = lines[li];
    var style = base;
    final heading = RegExp(r'^\s*#{1,6}\s+').firstMatch(line);
    if (heading != null) {
      line = line.substring(heading.end);
      style = base.copyWith(fontWeight: FontWeight.w800);
    }
    final bullet = RegExp(r'^(\s*)[-*•]\s+').firstMatch(line);
    if (bullet != null) {
      line = '${bullet.group(1)}•  ${line.substring(bullet.end)}';
    }
    var pos = 0;
    for (final m in inline.allMatches(line)) {
      if (m.start > pos) {
        spans.add(TextSpan(text: line.substring(pos, m.start), style: style));
      }
      spans.add(
        m.group(1) != null
            ? TextSpan(
                text: m.group(1),
                style: style.copyWith(fontWeight: FontWeight.w800),
              )
            : TextSpan(
                text: m.group(2),
                style: style.copyWith(fontStyle: FontStyle.italic),
              ),
      );
      pos = m.end;
    }
    if (pos < line.length) {
      spans.add(TextSpan(text: line.substring(pos), style: style));
    }
    if (li < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
  }
  return TextSpan(children: spans, style: base);
}

/// Burbuja con tres puntos que suben y bajan: "escribiendo…".
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _BotAvatar(),
          const SizedBox(width: 6),
          Semantics(
            label: 'El asistente está escribiendo',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Transform.translate(
                        offset: Offset(0, -4 * _bounce(_c.value - i * 0.18)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: CornPalette.goldDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Text(
                      'Escribiendo…',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _bounce(double t) {
    final x = t % 1;
    return x < 0.4 ? Curves.easeInOut.transform(1 - (x - 0.2).abs() / 0.2) : 0;
  }
}

/// Sugerencias en UNA fila que se desliza de lado (no tapa los mensajes).
class _SuggestionsRow extends StatelessWidget {
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onTap;

  const _SuggestionsRow({
    required this.suggestions,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(suggestions[i], style: const TextStyle(fontSize: 13)),
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.white,
          side: BorderSide(color: CornPalette.leaf.withValues(alpha: 0.3)),
          onPressed: enabled ? () => onTap(suggestions[i]) : null,
        ),
      ),
    );
  }
}

/// Barra de escritura FIJA abajo (sube sola cuando aparece el teclado).
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? onSend : null,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu pregunta sobre el maíz…',
                    filled: true,
                    fillColor: const Color(0xFFF1F5EE),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: CornPalette.leaf),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Enviar',
                style: IconButton.styleFrom(
                  backgroundColor: CornPalette.leaf,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: enabled ? () => onSend(controller.text) : null,
                icon: enabled
                    ? const Icon(Icons.send_rounded)
                    : const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
