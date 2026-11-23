import 'dart:math' as math;
import 'dart:typed_data';

import '../../../_shared/errors/exceptions.dart';
import 'classifier_web.dart'
    if (dart.library.ffi) 'tflite_disease_classifier.dart'
    as impl;

/// Resultado crudo del modelo.
class Classification {
  final String label;
  final double confidence;
  final Map<String, double> probabilities;

  const Classification({
    required this.label,
    required this.confidence,
    required this.probabilities,
  });
}

/// Clasifica una hoja a partir de la entrada 224x224x3 (float32, 0–255).
abstract class DiseaseClassifier {
  Future<Classification> classify(Float32List modelInput);
}

/// Elige la clase con mayor probabilidad. Si la salida no suma 1 (logits),
/// aplica softmax. Separado para poder probarlo sin el modelo.
Classification pickTop(List<double> output, List<String> labels) {
  if (output.length != labels.length) {
    throw ServerException(
      'El modelo devolvió ${output.length} valores pero hay '
      '${labels.length} etiquetas en etiquetas.txt.',
    );
  }
  var probs = output;
  final sum = output.fold<double>(0, (a, b) => a + b);
  final looksLikeProbs =
      output.every((p) => p >= 0 && p <= 1) && (sum - 1).abs() < 0.01;
  if (!looksLikeProbs) {
    final maxV = output.reduce(math.max);
    final exps = output.map((v) => math.exp(v - maxV)).toList();
    final total = exps.fold<double>(0, (a, b) => a + b);
    probs = exps.map((e) => e / total).toList();
  }
  var best = 0;
  for (var i = 1; i < probs.length; i++) {
    if (probs[i] > probs[best]) best = i;
  }
  return Classification(
    label: labels[best],
    confidence: probs[best],
    probabilities: {
      for (var i = 0; i < labels.length; i++) labels[i]: probs[i],
    },
  );
}

/// Lee etiquetas.txt: una etiqueta por línea, en el orden de salida del modelo.
List<String> parseLabels(String raw) => raw
    .replaceAll('\uFEFF', '') // BOM de algunos editores
    .split(RegExp(r'\r?\n'))
    .map((l) => normalizeLabel(l.trim()))
    .where((l) => l.isNotEmpty)
    .toList();

/// Une letras + tilde escritas por separado (p. ej. "i" + "\u0301") en un solo
/// carácter ("í"), para que "Roya_del_Maíz" coincida siempre con la
/// configuración, sin importar cómo guardó el archivo el editor de texto.
String normalizeLabel(String label) {
  const acute = {
    'a': 'á',
    'e': 'é',
    'i': 'í',
    'o': 'ó',
    'u': 'ú',
    'A': 'Á',
    'E': 'É',
    'I': 'Í',
    'O': 'Ó',
    'U': 'Ú',
  };
  return label
      .replaceAllMapped(RegExp('([aeiouAEIOU])\u0301'), (m) => acute[m[1]!]!)
      .replaceAll('n\u0303', 'ñ')
      .replaceAll('N\u0303', 'Ñ')
      .replaceAll('u\u0308', 'ü')
      .replaceAll('U\u0308', 'Ü');
}

/// Crea el clasificador real: TFLite en Android/iOS (sin internet).
/// En la versión web no existe TFLite y se informa al usuario.
DiseaseClassifier createDiseaseClassifier() => impl.createClassifier();
