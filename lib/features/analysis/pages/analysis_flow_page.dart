import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/widgets/authenticated_shell.dart';
import '../../analysis/model/analysis_dto.dart';
import '../../camera/manager/camera_manager.dart';
import '../manager/analysis_manager.dart';
import 'analysis_result_page.dart';

enum _AnalysisStep { selectPlant, uploadImage }

class AnalysisFlowPage extends WatchingStatefulWidget {
  final AnalysisType? initialType;
  final bool embedded;

  const AnalysisFlowPage({super.key, this.initialType, this.embedded = false});

  @override
  State<AnalysisFlowPage> createState() => _AnalysisFlowPageState();
}

class _AnalysisFlowPageState extends State<AnalysisFlowPage> {
  _AnalysisStep _step = _AnalysisStep.selectPlant;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          di<CameraManager>().setAnalysisType(widget.initialType!);
        }
      });
    }
  }

  /// Ejecuta el análisis real y abre la pantalla de resultados.
  Future<void> _analyze() async {
    final manager = di<CameraManager>();
    AnalysisOutcome? outcome;
    try {
      outcome = await manager.analyzeCommand.runAsync();
    } catch (_) {
      return; // el error ya se mostró en un aviso
    }
    if (outcome == null || !mounted) return;
    final saved = outcome.savedId != null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisResultPage(
          result: ResultView.fromDiagnosis(
            outcome!.diagnosis,
            outcome.plantName,
          ),
        ),
      ),
    );
    if (saved && mounted) {
      setState(() => _step = _AnalysisStep.selectPlant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = di<CameraManager>();
    final type = watchValue((CameraManager m) => m.analysisType);
    final plants = watchValue((CameraManager m) => m.plants);
    final plantId = watchValue((CameraManager m) => m.selectedPlantId);
    final image = watchValue((CameraManager m) => m.capturedImage);
    final preview = watchValue((CameraManager m) => m.capturedPreview);
    final isPickingCamera = watchValue(
      (CameraManager m) => m.pickFromCameraCommand.isRunning,
    );
    final isPickingGallery = watchValue(
      (CameraManager m) => m.pickFromGalleryCommand.isRunning,
    );
    final isAnalyzing = watchValue(
      (CameraManager m) => m.analyzeCommand.isRunning,
    );
    final colors = Theme.of(context).colorScheme;

    final isLeaf = type == AnalysisType.hoja;
    final uploadHint = isLeaf
        ? 'Sube o toma una foto de la hoja.'
        : 'Sube una imagen aérea o panorámica del terreno.';

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Nuevo análisis',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Detecta enfermedades en tus cultivos.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                title: 'Hoja individual',
                subtitle: 'Analiza una hoja específica con el modelo de IA.',
                icon: Icons.eco_rounded,
                selected: isLeaf,
                onTap: () => manager.setAnalysisType(AnalysisType.hoja),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: 0.5,
                child: _TypeCard(
                  title: 'Terreno completo',
                  subtitle:
                      'Próximamente: el modelo actual solo reconoce hojas.',
                  icon: Icons.landscape_rounded,
                  selected: false,
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_step == _AnalysisStep.selectPlant) ...[
          Text(
            'Selecciona una planta',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (plants.isEmpty)
            Text(
              'Registra una planta antes de analizar.',
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: plantId,
              decoration: const InputDecoration(
                labelText: 'Plantas registradas',
              ),
              items: plants
                  .map(
                    (e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.dto.name)),
                  )
                  .toList(),
              onChanged: manager.selectPlant,
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: plantId == null
                ? null
                : () => setState(() => _step = _AnalysisStep.uploadImage),
            child: const Text('Siguiente'),
          ),
        ] else ...[
          TextButton.icon(
            onPressed: () => setState(() => _step = _AnalysisStep.selectPlant),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Volver'),
          ),
          const SizedBox(height: 8),
          Text(
            uploadHint,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: colors.secondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Para un resultado más preciso: una sola hoja, de cerca, '
                    'bien iluminada y enfocada, ocupando casi toda la foto y '
                    'con fondo despejado (sin hojas secas ni tierra alrededor).',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _UploadOption(
            icon: Icons.photo_camera_rounded,
            label: 'Tomar fotografía',
            loading: isPickingCamera,
            onTap: isPickingCamera
                ? null
                : () => manager.pickFromCameraCommand.run(),
          ),
          const SizedBox(height: 10),
          _UploadOption(
            icon: Icons.photo_library_rounded,
            label: 'Subir desde galería',
            loading: isPickingGallery,
            onTap: isPickingGallery
                ? null
                : () => manager.pickFromGalleryCommand.run(),
          ),
          if (image != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: colors.primary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Foto lista para analizar')),
                    ],
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        preview,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isAnalyzing ? null : _analyze,
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.biotech_rounded),
              label: Text(isAnalyzing ? 'Analizando...' : 'Iniciar análisis'),
            ),
          ],
        ],
      ],
    );

    if (widget.embedded) return content;

    return AuthenticatedShell(
      child: Scaffold(
        appBar: AppBar(title: const Text('Nuevo análisis')),
        body: content,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}
