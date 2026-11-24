import 'dart:typed_data';

import '../config/analysis_config.dart';
import '../logic/decision.dart';

export '../logic/decision.dart'
    show EstadoDiagnostico, ClaseProbable, claseSana;

/// Severidad del daño según el % de área afectada (ver AnalysisConfig).
enum Severity { leve, moderada, severa }

extension SeverityX on Severity {
  String get label => switch (this) {
    Severity.leve => 'Leve',
    Severity.moderada => 'Moderada',
    Severity.severa => 'Severa',
  };

  /// < 10 % Leve · 10 % a 30 % Moderada · > 30 % Severa.
  static Severity fromPercent(double percent) {
    if (percent < AnalysisConfig.severityModerateFrom) return Severity.leve;
    if (percent <= AnalysisConfig.severitySevereAbove) return Severity.moderada;
    return Severity.severa;
  }

  static Severity? tryParse(String? value) {
    for (final s in Severity.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

/// Formatea el tiempo de análisis: "1.4 s"; si es menor a 1 s, "0.85 s".
String formatAnalysisTime(int ms) {
  final seconds = ms / 1000;
  return seconds < 1
      ? '${seconds.toStringAsFixed(2)} s'
      : '${seconds.toStringAsFixed(1)} s';
}

/// Resultado completo de analizar UNA foto.
class LeafDiagnosis {
  final EstadoDiagnostico status;

  /// Enfermedad mostrada (si ENFERMA) o la clase ganadora (en otros casos).
  final String label;

  /// Probabilidad de la clase mostrada.
  final double confidence;

  /// El modelo dijo "sana" pero se detectó una zona afectada.
  final bool partial;

  /// La enfermedad ganó con confianza media (< 70 %).
  final bool mediumConfidence;

  /// Las dos clases más probables.
  final List<ClaseProbable> top2;

  /// Probabilidad de cada etiqueta (orden de etiquetas.txt).
  final Map<String, double> probabilities;

  /// % de área afectada (HSV, 1 decimal). null si no se midió.
  final double? affectedPercent;

  /// Severidad (solo si ENFERMA y el % se pudo medir).
  final Severity? severity;

  /// Tiempo de análisis en milisegundos (preprocesamiento + inferencia +
  /// segmentación + decisión).
  final int analysisTimeMs;

  /// Regla de decisión aplicada (para logs y la tesis).
  final String rule;

  /// Foto analizada (JPEG reducido, con la orientación ya corregida).
  final Uint8List photoJpeg;

  const LeafDiagnosis({
    required this.status,
    required this.label,
    required this.confidence,
    required this.top2,
    required this.probabilities,
    required this.analysisTimeMs,
    required this.rule,
    required this.photoJpeg,
    this.partial = false,
    this.mediumConfidence = false,
    this.affectedPercent,
    this.severity,
  });

  bool get isDisease => status == EstadoDiagnostico.enferma;
}
