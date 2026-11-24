import 'package:flutter/material.dart';

import '../../analysis/model/leaf_diagnosis.dart' show claseSana;
import '../../analysis/pages/recommendations_page.dart';
import '../model/library_entry.dart';

/// Detalle de una enfermedad o problema: síntomas, causas, manejo y
/// prevención, en tarjetas que se abren y cierran.
class DiseaseDetailPage extends StatelessWidget {
  final LibraryEntry entry;
  final String notice;

  const DiseaseDetailPage({super.key, required this.entry, this.notice = ''});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = entry.modelLabel;
    final hasRecommendations = label != null && label != claseSana;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: entry.color,
            foregroundColor: Colors.white,
            // El nombre arriba solo aparece al bajar (cuando se encoge la
            // cabecera); antes ya se ve grande en la cabecera.
            title: Builder(
              builder: (context) {
                final bar = context
                    .dependOnInheritedWidgetOfExactType<
                      FlexibleSpaceBarSettings
                    >();
                final collapsed =
                    bar == null || bar.currentExtent <= bar.minExtent + 30;
                return AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(entry.name),
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              // El título solo aparece al bajar; arriba se ve el diseño.
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [entry.color.withValues(alpha: 0.7), entry.color],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'lib-${entry.id}',
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Icon(
                              entry.icon,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (entry.scientificName.isNotEmpty)
                                Text(
                                  entry.scientificName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _WhiteTag(entry.type.label),
                                  for (final p in entry.partNames) _WhiteTag(p),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                Text(
                  entry.summary,
                  style: const TextStyle(fontSize: 17, height: 1.4),
                ),
                if (entry.detectedByApp) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_camera_rounded,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'La app puede reconocer esto con una foto de la hoja.',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        if (hasRecommendations) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecommendationsPage(
                                  label: label,
                                  severity: null,
                                  partial: false,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.medical_services_outlined),
                            label: const Text('Ver recomendaciones completas'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.visibility_rounded,
                  title: entry.type == LibraryType.sana
                      ? 'Cómo se ve'
                      : 'Síntomas: cómo reconocerla',
                  color: entry.color,
                  items: entry.symptoms,
                  initiallyExpanded: true,
                ),
                _Section(
                  icon: Icons.help_outline_rounded,
                  title: entry.type == LibraryType.sana
                      ? '¿Por qué está sana?'
                      : '¿Por qué aparece?',
                  color: const Color(0xFF6D4C41),
                  items: entry.causes,
                  initiallyExpanded: true,
                ),
                _Section(
                  icon: Icons.medical_services_outlined,
                  title: '¿Qué hacer?',
                  color: const Color(0xFFC62828),
                  items: entry.management,
                ),
                _Section(
                  icon: Icons.shield_outlined,
                  title: 'Cómo prevenirla',
                  color: const Color(0xFF1565C0),
                  items: entry.prevention,
                ),
                if (notice.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB26A00),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(notice)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteTag extends StatelessWidget {
  final String text;

  const _WhiteTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tarjeta que se abre y cierra con una lista de puntos.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> items;
  final bool initiallyExpanded;

  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
