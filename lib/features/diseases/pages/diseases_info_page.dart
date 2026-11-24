import 'package:flutter/material.dart';

import '../../../_shared/widgets/corn_art.dart';
import '../model/library_entry.dart';
import 'disease_detail_page.dart';

/// Biblioteca: enfermedades, plagas y problemas comunes del maíz.
/// Los datos están en assets/data/biblioteca_maiz.json.
class DiseasesInfoPage extends StatefulWidget {
  const DiseasesInfoPage({super.key});

  @override
  State<DiseasesInfoPage> createState() => _DiseasesInfoPageState();
}

class _DiseasesInfoPageState extends State<DiseasesInfoPage> {
  final _search = TextEditingController();
  late final Future<LibraryData> _data = LibraryRepository.load();
  LibraryType? _type;
  bool _onlyDetected = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<LibraryData>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text(
              'No se pudo abrir la Biblioteca (biblioteca_maiz.json).',
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final found = filterLibrary(
          data.entries,
          query: _search.text,
          type: _type,
          onlyDetected: _onlyDetected,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Text(
              'Biblioteca',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${data.entries.length} enfermedades, plagas y problemas del maíz',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Busca: roya, manchas, gusano, amarillo…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TypeChip(
                    label: 'Todos',
                    icon: Icons.apps_rounded,
                    color: colors.primary,
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  for (final t in LibraryType.values)
                    if (data.entries.any((e) => e.type == t))
                      _TypeChip(
                        label: t.label,
                        icon: t.icon,
                        color: t.color,
                        selected: _type == t,
                        onTap: () =>
                            setState(() => _type = _type == t ? null : t),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                avatar: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Solo lo que detecta la app'),
                selected: _onlyDetected,
                onSelected: (v) => setState(() => _onlyDetected = v),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
            const SizedBox(height: 8),
            if (found.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 44,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No encontramos nada con esa búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var i = 0; i < found.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideIn(
                    // La clave hace que la animación se repita al filtrar.
                    key: ValueKey(
                      '${found[i].id}-${_type?.name}-$_onlyDetected',
                    ),
                    delayMs: (i * 40).clamp(0, 240),
                    child: _EntryCard(
                      entry: found[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiseaseDetailPage(
                            entry: found[i],
                            notice: data.notice,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              data.notice,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: selected ? Colors.white : color),
        label: Text(label),
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: FontWeight.w700,
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: color,
        onSelected: (_) => onTap(),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback onTap;

  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'lib-${entry.id}',
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        entry.color.withValues(alpha: 0.75),
                        entry.color,
                      ],
                    ),
                  ),
                  child: Icon(entry.icon, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.scientificName.isNotEmpty)
                      Text(
                        entry.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: muted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      entry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: muted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(text: entry.type.label, color: entry.type.color),
                        if (entry.detectedByApp)
                          const _Tag(
                            text: 'La app lo detecta',
                            color: Color(0xFF2E7D32),
                            icon: Icons.photo_camera_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Tag({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
