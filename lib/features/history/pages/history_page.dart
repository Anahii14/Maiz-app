import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../analysis/manager/analysis_manager.dart';
import '../../analysis/config/disease_catalog.dart';
import '../../analysis/model/analysis_dto.dart';
import '../../analysis/pages/analysis_result_page.dart';

enum HistoryFilter { todos, hoja, terreno }

class HistoryPage extends WatchingStatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.todos;

  @override
  Widget build(BuildContext context) {
    // Evitar acceder al manager si aún no está registrado/listo.
    if (!di.isRegistered<AnalysisManager>()) {
      return const Center(child: CircularProgressIndicator());
    }

    // Anotación explícita para evitar 'prefer_typing_uninitialized_variables'
    late final List<AnalysisEntry> analyses;
    try {
      analyses = watchValue((AnalysisManager m) => m.analyses);
    } on StateError {
      // Manager aún no listo: mostrar indicador y reintentar en rebuild.
      return const Center(child: CircularProgressIndicator());
    }

    final colors = Theme.of(context).colorScheme;

    final filtered = analyses.where((entry) {
      switch (_filter) {
        case HistoryFilter.todos:
          return true;
        case HistoryFilter.hoja:
          return entry.dto.type == AnalysisType.hoja;
        case HistoryFilter.terreno:
          return entry.dto.type == AnalysisType.terreno;
      }
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        SegmentedButton<HistoryFilter>(
          segments: const [
            ButtonSegment(value: HistoryFilter.todos, label: Text('Todos')),
            ButtonSegment(value: HistoryFilter.hoja, label: Text('Hoja')),
            ButtonSegment(value: HistoryFilter.terreno, label: Text('Terreno')),
          ],
          selected: {_filter},
          onSelectionChanged: (value) => setState(() => _filter = value.first),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No hay análisis registrados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          )
        else
          ...filtered.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnalysisHistoryCard(entry: entry),
            ),
          ),
      ],
    );
  }
}

class _AnalysisHistoryCard extends StatelessWidget {
  final AnalysisEntry entry;

  const _AnalysisHistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dto = entry.dto;
    final colors = Theme.of(context).colorScheme;
    final info = DiseaseCatalog.of(dto.label);
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultPage(result: ResultView.fromDto(dto)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: dto.photo != null
                      ? Image.memory(dto.photo!, fit: BoxFit.cover)
                      : Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(info.icon, color: info.color),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(info.icon, size: 18, color: info.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            info.name,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: info.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dto.plantName} · ${_formatDate(dto.date)}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!dto.isHealthy && dto.affectionPercent != null)
                          _InfoTag(
                            label:
                                '${dto.affectionPercent!.toStringAsFixed(1)}% afectado',
                          ),
                        if (!dto.isHealthy)
                          SeverityBadge(severity: dto.severity, compact: true),
                        _InfoTag(
                          label:
                              'Confianza ${(dto.confidence * 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} $h:$min';
  }
}

class _InfoTag extends StatelessWidget {
  final String label;

  const _InfoTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}
