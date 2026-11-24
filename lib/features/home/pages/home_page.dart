import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/theme/corn_palette.dart';
import '../../../_shared/widgets/authenticated_shell.dart';
import '../../../_shared/widgets/corn_art.dart';
import '../../analysis/config/disease_catalog.dart';
import '../../analysis/manager/analysis_manager.dart';
import '../../analysis/model/analysis_dto.dart';
import '../../analysis/model/leaf_diagnosis.dart';
import '../../analysis/pages/analysis_flow_page.dart';
import '../../auth/manager/auth_manager.dart';
import '../../diseases/pages/diseases_info_page.dart';
import '../../history/pages/history_page.dart';
import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_dto.dart';
import '../../plants/model/plant_status.dart';
import '../../plants/model/plant_watering.dart';
import '../../plants/pages/plant_detail_page.dart';
import '../../plants/pages/plants_page.dart';
import '../../plants/widgets/water_action.dart';

/// Pestañas de la barra inferior (el Chat IA ya no es pestaña: es el
/// botón flotante verde).
class HomeTab {
  HomeTab._();
  static const inicio = 0;
  static const plantas = 1;
  static const nuevo = 2;
  static const historial = 3;
  static const biblioteca = 4;
}

/// Alto de la barra inferior (sin contar la barra del sistema).
const _navBarHeight = 76.0;

class HomePage extends WatchingStatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = HomeTab.inicio;

  void _open(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final isLoggingOut = watchValue(
      (AuthManager m) => m.logoutCommand.isRunning,
    );

    final pages = [
      _DashboardView(onOpenTab: _open),
      const PlantsPage(),
      const AnalysisFlowPage(embedded: true),
      const HistoryPage(),
      const DiseasesInfoPage(),
    ];

    return AuthenticatedShell(
      // El botón de chat queda encima de la barra, sin tapar sus botones.
      chatBottomOffset: _navBarHeight,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: const Row(
            children: [
              Icon(Icons.eco_rounded, color: CornPalette.goldDark),
              SizedBox(width: 8),
              Text('AgroCare', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: isLoggingOut ? 'Saliendo...' : 'Cerrar sesión',
              onPressed: isLoggingOut
                  ? null
                  : () => di<AuthManager>().logoutCommand.run(),
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _AnalyzeButton(
          selected: _index == HomeTab.nuevo,
          onTap: () => _open(HomeTab.nuevo),
        ),
        bottomNavigationBar: _CornNavBar(index: _index, onTap: _open),
      ),
    );
  }
}

// ============================================================================
//  BARRA INFERIOR
// ============================================================================

class _CornNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _CornNavBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, IconData selectedIcon, String label) =>
        Expanded(
          child: _NavItem(
            icon: icon,
            selectedIcon: selectedIcon,
            label: label,
            selected: index == i,
            onTap: () => onTap(i),
          ),
        );

    return BottomAppBar(
      height: _navBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black26,
      shape: const CircularNotchedRectangle(),
      notchMargin: 7,
      child: Row(
        children: [
          item(
            HomeTab.inicio,
            Icons.home_outlined,
            Icons.home_rounded,
            'Inicio',
          ),
          item(
            HomeTab.plantas,
            Icons.spa_outlined,
            Icons.spa_rounded,
            'Mis Plantas',
          ),
          // Lugar del botón central "Nuevo".
          Expanded(
            child: Semantics(
              button: true,
              label: 'Nuevo análisis',
              child: InkWell(
                onTap: () => onTap(HomeTab.nuevo),
                child: SizedBox(
                  height: _navBarHeight,
                  child: Align(
                    alignment: const Alignment(0, 0.72),
                    child: Text(
                      'Nuevo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: index == HomeTab.nuevo
                            ? CornPalette.leafDark
                            : CornPalette.goldDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          item(
            HomeTab.historial,
            Icons.assignment_outlined,
            Icons.assignment_rounded,
            'Historial',
          ),
          item(
            HomeTab.biblioteca,
            Icons.menu_book_outlined,
            Icons.menu_book_rounded,
            'Biblioteca',
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? CornPalette.leafDark : const Color(0xFF6B7468);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          // Zona táctil de al menos 48 × 48 dp.
          constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: selected ? 56 : 40,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? CornPalette.leafLight.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
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

/// Botón central "Nuevo": más grande, dorado como un grano de maíz.
class _AnalyzeButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AnalyzeButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Analizar hoja',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: const Duration(milliseconds: 200),
        child: SizedBox.square(
          dimension: 66,
          child: FloatingActionButton(
            heroTag: 'nuevo-analisis',
            onPressed: onTap,
            elevation: 6,
            shape: CircleBorder(
              side: BorderSide(
                color: selected ? CornPalette.leafDark : Colors.white,
                width: 3,
              ),
            ),
            backgroundColor: CornPalette.gold,
            foregroundColor: CornPalette.leafDark,
            child: const Icon(Icons.add_a_photo_rounded, size: 30),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  RESUMEN GENERAL (pestaña Inicio)
// ============================================================================

class _DashboardView extends WatchingWidget {
  final ValueChanged<int> onOpenTab;

  const _DashboardView({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    if (!sessionReady()) {
      return const Center(child: CircularProgressIndicator());
    }

    final plants = watchValue((PlantsManager m) => m.plants);
    final analyses = watchValue((AnalysisManager m) => m.analyses);
    final user = watchValue((AuthManager m) => m.userState);

    final healthy = plants
        .where((p) => p.dto.status == PlantStatus.saludable)
        .length;
    final watch = plants
        .where((p) => p.dto.status == PlantStatus.enObservacion)
        .length;
    final sick = plants.length - healthy - watch;

    final now = DateTime.now();
    final upcoming = [...plants]
      ..sort(
        (a, b) => a.dto
            .daysUntilWatering(now)
            .compareTo(b.dto.daysUntilWatering(now)),
      );
    final dueToday = plants
        .where((p) => p.dto.daysUntilWatering(now) <= 0)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        FadeSlideIn(
          child: _GreetingCard(
            name: user?.name ?? '',
            plants: plants.length,
            needCare: sick + watch,
            dueToday: dueToday,
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delayMs: 80,
          child: _AnalyzeCard(onTap: () => onOpenTab(HomeTab.nuevo)),
        ),
        const SizedBox(height: 22),
        FadeSlideIn(
          delayMs: 160,
          child: _SectionTitle(
            icon: Icons.health_and_safety_rounded,
            title: 'Salud de tus plantas',
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delayMs: 160,
          child: _HealthCard(
            healthy: healthy,
            watch: watch,
            sick: sick,
            onAddPlant: () => onOpenTab(HomeTab.plantas),
          ),
        ),
        if (plants.isNotEmpty) ...[
          const SizedBox(height: 22),
          FadeSlideIn(
            delayMs: 240,
            child: _SectionTitle(
              icon: Icons.water_drop_rounded,
              title: 'Próximos riegos',
              action: 'Ver plantas',
              onAction: () => onOpenTab(HomeTab.plantas),
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn(
            delayMs: 240,
            child: _WateringCard(plants: upcoming.take(4).toList()),
          ),
        ],
        const SizedBox(height: 22),
        FadeSlideIn(
          delayMs: 320,
          child: _SectionTitle(
            icon: Icons.history_rounded,
            title: 'Últimas detecciones',
            action: analyses.isEmpty ? null : 'Ver todo',
            onAction: () => onOpenTab(HomeTab.historial),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delayMs: 320,
          child: analyses.isEmpty
              ? const _EmptyHint(
                  icon: Icons.photo_camera_back_rounded,
                  text:
                      'Aún no hay análisis. Toca el botón dorado '
                      '"Nuevo" para revisar una hoja.',
                )
              : _RecentDetections(analyses: analyses.take(6).toList()),
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final String name;
  final int plants;
  final int needCare;
  final int dueToday;

  const _GreetingCard({
    required this.name,
    required this.plants,
    required this.needCare,
    required this.dueToday,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _message {
    if (plants == 0) return 'Registra tu primera planta de maíz para empezar.';
    if (needCare > 0) {
      return needCare == 1
          ? '1 planta necesita tu atención.'
          : '$needCare plantas necesitan tu atención.';
    }
    if (dueToday > 0) {
      return dueToday == 1
          ? 'Tus plantas están sanas. Hoy toca regar 1.'
          : 'Tus plantas están sanas. Hoy toca regar $dueToday.';
    }
    return '¡Tus plantas están sanas! Sigue así.';
  }

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(' ').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CornPalette.leaf, CornPalette.leafDark],
        ),
        boxShadow: [
          BoxShadow(
            color: CornPalette.leafDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  first.isEmpty ? '¡Hola, agricultor!' : '¡Hola, $first!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const _SunAndCorn(),
        ],
      ),
    );
  }
}

/// Sol dorado detrás de una planta de maíz.
class _SunAndCorn extends StatelessWidget {
  const _SunAndCorn();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 110,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 4,
            right: 8,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CornPalette.gold,
                boxShadow: [
                  BoxShadow(
                    color: CornPalette.gold.withValues(alpha: 0.6),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          const CornPlantArt(
            growth: 1,
            size: 104,
            leafColor: CornPalette.leafLight,
          ),
        ],
      ),
    );
  }
}

class _AnalyzeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AnalyzeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [CornPalette.goldLight, CornPalette.gold],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: CornPalette.leafDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analizar hoja',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: CornPalette.leafDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Toma una foto y descubre si tu maíz está sano.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4E3B00),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: CornPalette.leafDark,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: CornPalette.leaf, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onAction,
            child: Text(action!),
          ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  final int healthy;
  final int watch;
  final int sick;
  final VoidCallback onAddPlant;

  const _HealthCard({
    required this.healthy,
    required this.watch,
    required this.sick,
    required this.onAddPlant,
  });

  @override
  Widget build(BuildContext context) {
    final total = healthy + watch + sick;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CornCobChart(
              healthy: healthy,
              watch: watch,
              sick: sick,
              height: 156,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: total == 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Todavía no tienes plantas.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: onAddPlant,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Registrar planta'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cada grano de la mazorca es una parte de tus plantas.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _HealthRow(
                          color: CornPalette.gold,
                          label: 'Sanas',
                          value: healthy,
                        ),
                        _HealthRow(
                          color: CornPalette.watch,
                          label: 'En observación',
                          value: watch,
                        ),
                        _HealthRow(
                          color: CornPalette.sick,
                          label: 'Enfermas',
                          value: sick,
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

class _HealthRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _HealthRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          // El número sube contando desde 0.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, v, _) => Text(
              '${v.round()}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WateringCard extends StatelessWidget {
  final List<PlantEntry> plants;

  const _WateringCard({required this.plants});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < plants.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72),
              _WateringRow(entry: plants[i], now: now),
            ],
          ],
        ),
      ),
    );
  }
}

class _WateringRow extends StatelessWidget {
  final PlantEntry entry;
  final DateTime now;

  const _WateringRow({required this.entry, required this.now});

  @override
  Widget build(BuildContext context) {
    final p = entry.dto;
    final days = p.daysUntilWatering(now);
    final color = days < 0
        ? CornPalette.critical
        : days == 0
        ? CornPalette.waterDark
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlantDetailPage(plantId: entry.id, plant: p),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Center(
                child: WaterDropGauge(level: p.waterLevel(now), size: 40),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    nextWateringText(days),
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: days <= 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (days <= 0)
              WaterButton(plantId: entry.id, plantName: p.name, compact: true)
            else
              Text(
                daysAgoText(p.daysSinceWatering(now)),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentDetections extends StatelessWidget {
  final List<AnalysisEntry> analyses;

  const _RecentDetections({required this.analyses});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: analyses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _DetectionCard(dto: analyses[i].dto),
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  final AnalysisDto dto;

  const _DetectionCard({required this.dto});

  @override
  Widget build(BuildContext context) {
    final info = DiseaseCatalog.of(dto.label);
    final photo = dto.photo;
    return SizedBox(
      width: 156,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photo != null)
                    Image.memory(
                      photo,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  else
                    ColoredBox(
                      color: info.color.withValues(alpha: 0.12),
                      child: Icon(info.icon, color: info.color, size: 40),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: info.color,
                      child: Icon(
                        dto.isHealthy ? Icons.check_rounded : info.icon,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Text(
                info.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: info.color,
                  fontSize: 15,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: Text(
                dto.plantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: Text(
                [
                  if (!dto.isHealthy && dto.severity != null)
                    dto.severity!.label,
                  _formatDate(dto.date),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: CornPalette.goldDark, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
