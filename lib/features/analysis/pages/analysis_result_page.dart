import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/disease_catalog.dart';
import '../model/analysis_dto.dart';
import '../model/leaf_diagnosis.dart';
import 'package:watch_it/watch_it.dart';

import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_status.dart';
import '../../reports/analysis_report.dart';
import 'recommendations_page.dart';

/// Datos que necesita la pantalla (de un análisis nuevo o del historial).
class ResultView {
  final EstadoDiagnostico status;
  final String label;
  final double confidence;
  final bool partial;
  final bool mediumConfidence;
  final List<ClaseProbable> top2;
  final double? affectedPercent;
  final Severity? severity;
  final Uint8List? photo;
  final String plantId;
  final String plantName;
  final int? analysisTimeMs;

  /// Fecha del análisis (si es nuevo, el momento en que se hizo).
  final DateTime? date;

  const ResultView({
    required this.status,
    required this.label,
    required this.confidence,
    required this.plantName,
    this.plantId = '',
    this.partial = false,
    this.mediumConfidence = false,
    this.top2 = const [],
    this.affectedPercent,
    this.severity,
    this.photo,
    this.analysisTimeMs,
    this.date,
  });

  factory ResultView.fromDiagnosis(
    LeafDiagnosis d, {
    required String plantId,
    required String plantName,
  }) => ResultView(
    status: d.status,
    label: d.label,
    confidence: d.confidence,
    partial: d.partial,
    mediumConfidence: d.mediumConfidence,
    top2: d.top2,
    affectedPercent: d.affectedPercent,
    severity: d.severity,
    photo: d.photoJpeg,
    plantId: plantId,
    plantName: plantName,
    analysisTimeMs: d.analysisTimeMs,
    date: DateTime.now(),
  );

  factory ResultView.fromDto(AnalysisDto dto) => ResultView(
    status: dto.isHealthy ? EstadoDiagnostico.sana : EstadoDiagnostico.enferma,
    label: dto.label,
    confidence: dto.confidence,
    partial: dto.partial,
    mediumConfidence: dto.mediumConfidence,
    top2: dto.top2,
    affectedPercent: dto.affectionPercent,
    severity: dto.severity,
    photo: dto.photo,
    plantId: dto.plantId,
    plantName: dto.plantName,
    analysisTimeMs: dto.analysisTimeMs,
    date: dto.date,
  );
}

extension ResultViewReport on ResultView {
  /// Mismos datos que usa el PDF del historial.
  AnalysisReportItem toReportItem() {
    PlantStatus? plantStatus;
    if (di.isRegistered<PlantsManager>()) {
      for (final p in di<PlantsManager>().plants.value) {
        if (p.id == plantId) plantStatus = p.dto.status;
      }
    }
    return AnalysisReportItem(
      plantId: plantId,
      plantName: plantName,
      plantStatus: plantStatus,
      label: label,
      isHealthy: status == EstadoDiagnostico.sana,
      partial: partial,
      confidence: confidence,
      affectedPercent: affectedPercent,
      severity: severity,
      date: date ?? DateTime.now(),
      photo: photo,
    );
  }
}

/// Colores de la severidad: Leve = verde, Moderada = amarillo, Severa = rojo.
Color severityColor(Severity? s) => switch (s) {
  Severity.leve => const Color(0xFF2E7D32),
  Severity.moderada => const Color(0xFFF9A825),
  Severity.severa => const Color(0xFFC62828),
  null => const Color(0xFF757575),
};

/// "87 %".
String percentText(double p) => '${(p * 100).round()} %';

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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: switch (result.status) {
                EstadoDiagnostico.enferma => _disease(context),
                EstadoDiagnostico.sana => _healthy(context),
                EstadoDiagnostico.noReconocido => _retry(
                  context,
                  title: 'No reconocido',
                  icon: Icons.help_outline_rounded,
                ),
                EstadoDiagnostico.noEsHoja => _retry(
                  context,
                  title: 'Esto no parece una hoja',
                  icon: Icons.image_not_supported_outlined,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- ENFERMA
  List<Widget> _disease(BuildContext context) {
    final info = DiseaseCatalog.of(result.label);
    final text = Theme.of(context).textTheme;
    final percent = result.affectedPercent;
    return [
      // 1. Foto analizada.
      _Photo(bytes: result.photo, height: 230),
      const SizedBox(height: 16),

      // 2. Nombre de la enfermedad, grande.
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: info.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: info.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: info.color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(info.icon, color: Colors.white, size: 38),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if (info.scientificName.isNotEmpty)
                    Text(
                      info.scientificName,
                      style: text.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (result.partial) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hoja mayormente sana, pero se detectó una zona afectada',
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // 3 y 4. Dona con el % afectado + insignia de severidad.
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: Column(
            children: [
              if (percent != null)
                AffectionGauge(
                  percent: percent,
                  color: severityColor(result.severity),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No se pudo separar la hoja del fondo para medir el área '
                    'afectada. Toma la foto más cerca, con la hoja ocupando '
                    'casi toda la imagen.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ),
              const SizedBox(height: 16),
              SeverityBadge(severity: result.severity),
              // 5. Tiempo de análisis (discreto).
              if (result.analysisTimeMs != null) ...[
                const SizedBox(height: 14),
                AnalysisTimeText(ms: result.analysisTimeMs!),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),

      // 6. Botón grande de recomendaciones.
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecommendationsPage(
              label: result.label,
              severity: result.severity,
              partial: result.partial,
              plantId: result.plantId,
              report: result.toReportItem(),
            ),
          ),
        ),
        icon: const Icon(Icons.medical_services_outlined, size: 26),
        label: const Text('Recomendaciones'),
      ),
      const SizedBox(height: 28),

      // 7. Datos técnicos del modelo: pequeños y discretos.
      _ModelDetails(result: result),
    ];
  }

  // ---------------------------------------------------------------- SANA
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
              if (result.analysisTimeMs != null) ...[
                const SizedBox(height: 14),
                AnalysisTimeText(ms: result.analysisTimeMs!),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _Photo(bytes: result.photo),
    ];
  }

  // ------------------------------------- NO RECONOCIDO / NO ES HOJA
  List<Widget> _retry(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              Icon(icon, size: 72, color: colors.outline),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Acércate a una hoja, con buena luz y enfocada.',
                textAlign: TextAlign.center,
                style: text.titleMedium,
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
      _Photo(bytes: result.photo, height: 260),
      const SizedBox(height: 20),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.photo_camera_rounded),
        label: const Text('Tomar otra foto'),
      ),
    ];
  }
}

// ============================================================ Componentes

/// "Análisis en 1.4 s" con ícono de reloj, discreto.
class AnalysisTimeText extends StatelessWidget {
  final int ms;

  const AnalysisTimeText({super.key, required this.ms});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          'Análisis en ${formatAnalysisTime(ms)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Seguridad del modelo y otras posibilidades: letra pequeña, gris suave.
/// Son probabilidades del modelo, NO el porcentaje de hoja afectado.
class _ModelDetails extends StatelessWidget {
  final ResultView result;

  const _ModelDetails({required this.result});

  @override
  Widget build(BuildContext context) {
    final grey = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: grey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seguridad del modelo: ${percentText(result.confidence)}',
          style: small,
        ),
        if (result.top2.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Otras posibilidades', style: small),
          for (final c in result.top2)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2),
              child: Text(
                '• ${DiseaseCatalog.of(c.etiqueta).name}: '
                '${percentText(c.probabilidad)}',
                style: small,
              ),
            ),
        ],
        if (result.mediumConfidence) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Confianza media: toma otra foto con buena luz para '
                  'confirmar',
                  style: small,
                ),
              ),
            ],
          ),
        ],
      ],
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
                  '${percent.toStringAsFixed(1)} %',
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
    final arcRect = (Offset.zero & size).deflate(stroke / 2);
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
        horizontal: compact ? 10 : 20,
        vertical: compact ? 4 : 9,
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
          // Sobre amarillo se lee mejor el texto oscuro.
          color: severity == Severity.moderada
              ? const Color(0xFF3E2C00)
              : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 17,
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final Uint8List? bytes;
  final double? height;

  const _Photo({required this.bytes, this.height});

  @override
  Widget build(BuildContext context) {
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.memory(
        bytes!,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
