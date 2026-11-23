import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../config/analysis_config.dart';
import '../model/leaf_diagnosis.dart';
import 'disease_classifier.dart';
import 'image_preprocessor.dart';
import 'leaf_segmenter.dart';

/// Analiza una foto de hoja de maíz. El resultado depende SOLO de la imagen.
class LeafAnalyzer {
  LeafAnalyzer(this._classifier);

  final DiseaseClassifier _classifier;

  Future<LeafDiagnosis> analyze(Uint8List photoBytes) async {
    // 1) Decodificar, corregir orientación EXIF y preparar (en otro hilo).
    final prepared = await compute(ImagePreprocessor.prepare, photoBytes);

    // 2) Clasificar con el modelo TFLite.
    final result = await _classifier.classify(prepared.modelInput);

    // 3) Confianza insuficiente: no se muestra ninguna enfermedad.
    if (result.confidence < AnalysisConfig.minConfidence) {
      return LeafDiagnosis(
        status: DiagnosisStatus.notRecognized,
        label: result.label,
        confidence: result.confidence,
        probabilities: result.probabilities,
        photoJpeg: prepared.storedJpeg,
      );
    }

    // 4) Hoja sana: sin porcentaje ni severidad.
    if (result.label == AnalysisConfig.healthyLabel) {
      return LeafDiagnosis(
        status: DiagnosisStatus.healthy,
        label: result.label,
        confidence: result.confidence,
        probabilities: result.probabilities,
        photoJpeg: prepared.storedJpeg,
      );
    }

    // 5) Enfermedad: medir el área afectada y calcular la severidad.
    final segmentation = await compute(_segment, (
      prepared.segmentationImage,
      result.label,
    ));
    final percent = segmentation.affectedPercent;
    return LeafDiagnosis(
      status: DiagnosisStatus.disease,
      label: result.label,
      confidence: result.confidence,
      probabilities: result.probabilities,
      photoJpeg: prepared.storedJpeg,
      affectedPercent: percent,
      severity: percent == null ? null : SeverityX.fromPercent(percent),
    );
  }
}

SegmentationResult _segment((img.Image, String) args) =>
    segmentLeaf(args.$1, args.$2);
