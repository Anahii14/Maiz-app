import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/widgets/corn_art.dart';
import '../../analysis/config/disease_catalog.dart';
import '../../analysis/manager/analysis_manager.dart';
import '../../analysis/model/analysis_dto.dart';
import '../../analysis/model/leaf_diagnosis.dart';
import '../../analysis/pages/analysis_result_page.dart';
import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_status.dart';
import '../../reports/analysis_report.dart';
import '../../reports/pdf_report_page.dart';

class HistoryPage extends WatchingStatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryFilters _filters = HistoryFilters.none;

  @override
  Widget build(BuildContext context) {
    if (!di.isRegistered<AnalysisManager>()) {
      return const Center(child: CircularProgressIndicator());
    }
    late final List<AnalysisEntry> analyses;
    try {
      analyses = watchValue((AnalysisManager m) => m.analyses);
    } on StateError {
      return const Center(child: CircularProgressIndicator());
    }

    final colors = Theme.of(context).colorScheme;
    final filtered = analyses.where((e) => _filters.matches(e.dto)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _filters.isActive
                        ? '${filtered.length} de ${analyses.length} análisis'
                        : '${analyses.length} análisis',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: analyses.isEmpty
                  ? null
                  : () => _showPdfOptions(analyses, filtered),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Descargar PDF'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FiltersBar(
          filters: _filters,
          analyses: analyses,
          onChanged: (f) => setState(() => _filters = f),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 44,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analyses.isEmpty
                        ? 'Aún no hay análisis. Toca "Nuevo" para revisar una hoja.'
                        : 'No hay análisis con estos filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < filtered.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeSlideIn(
                delayMs: (i * 50).clamp(0, 250),
                child: _AnalysisHistoryCard(
                  entry: filtered[i],
                  onPdf: () => _openPdf(
                    [filtered[i]],
                    title: 'Reporte de análisis',
                    kind: 'analisis',
                  ),
                ),
              ),
            ),
      ],
    );
  }

  PlantStatus? _statusOf(String plantId) {
    if (!di.isRegistered<PlantsManager>()) return null;
    for (final p in di<PlantsManager>().plants.value) {
      if (p.id == plantId) return p.dto.status;
    }
    return null;
  }

  void _openPdf(
    List<AnalysisEntry> entries, {
    required String title,
    required String kind,
    String? filterText,
  }) {
    openAnalysisPdf(
      context,
      items: [
        for (final e in entries)
          AnalysisReportItem.fromDto(e.dto, status: _statusOf(e.dto.plantId)),
      ],
      title: title,
      fileKind: kind,
      filterText: filterText,
    );
  }

  /// Las 3 opciones: todo, filtrado o un análisis.
  void _showPdfOptions(List<AnalysisEntry> all, List<AnalysisEntry> filtered) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '¿Qué quieres descargar?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              _PdfOption(
                icon: Icons.library_books_rounded,
                title: 'Todo el historial',
                subtitle: '${all.length} análisis',
                onTap: () {
                  Navigator.pop(sheet);
                  _openPdf(all, title: 'Historial completo', kind: 'historial');
                },
              ),
              _PdfOption(
                icon: Icons.filter_alt_rounded,
                title: 'Solo lo filtrado',
                subtitle: _filters.isActive
                    ? '${filtered.length} análisis · ${_describe(_filters)}'
                    : 'Primero elige un filtro arriba: fecha, enfermedad o planta',
                enabled: _filters.isActive && filtered.isNotEmpty,
                onTap: () {
                  Navigator.pop(sheet);
                  _openPdf(
                    filtered,
                    title: 'Historial filtrado',
                    kind: 'historial_filtrado',
                    filterText: _describe(_filters),
                  );
                },
              ),
              _PdfOption(
                icon: Icons.description_rounded,
                title: 'Un solo análisis',
                subtitle: 'Elige cuál en la lista',
                onTap: () {
                  Navigator.pop(sheet);
                  _pickOne(filtered.isEmpty ? all : filtered);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickOne(List<AnalysisEntry> entries) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Elige el análisis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            for (final e in entries)
              ListTile(
                minVerticalPadding: 12,
                leading: _Thumb(dto: e.dto, size: 48),
                title: Text(DiseaseCatalog.of(e.dto.label).name),
                subtitle: Text(
                  '${e.dto.plantName} · ${_formatDate(e.dto.date)}',
                ),
                trailing: const Icon(Icons.picture_as_pdf_rounded),
                onTap: () {
                  Navigator.pop(sheet);
                  _openPdf([e], title: 'Reporte de análisis', kind: 'analisis');
                },
              ),
          ],
        ),
      ),
    );
  }

  String _describe(HistoryFilters f) {
    final parts = <String>[];
    if (f.from != null || f.to != null) {
      parts.add(
        'del ${f.from == null ? '…' : _formatDay(f.from!)} '
        'al ${f.to == null ? '…' : _formatDay(f.to!)}',
      );
    }
    if (f.label != null) parts.add(DiseaseCatalog.of(f.label!).name);
    if (f.plantId != null) {
      final match = di<AnalysisManager>().analyses.value
          .where((e) => e.dto.plantId == f.plantId)
          .map((e) => e.dto.plantName);
      parts.add('planta ${match.isEmpty ? '' : match.first}');
    }
    return parts.join(' · ');
  }
}

String _formatDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatDate(DateTime d) =>
    '${_formatDay(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Fila de filtros: fecha, enfermedad y planta.
class _FiltersBar extends StatelessWidget {
  final HistoryFilters filters;
  final List<AnalysisEntry> analyses;
  final ValueChanged<HistoryFilters> onChanged;

  const _FiltersBar({
    required this.filters,
    required this.analyses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {for (final a in analyses) a.dto.label}.toList();
    final plants = <String, String>{
      for (final a in analyses) a.dto.plantId: a.dto.plantName,
    };
    final hasDates = filters.from != null || filters.to != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(
            icon: Icons.date_range_rounded,
            label: hasDates
                ? '${filters.from == null ? '…' : _formatDay(filters.from!)} – '
                      '${filters.to == null ? '…' : _formatDay(filters.to!)}'
                : 'Fecha',
            active: hasDates,
            onTap: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                helpText: 'Elige las fechas',
                initialDateRange: hasDates
                    ? DateTimeRange(
                        start: filters.from ?? DateTime(2020),
                        end: filters.to ?? now,
                      )
                    : null,
              );
              if (range != null) {
                onChanged(filters.copyWith(from: range.start, to: range.end));
              }
            },
            onClear: hasDates
                ? () => onChanged(filters.copyWith(clearDates: true))
                : null,
          ),
          const SizedBox(width: 8),
          _MenuFilter(
            icon: Icons.coronavirus_outlined,
            label: filters.label == null
                ? 'Enfermedad'
                : DiseaseCatalog.of(filters.label!).name,
            active: filters.label != null,
            options: {for (final l in labels) l: DiseaseCatalog.of(l).name},
            onSelected: (l) => onChanged(filters.copyWith(label: l)),
            onClear: () => onChanged(filters.copyWith(clearLabel: true)),
          ),
          const SizedBox(width: 8),
          _MenuFilter(
            icon: Icons.grass_rounded,
            label: filters.plantId == null
                ? 'Planta'
                : (plants[filters.plantId] ?? 'Planta'),
            active: filters.plantId != null,
            options: plants,
            onSelected: (id) => onChanged(filters.copyWith(plantId: id)),
            onClear: () => onChanged(filters.copyWith(clearPlant: true)),
          ),
          if (filters.isActive) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => onChanged(HistoryFilters.none),
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Quitar filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onPressed: onTap,
      onDeleted: onClear,
      selectedColor: colors.primaryContainer,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _MenuFilter extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  const _MenuFilter({
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final o in options.entries)
          MenuItemButton(
            style: MenuItemButton.styleFrom(minimumSize: const Size(200, 48)),
            onPressed: () => onSelected(o.key),
            child: Text(o.value),
          ),
      ],
      builder: (context, controller, _) => _FilterChipButton(
        icon: icon,
        label: label,
        active: active,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        onClear: active ? onClear : null,
      ),
    );
  }
}

class _PdfOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _PdfOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      minVerticalPadding: 14,
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        child: Icon(icon, color: colors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _Thumb extends StatelessWidget {
  final AnalysisDto dto;
  final double size;

  const _Thumb({required this.dto, required this.size});

  @override
  Widget build(BuildContext context) {
    final info = DiseaseCatalog.of(dto.label);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: SizedBox.square(
        dimension: size,
        child: dto.photo != null
            ? Image.memory(dto.photo!, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: info.color.withValues(alpha: 0.12),
                child: Icon(info.icon, color: info.color),
              ),
      ),
    );
  }
}

class _AnalysisHistoryCard extends StatelessWidget {
  final AnalysisEntry entry;
  final VoidCallback onPdf;

  const _AnalysisHistoryCard({required this.entry, required this.onPdf});

  @override
  Widget build(BuildContext context) {
    final dto = entry.dto;
    final colors = Theme.of(context).colorScheme;
    final info = DiseaseCatalog.of(dto.label);
    final sevColor = dto.isHealthy
        ? const Color(0xFF2E7D32)
        : severityColor(dto.severity);
    final percent = dto.affectionPercent;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultPage(result: ResultView.fromDto(dto)),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Franja de color según la severidad.
              Container(width: 6, color: sevColor),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _Thumb(dto: dto, size: 96),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: info.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _IconLine(icon: Icons.grass_rounded, text: dto.plantName),
                      _IconLine(
                        icon: Icons.schedule_rounded,
                        text: _formatDate(dto.date),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _SeverityPill(
                            text: dto.isHealthy
                                ? 'Sana'
                                : (dto.severity?.label ?? 'Sin medir'),
                            color: sevColor,
                            dark:
                                !dto.isHealthy &&
                                dto.severity == Severity.moderada,
                          ),
                          if (!dto.isHealthy && percent != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PercentBar(
                                percent: percent,
                                color: sevColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'PDF de este análisis',
                onPressed: onPdf,
                icon: Icon(Icons.picture_as_pdf_rounded, color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool dark;

  const _SeverityPill({
    required this.text,
    required this.color,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: dark ? const Color(0xFF3E2C00) : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// "12.5 % afectado" con una barrita que muestra cuánto de la hoja está mal.
class _PercentBar extends StatelessWidget {
  final double percent;
  final Color color;

  const _PercentBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${percent.toStringAsFixed(1)} % afectado',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
