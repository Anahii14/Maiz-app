import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/theme/corn_palette.dart';
import '../../../_shared/widgets/corn_art.dart';
import '../../../app/routes.dart';
import '../manager/plants_manager.dart';
import '../model/plant_dto.dart';
import '../model/plant_status.dart';
import '../model/plant_watering.dart';
import '../widgets/water_action.dart';
import 'plant_detail_page.dart';

class PlantsPage extends WatchingWidget {
  const PlantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Evitar acceder al manager si aún no está registrado/listo.
    if (!di.isRegistered<PlantsManager>()) {
      return const Center(child: CircularProgressIndicator());
    }

    late final List<PlantEntry> plants;
    try {
      plants = watchValue((PlantsManager m) => m.plants);
    } on StateError {
      return const Center(child: CircularProgressIndicator());
    }

    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final toWater = plants
        .where((p) => p.dto.daysUntilWatering(now) <= 0)
        .length;
    final healthy = plants
        .where((p) => p.dto.status == PlantStatus.saludable)
        .length;

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
                    'Mis Plantas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    plants.length == 1
                        ? '1 planta registrada'
                        : '${plants.length} plantas registradas',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.plantForm),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Nueva Planta'),
            ),
          ],
        ),
        if (plants.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                icon: Icons.water_drop_rounded,
                color: CornPalette.waterDark,
                text: toWater == 0
                    ? 'Nada que regar hoy'
                    : toWater == 1
                    ? '1 por regar hoy'
                    : '$toWater por regar hoy',
              ),
              _SummaryChip(
                icon: Icons.eco_rounded,
                color: CornPalette.leaf,
                text: '$healthy sanas',
              ),
              if (plants.length - healthy > 0)
                _SummaryChip(
                  icon: Icons.visibility_rounded,
                  color: CornPalette.sick,
                  text: '${plants.length - healthy} por revisar',
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (plants.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CornPlantArt(growth: 0.3, size: 96),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no tienes plantas registradas',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Presiona Nueva Planta para comenzar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < plants.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeSlideIn(
                delayMs: (i * 60).clamp(0, 300),
                child: _PlantCard(
                  // La clave por id hace que cada tarjeta conserve su estado
                  // y se actualice sola cuando cambia SU planta.
                  key: ValueKey(plants[i].id),
                  entry: plants[i],
                  now: now,
                ),
              ),
            ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _SummaryChip({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final PlantEntry entry;
  final DateTime now;

  const _PlantCard({super.key, required this.entry, required this.now});

  @override
  Widget build(BuildContext context) {
    final p = entry.dto;
    final colors = Theme.of(context).colorScheme;
    final stage = p.stage(now);
    final days = p.daysUntilWatering(now);
    final statusColor = CornPalette.statusColor(p.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlantDetailPage(plantId: entry.id, plant: p),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dibujo de la planta según su edad y su salud.
              Container(
                width: 96,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE8F5E9), CornPalette.cream],
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CornPlantArt(
                      growth: p.growth(now),
                      leafColor: CornPalette.leafFor(p.status),
                      spots: p.status.isAtRisk,
                      size: 84,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: CornPalette.leafDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Text(
                        [
                          p.variety.isNotEmpty ? p.variety : 'Sin variedad',
                          if (p.areaHectares > 0) '${p.areaHectares} ha',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      _StatusPill(status: p.status, color: statusColor),
                      const SizedBox(height: 10),
                      _GrowthBar(days: p.daysSincePlanting(now)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          WaterDropGauge(level: p.waterLevel(now), size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Regado: ${daysAgoText(p.daysSinceWatering(now)).toLowerCase()}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  'Próximo: ${nextWateringText(days)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: days < 0
                                        ? CornPalette.critical
                                        : CornPalette.waterDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          WaterButton(
                            plantId: entry.id,
                            plantName: p.name,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      WeekWateringStrip(plant: p, now: now),
                    ],
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

class _StatusPill extends StatelessWidget {
  final PlantStatus status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CornPalette.statusIcon(status), size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Barra dorada de crecimiento: del día de siembra a la cosecha.
class _GrowthBar extends StatelessWidget {
  final int days;

  const _GrowthBar({required this.days});

  @override
  Widget build(BuildContext context) {
    final harvest = CornStage.madurez.fromDay;
    final value = (days / harvest).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          days >= harvest ? 'Día $days · lista' : 'Día $days de ~$harvest',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: CornPalette.goldLight.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation(CornPalette.gold),
            ),
          ),
        ),
      ],
    );
  }
}

/// Los últimos 7 días: una gota llena por cada día con riego.
class WeekWateringStrip extends StatelessWidget {
  final PlantDto plant;
  final DateTime now;

  const WeekWateringStrip({super.key, required this.plant, required this.now});

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(now);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 6; i >= 0; i--)
          Builder(
            builder: (context) {
              final day = today.subtract(Duration(days: i));
              final watered = plant.wateredOn(day);
              return Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Icon(
                      watered
                          ? Icons.water_drop_rounded
                          : Icons.water_drop_outlined,
                      key: ValueKey(watered),
                      size: 18,
                      color: watered
                          ? CornPalette.water
                          : CornPalette.water.withValues(alpha: 0.3),
                    ),
                  ),
                  Text(
                    i == 0 ? 'Hoy' : _letters[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
