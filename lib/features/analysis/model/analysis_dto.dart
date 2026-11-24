import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/disease_catalog.dart';
import 'leaf_diagnosis.dart';

enum AnalysisType { hoja, terreno }

extension AnalysisTypeLabel on AnalysisType {
  String get label => this == AnalysisType.hoja ? 'Hoja' : 'Terreno';

  String get storageKey => this == AnalysisType.hoja ? 'hoja' : 'terreno';

  static AnalysisType fromString(String? value) {
    return value == 'terreno' ? AnalysisType.terreno : AnalysisType.hoja;
  }
}

/// Un análisis guardado en Firestore: users/{uid}/analyses/{id}.
/// Todos los valores salen del modelo y de la foto; nada es inventado.
class AnalysisDto {
  final String plantId;
  final String plantName;
  final AnalysisType type;

  /// Etiqueta del modelo (p. ej. "Roya_del_Maíz" o "Hoja_sana").
  final String label;

  /// Probabilidad de esa etiqueta según el modelo (0–1).
  final double confidence;

  /// % de área afectada medido por HSV (en hoja sana se guarda pero no se
  /// muestra). Nunca es una probabilidad del modelo.
  final double? affectionPercent;

  /// Severidad (solo enfermedades; null en hoja sana).
  final Severity? severity;

  /// El modelo dijo "sana" pero se detectó una zona afectada.
  final bool partial;

  /// La enfermedad ganó con confianza media (< 70 %).
  final bool mediumConfidence;

  /// Las dos clases más probables según el modelo.
  final List<ClaseProbable> top2;

  /// Tiempo de análisis en milisegundos.
  final int? analysisTimeMs;

  /// Fecha del análisis (hora del servidor de Firebase).
  final DateTime date;

  /// Foto analizada (JPEG reducido).
  final Uint8List? photo;

  const AnalysisDto({
    required this.plantId,
    required this.plantName,
    required this.type,
    required this.label,
    required this.confidence,
    required this.date,
    this.affectionPercent,
    this.severity,
    this.photo,
    this.partial = false,
    this.mediumConfidence = false,
    this.top2 = const [],
    this.analysisTimeMs,
  });

  factory AnalysisDto.fromDiagnosis({
    required LeafDiagnosis diagnosis,
    required String plantId,
    required String plantName,
  }) {
    return AnalysisDto(
      plantId: plantId,
      plantName: plantName,
      type: AnalysisType.hoja,
      label: diagnosis.label,
      confidence: diagnosis.confidence,
      affectionPercent: diagnosis.affectedPercent,
      severity: diagnosis.severity,
      date: DateTime.now(),
      photo: diagnosis.photoJpeg,
      partial: diagnosis.partial,
      mediumConfidence: diagnosis.mediumConfidence,
      top2: diagnosis.top2,
      analysisTimeMs: diagnosis.analysisTimeMs,
    );
  }

  bool get isHealthy => label == claseSana;

  /// Nombre legible de la enfermedad (o "Hoja sana").
  String get disease => DiseaseCatalog.of(label).name;

  /// Texto corto: "Roya del maíz · 12.5% · Moderada" o "Hoja sana".
  String get summary {
    if (isHealthy) return disease;
    final parts = [disease];
    if (affectionPercent != null) {
      parts.add('${affectionPercent!.toStringAsFixed(1)}%');
    }
    if (severity != null) parts.add(severity!.label);
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() {
    return {
      'plantId': plantId,
      'plantName': plantName,
      'type': type.storageKey,
      'label': label,
      'disease': disease,
      'confidence': confidence,
      'affectionPercent': affectionPercent,
      'severity': severity?.name,
      'date': FieldValue.serverTimestamp(),
      'photo': photo == null ? null : Blob(photo!),
      'parcial': partial,
      'confianza_media': mediumConfidence,
      'otras_posibilidades': [
        for (final c in top2)
          {'etiqueta': c.etiqueta, 'probabilidad': c.probabilidad},
      ],
      'tiempo_analisis_ms': analysisTimeMs,
    };
  }

  factory AnalysisDto.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    final rawPhoto = map['photo'];
    return AnalysisDto(
      plantId: (map['plantId'] ?? '') as String,
      plantName: (map['plantName'] ?? '') as String,
      type: AnalysisTypeLabel.fromString(map['type'] as String?),
      label: (map['label'] ?? map['disease'] ?? '') as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      affectionPercent: (map['affectionPercent'] as num?)?.toDouble(),
      severity: SeverityX.tryParse(map['severity'] as String?),
      // Mientras el servidor confirma la escritura, la fecha llega vacía.
      date: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      photo: rawPhoto is Blob ? rawPhoto.bytes : null,
      partial: map['parcial'] == true,
      mediumConfidence: map['confianza_media'] == true,
      top2: [
        for (final c in (map['otras_posibilidades'] as List<dynamic>? ?? []))
          if (c is Map)
            ClaseProbable(
              (c['etiqueta'] ?? '') as String,
              (c['probabilidad'] as num?)?.toDouble() ?? 0,
            ),
      ],
      analysisTimeMs: (map['tiempo_analisis_ms'] as num?)?.toInt(),
    );
  }
}

class AnalysisEntry {
  final String id;
  final AnalysisDto dto;

  const AnalysisEntry({required this.id, required this.dto});
}
