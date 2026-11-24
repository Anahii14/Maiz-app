import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/widgets/authenticated_shell.dart';
import '../../analysis/manager/analysis_manager.dart';
import '../manager/plants_manager.dart';
import '../model/plant_dto.dart';
import '../../../_shared/theme/corn_palette.dart';
import '../../../_shared/widgets/corn_art.dart';
import '../../analysis/config/disease_catalog.dart';
import '../../analysis/model/analysis_dto.dart';
import '../model/plant_status.dart';
import '../model/plant_watering.dart';
import '../widgets/water_action.dart';

class PlantDetailPage extends WatchingWidget {
  final String plantId;
  final PlantDto plant;

  const PlantDetailPage({
    super.key,
    required this.plantId,
    required this.plant,
  });

  @override
  Widget build(BuildContext context) {
    final manager = di<PlantsManager>();
    // Se ESCUCHA la lista de plantas: así, al regar o editar, esta pantalla
    // cambia al instante. (Antes mostraba la copia recibida al abrirla y no
    // se actualizaba hasta volver a entrar.)
    final plants = watchValue((PlantsManager m) => m.plants);
    final analyses = watchValue((AnalysisManager m) => m.analyses);
    final colors = Theme.of(context).colorScheme;
    final plant = _current(plants);
    final now = DateTime.now();

    final plantAnalyses = analyses
        .where((a) => a.dto.plantId == plantId)
        .map((e) => e.dto)
        .toList();

    return AuthenticatedShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(plant.name),
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _showEditDialog(context, manager, plant),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(context, manager, plant),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _PlantHero(plant: plant, now: now),
            const SizedBox(height: 16),
            _StageTimeline(days: plant.daysSincePlanting(now)),
            const SizedBox(height: 16),
            _WateringPanel(plantId: plantId, plant: plant, now: now),
            const SizedBox(height: 20),
            _Title('Resumen de Planta'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Variedad',
                      value: plant.variety.isEmpty ? '—' : plant.variety,
                    ),
                    _DetailRow(
                      label: 'Ubicación',
                      value: plant.displayLocation.isEmpty
                          ? '—'
                          : plant.displayLocation,
                    ),
                    _DetailRow(
                      label: 'Fecha de siembra',
                      value: _formatDate(plant.plantedDate),
                    ),
                    _DetailRow(
                      label: 'Área',
                      value: plant.areaHectares > 0
                          ? '${plant.areaHectares} ha'
                          : '—',
                    ),
                    _DetailRow(label: 'Estado', value: plant.status.label),
                    if (plant.notes.isNotEmpty)
                      _DetailRow(label: 'Observaciones', value: plant.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Title('Historial de análisis'),
            const SizedBox(height: 10),
            if (plantAnalyses.isEmpty)
              Text(
                'Sin análisis registrados.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else ...[
              _AffectionChart(analyses: plantAnalyses.take(8).toList()),
              const SizedBox(height: 8),
              ...plantAnalyses.map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    a.isHealthy
                        ? Icons.check_circle_outline
                        : Icons.warning_amber,
                    color: a.isHealthy ? colors.primary : colors.error,
                  ),
                  title: Text(a.summary),
                  subtitle: Text(_formatDate(a.date)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Title('Historial de riegos'),
            const SizedBox(height: 8),
            if (plant.wateringHistory.isEmpty)
              Text(
                'Sin riegos registrados.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              ...plant.wateringHistory
                  .take(10)
                  .map(
                    (date) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.water_drop_rounded,
                        color: CornPalette.water,
                      ),
                      title: Text(_formatDate(date)),
                      trailing: Text(
                        daysAgoText(daysBetween(date, now)),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// La versión más nueva de la planta (o la recibida si ya no está).
  PlantDto _current(List<PlantEntry> plants) {
    for (final p in plants) {
      if (p.id == plantId) return p.dto;
    }
    return plant;
  }

  Future<void> _showEditDialog(
    BuildContext context,
    PlantsManager manager,
    PlantDto plant,
  ) async {
    final nameController = TextEditingController(text: plant.name);
    final varietyController = TextEditingController(text: plant.variety);
    final locationController = TextEditingController(
      text: plant.displayLocation,
    );
    var status = plant.status;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar planta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: varietyController,
                  decoration: const InputDecoration(labelText: 'Variedad'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PlantStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: PlantStatus.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
            FilledButton(
              onPressed: () {
                manager.savePlantCommand.run(
                  PlantSaveRequest(
                    id: plantId,
                    dto: plant.copyWith(
                      name: nameController.text.trim(),
                      variety: varietyController.text.trim(),
                      placeName: locationController.text.trim(),
                      location: locationController.text.trim(),
                      status: status,
                    ),
                  ),
                );
                // La pantalla de detalle se actualiza sola: solo se cierra
                // el diálogo.
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    varietyController.dispose();
    locationController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlantsManager manager,
    PlantDto plant,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar planta'),
        content: Text(
          '¿Estás seguro de eliminar "${plant.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      manager.deletePlantCommand.run(plantId);
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

/// Cabecera con la planta dibujada, meciéndose con el viento.
class _PlantHero extends StatelessWidget {
  final PlantDto plant;
  final DateTime now;

  const _PlantHero({required this.plant, required this.now});

  @override
  Widget build(BuildContext context) {
    final statusColor = CornPalette.statusColor(plant.status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFF1F8E9), CornPalette.cream],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          CornPlantArt(
            growth: plant.growth(now),
            leafColor: CornPalette.leafFor(plant.status),
            spots: plant.status.isAtRisk,
            size: 140,
            sway: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.stage(now).label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CornPalette.leafDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plant.daysSincePlanting(now) == 1
                      ? '1 día desde la siembra'
                      : '${plant.daysSincePlanting(now)} días desde la siembra',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CornPalette.statusIcon(plant.status),
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        plant.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea de tiempo con las etapas del maíz; la actual resaltada.
class _StageTimeline extends StatelessWidget {
  final int days;

  const _StageTimeline({required this.days});

  static const _icons = [
    Icons.grass_rounded,
    Icons.spa_rounded,
    Icons.local_florist_rounded,
    Icons.egg_rounded,
    Icons.agriculture_rounded,
  ];

  Color _line(bool done) =>
      done ? CornPalette.gold : CornPalette.goldLight.withValues(alpha: 0.4);

  @override
  Widget build(BuildContext context) {
    final current = CornStage.fromDays(days).index;
    final last = CornStage.values.length - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in CornStage.values)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              color: s.index == 0
                                  ? Colors.transparent
                                  : _line(s.index <= current),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: s.index == current ? 40 : 30,
                            height: s.index == current ? 40 : 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _line(s.index <= current),
                              border: s.index == current
                                  ? Border.all(
                                      color: CornPalette.leafDark,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              _icons[s.index],
                              size: s.index == current ? 22 : 16,
                              color: s.index <= current
                                  ? CornPalette.leafDark
                                  : Colors.black38,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: s.index == last
                                  ? Colors.transparent
                                  : _line(s.index < current),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: s.index == current
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Riego: gota grande, botones y calendario de las últimas 4 semanas.
class _WateringPanel extends StatelessWidget {
  final String plantId;
  final PlantDto plant;
  final DateTime now;

  const _WateringPanel({
    required this.plantId,
    required this.plant,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final days = plant.daysUntilWatering(now);
    final interval = plant.wateringIntervalDays;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WaterDropGauge(level: plant.waterLevel(now), size: 70),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Último riego: '
                        '${daysAgoText(plant.daysSinceWatering(now)).toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Próximo riego: ${nextWateringText(days).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: days < 0
                              ? CornPalette.critical
                              : CornPalette.waterDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        interval == 1
                            ? 'Riegas cada día'
                            : 'Riegas cada $interval días aprox.',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: WaterButton(plantId: plantId, plantName: plant.name),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => waterPlantOnDate(
                    context,
                    plantId: plantId,
                    plantName: plant.name,
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  label: const Text('Otra fecha'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Últimas 4 semanas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            _WateringCalendar(plant: plant, now: now),
          ],
        ),
      ),
    );
  }
}

class _WateringCalendar extends StatelessWidget {
  final PlantDto plant;
  final DateTime now;

  const _WateringCalendar({required this.plant, required this.now});

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  Widget _cell(DateTime day, DateTime today) {
    final future = day.isAfter(today);
    final watered = !future && plant.wateredOn(day);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(2.5),
      height: 34,
      decoration: BoxDecoration(
        color: watered
            ? CornPalette.water
            : future
            ? Colors.transparent
            : CornPalette.water.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: day == today
            ? Border.all(color: CornPalette.leafDark, width: 2)
            : null,
      ),
      child: Center(
        child: watered
            ? const Icon(
                Icons.water_drop_rounded,
                size: 16,
                color: Colors.white,
              )
            : Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: future ? Colors.black26 : Colors.black54,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(now);
    // Empieza en lunes, 3 semanas antes de la semana actual.
    final start = today.subtract(Duration(days: today.weekday - 1 + 21));
    return Column(
      children: [
        Row(
          children: [
            for (final l in _letters)
              Expanded(
                child: Center(
                  child: Text(
                    l,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < 4; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: _cell(
                    DateTime(start.year, start.month, start.day + w * 7 + d),
                    today,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Barras con el % afectado de cada análisis (las más recientes a la derecha).
class _AffectionChart extends StatelessWidget {
  final List<AnalysisDto> analyses;

  const _AffectionChart({required this.analyses});

  static const _maxH = 110.0;

  double _barHeight(AnalysisDto a) {
    if (a.isHealthy) return 6;
    final p = (a.affectionPercent ?? 0).clamp(0, 60);
    return 6 + p / 60 * (_maxH - 6);
  }

  @override
  Widget build(BuildContext context) {
    final items = analyses.reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '% de hoja afectada en cada análisis',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: _maxH + 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final a in items)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              a.isHealthy
                                  ? 'Sana'
                                  : '${(a.affectionPercent ?? 0).round()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: _barHeight(a)),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (_, h, _) => Container(
                                height: h,
                                decoration: BoxDecoration(
                                  color: DiseaseCatalog.of(a.label).color,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmtDate(a.date).substring(0, 5),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
