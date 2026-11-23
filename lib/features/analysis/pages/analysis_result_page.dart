import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/disease_catalog.dart';
import '../config/recommendations.dart';
import '../model/analysis_dto.dart';
import '../model/leaf_diagnosis.dart';

/// Datos que necesita la pantalla (vienen de un análisis nuevo o del historial).
class ResultView {
  final DiagnosisStatus status;
  final String label;
  final double confidence;
  final double? affectedPercent;
  final Severity? severity;
  final Uint8List? photo;
  final String plantName;
  final DateTime? date;

  const ResultView({
    required this.status,
    required this.label,
    required this.confidence,
    required this.plantName,
    this.affectedPercent,
    this.severity,
    this.photo,
    this.date,
  });

  factory ResultView.fromDiagnosis(LeafDiagnosis d, String plantName) =>
      ResultView(
        status: d.status,
        label: d.label,
        confidence: d.confidence,
        affectedPercent: d.affectedPercent,
        severity: d.severity,
        photo: d.photoJpeg,
        plantName: plantName,
        date: DateTime.now(),
      );

  factory ResultView.fromDto(AnalysisDto dto) => ResultView(
    status: dto.isHealthy ? DiagnosisStatus.healthy : DiagnosisStatus.disease,
    label: dto.label,
    confidence: dto.confidence,
    affectedPercent: dto.affectionPercent,
    severity: dto.severity,
    photo: dto.photo,
    plantName: dto.plantName,
    date: dto.date,
  );
}

/// Colores de la severidad: Leve = verde, Moderada = naranja, Severa = rojo.
Color severityColor(Severity? s) => switch (s) {
  Severity.leve => const Color(0xFF2E7D32),
  Severity.moderada => const Color(0xFFEF6C00),
  Severity.severa => const Color(0xFFC62828),
  null => const Color(0xFF757575),
};

class AnalysisResultPage extends StatelessWidget {
  final ResultView result;

  const AnalysisResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado del análisis')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: switch (result.status) {
                DiagnosisStatus.disease => _disease(context),
                DiagnosisStatus.healthy => _healthy(context),
                DiagnosisStatus.notRecognized => _notRecognized(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Enfermedad
  List<Widget> _disease(BuildContext context) {
    final info = DiseaseCatalog.of(result.label);
    final text = Theme.of(context).textTheme;
    final percent = result.affectedPercent;
    return [
      _HeaderCard(
        color: info.color,
        icon: info.icon,
        title: info.name,
        subtitle: info.scientificName.isEmpty ? null : info.scientificName,
        caption: 'Planta: ${result.plantName}',
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: Column(
            children: [
              if (percent != null) ...[
                AffectionGauge(
                  percent: percent,
                  color: severityColor(result.severity),
                ),
                const SizedBox(height: 16),
                SeverityBadge(severity: result.severity),
                if (percent < 0.5) ...[
                  const SizedBox(height: 14),
                  const _NoVisibleLesionsNote(),
                ],
              ] else ...[
                Icon(
                  Icons.crop_free_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  'No se pudo separar la hoja del fondo para medir el área '
                  'afectada. Toma la foto más cerca, con la hoja ocupando '
                  'casi toda la imagen.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              _ConfidenceText(confidence: result.confidence),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _Photo(bytes: result.photo),
      const SizedBox(height: 20),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => showRecommendations(
          context,
          label: result.label,
          severity: result.severity,
        ),
        icon: const Icon(Icons.medical_services_outlined),
        label: const Text('Recomendaciones'),
      ),
    ];
  }

  // -------------------------------------------------------------- Hoja sana
  List<Widget> _healthy(BuildContext context) {
    const green = Color(0xFF2E7D32);
    final text = Theme.of(context).textTheme;
    return [
      Card(
        color: const Color(0xFFE8F5E9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 76,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Hoja sana',
                style: text.displaySmall?.copyWith(
                  color: green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No se detectaron enfermedades en esta hoja.',
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text('Planta: ${result.plantName}', style: text.bodyMedium),
              const SizedBox(height: 12),
              _ConfidenceText(confidence: result.confidence),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _Photo(bytes: result.photo),
    ];
  }

  // ---------------------------------------------------------- No reconocido
  List<Widget> _notRecognized(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              Icon(Icons.help_outline_rounded, size: 72, color: colors.outline),
              const SizedBox(height: 14),
              Text(
                'No reconocido',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No reconocido, intenta con otra foto (hoja bien iluminada y '
                'enfocada).',
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Este intento no se guardó en el historial.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _Photo(bytes: result.photo),
      const SizedBox(height: 20),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.photo_camera_rounded),
        label: const Text('Intentar con otra foto'),
      ),
    ];
  }
}

// ============================================================== Componentes

class _HeaderCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String caption;

  const _HeaderCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.caption,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enfermedad detectada',
                  style: text.labelLarge?.copyWith(color: color),
                ),
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(caption, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de dona con el % de área afectada.
class AffectionGauge extends StatelessWidget {
  final double percent;
  final Color color;
  final double size;

  const AffectionGauge({
    super.key,
    required this.percent,
    required this.color,
    this.size = 210,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percent.clamp(0, 100).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _GaugePainter(
            value: value / 100,
            color: color,
            track: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text('de la hoja afectada', style: text.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, base);
    if (value <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Insignia de severidad con su color.
class SeverityBadge extends StatelessWidget {
  final Severity? severity;
  final bool compact;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 18,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact
            ? (severity?.label ?? 'Sin medir')
            : 'Severidad: ${severity?.label ?? 'sin medir'}',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 16,
        ),
      ),
    );
  }
}

/// El modelo detecta una enfermedad pero no se ven manchas medibles.
class _NoVisibleLesionsNote extends StatelessWidget {
  const _NoVisibleLesionsNote();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.tertiary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'El modelo reconoce la enfermedad, pero no se encontraron '
              'manchas visibles para medir. Puede ser una etapa muy '
              'temprana o una confusión del modelo: revisa la hoja en campo '
              'y repite con otra foto más cercana y nítida.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceText extends StatelessWidget {
  final double confidence;

  const _ConfidenceText({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Confianza del modelo: ${(confidence * 100).toStringAsFixed(1)}%',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final Uint8List? bytes;

  const _Photo({required this.bytes});

  @override
  Widget build(BuildContext context) {
    if (bytes == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto analizada',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(
            bytes!,
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ],
    );
  }
}

// ========================================================= Recomendaciones

/// Abre la ventana de recomendaciones de la enfermedad detectada.
Future<void> showRecommendations(
  BuildContext context, {
  required String label,
  required Severity? severity,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => RecommendationsView(
        label: label,
        severity: severity,
        controller: controller,
      ),
    ),
  );
}

class RecommendationsView extends StatelessWidget {
  final String label;
  final Severity? severity;
  final ScrollController? controller;

  const RecommendationsView({
    super.key,
    required this.label,
    required this.severity,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final info = DiseaseCatalog.of(label);
    final recs = Recommendations.byLabel[label];
    final text = Theme.of(context).textTheme;
    final chemicalFirst = Recommendations.chemicalRecommended(severity);
    final color = severityColor(severity);

    final prevention = _Section(
      icon: Icons.visibility_outlined,
      title: 'Monitoreo y prevención',
      items: recs?.prevention ?? const [],
      color: const Color(0xFF2E7D32),
    );
    final chemical = _Section(
      icon: Icons.science_outlined,
      title: chemicalFirst
          ? 'Control químico recomendado'
          : 'Control químico (solo si la enfermedad avanza)',
      items: recs?.chemical ?? const [],
      color: chemicalFirst ? color : const Color(0xFF757575),
    );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(
          'Recomendaciones',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${info.name}'
          '${info.scientificName.isEmpty ? '' : ' (${info.scientificName})'}',
          style: text.titleMedium?.copyWith(color: info.color),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.priority_high_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(Recommendations.emphasisFor(severity))),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (recs == null)
          const Text('No hay recomendaciones cargadas para esta clase.')
        else if (chemicalFirst) ...[
          chemical,
          prevention,
        ] else ...[
          prevention,
          chemical,
        ],
        const Divider(height: 32),
        _Section(
          icon: Icons.warning_amber_rounded,
          title: 'Advertencias importantes',
          items: Recommendations.warnings,
          color: const Color(0xFFB26A00),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  const _Section({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Icon(Icons.circle, size: 7, color: color),
                  ),
                  Expanded(child: Text(item, style: text.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
