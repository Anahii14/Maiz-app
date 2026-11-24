import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../logic/decision.dart';
import '../model/leaf_diagnosis.dart';
import 'disease_classifier.dart';
import 'image_preprocessor.dart';
import 'leaf_segmenter.dart';

/// Analiza una foto de hoja de maíz. El resultado depende SOLO de la imagen.
class LeafAnalyzer {
  LeafAnalyzer(this._classifier);

  final DiseaseClassifier _classifier;

  /// Carga el modelo por adelantado (al abrir la pantalla de análisis), para
  /// que la primera foto no espere. El modelo se carga una sola vez.
  Future<void> warmUp() async {
    try {
      await _classifier.load();
    } catch (_) {
      // Si falla, se reintentará (y se mostrará el error) al analizar.
    }
  }

  /// [clock]: reloj monotónico ya iniciado al recibir la imagen. Si no se
  /// pasa, se inicia aquí.
  Future<LeafDiagnosis> analyze(
    Uint8List photoBytes, {
    Stopwatch? clock,
  }) async {
    final sw = clock ?? (Stopwatch()..start());
    final spec = await _classifier.load(); // ya cargado: no se recarga

    // 1) Decodificar, aplicar EXIF y preparar según modelo_config.json.
    final prepared = await compute(
      ImagePreprocessor.prepare,
      PrepareRequest(
        bytes: photoBytes,
        inputSize: spec.inputSize,
        bgr: spec.config.colorOrder == 'BGR',
        divideBy255: spec.config.divideBy255,
        applyExif: spec.config.applyExif,
      ),
    );

    // 2) Inferencia con el modelo TFLite.
    final output = await _classifier.run(prepared.modelInput);
    final probabilities = {
      for (var i = 0; i < spec.labels.length; i++) spec.labels[i]: output[i],
    };

    // 3) Primera decisión (sin área) para saber si hay que segmentar.
    final preliminary = decidir(probabilities, null);
    double? area;
    if (preliminary.estado != EstadoDiagnostico.noReconocido &&
        preliminary.estado != EstadoDiagnostico.noEsHoja) {
      // 4) Segmentación HSV: SIEMPRE, también si el modelo dice "sana".
      area = (await compute(
        _segment,
        prepared.segmentationImage,
      )).affectedPercent;
    }

    // 5) Decisión final con el área medida.
    final decision = decidir(probabilities, area);
    final isDisease = decision.estado == EstadoDiagnostico.enferma;
    sw.stop();

    final diagnosis = LeafDiagnosis(
      status: decision.estado,
      label: decision.enfermedad ?? decision.top2.first.etiqueta,
      confidence: decision.confianza,
      partial: decision.parcial,
      mediumConfidence: decision.confianzaMedia,
      top2: decision.top2,
      probabilities: probabilities,
      affectedPercent: area,
      severity: isDisease && area != null ? SeverityX.fromPercent(area) : null,
      analysisTimeMs: sw.elapsedMilliseconds,
      rule: decision.regla,
      photoJpeg: prepared.storedJpeg,
    );

    if (logsDeDecision) {
      // LOG TEMPORAL para calibrar umbrales con fotos reales.
      debugPrint(
        '[ANALISIS] probs={${probabilities.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(4)}').join(', ')}} '
        '| area=${area?.toStringAsFixed(1) ?? 'no medida'} % '
        '| tiempo=${diagnosis.analysisTimeMs} ms '
        '| regla=${decision.regla} '
        '| resultado=${decision.estado.name} ${decision.enfermedad ?? ''}',
      );
    }
    return diagnosis;
  }
}

SegmentationResult _segment(img.Image image) => segmentLeaf(image);
