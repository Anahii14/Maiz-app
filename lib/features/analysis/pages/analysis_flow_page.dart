import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/widgets/authenticated_shell.dart';
import '../../analysis/model/analysis_dto.dart';
import '../../camera/manager/camera_manager.dart';
import '../manager/analysis_manager.dart';
import '../services/leaf_analyzer.dart';
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
    // Carga el modelo UNA vez al abrir la cámara/análisis (si ya estaba
    // cargado, no hace nada), para que la primera foto no espere.
    if (di.isRegistered<LeafAnalyzer>()) di<LeafAnalyzer>().warmUp();
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
    final plantId = manager.selectedPlantId.value ?? '';
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
            plantId: plantId,
            plantName: outcome.plantName,
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

    const uploadHint = 'Sube o toma una foto de la hoja.';

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
        // Solo hay análisis de hojas (el modelo reconoce hojas de maíz).
        const _LeafModeCard(),
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

class _LeafModeCard extends StatelessWidget {
  const _LeafModeCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_rounded, color: colors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Análisis de hoja',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Toma una foto de cerca a una sola hoja de maíz, con buena luz.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
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
