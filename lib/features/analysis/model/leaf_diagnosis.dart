import 'dart:typed_data';

import '../config/analysis_config.dart';

/// Severidad del daño según el % de área afectada (ver AnalysisConfig).
enum Severity { leve, moderada, severa }

extension SeverityX on Severity {
  String get label => switch (this) {
    Severity.leve => 'Leve',
    Severity.moderada => 'Moderada',
    Severity.severa => 'Severa',
  };

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

enum DiagnosisStatus {
  /// Confianza menor al umbral: no se muestra ninguna enfermedad.
  notRecognized,

  /// El modelo reconoce una hoja sana.
  healthy,

  /// El modelo reconoce una enfermedad.
  disease,
}

/// Resultado completo de analizar UNA foto.
class LeafDiagnosis {
  final DiagnosisStatus status;

  /// Etiqueta del modelo con mayor probabilidad (p. ej. "Roya_del_Maíz").
  final String label;

  /// Probabilidad de esa etiqueta (0–1).
  final double confidence;

  /// Probabilidad de cada etiqueta, en el orden de etiquetas.txt.
  final Map<String, double> probabilities;

  /// % de área afectada (1 decimal). Solo para enfermedades; null si la hoja
  /// no se pudo separar del fondo.
  final double? affectedPercent;

  /// Severidad según [affectedPercent]. Solo para enfermedades.
  final Severity? severity;

  /// Foto analizada (JPEG reducido, ya con la orientación corregida).
  final Uint8List photoJpeg;

  const LeafDiagnosis({
    required this.status,
    required this.label,
    required this.confidence,
    required this.probabilities,
    required this.photoJpeg,
    this.affectedPercent,
    this.severity,
  });
}
