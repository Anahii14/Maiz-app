import 'dart:math' as math;
import 'dart:typed_data';

import '../model/model_config.dart';
import 'classifier_web.dart'
    if (dart.library.ffi) 'tflite_disease_classifier.dart'
    as impl;

/// Lo que se sabe del modelo una vez cargado.
class ModelSpec {
  /// Configuración leída de modelo_config.json (ya verificada con el modelo).
  final ModelConfig config;

  /// Etiquetas leídas SOLO de etiquetas.txt, en el orden de salida.
  final List<String> labels;

  const ModelSpec({required this.config, required this.labels});

  int get inputSize => config.inputSize;
}

/// Clasificador de hojas. Se carga UNA sola vez y se reutiliza.
abstract class DiseaseClassifier {
  /// Carga el modelo (solo la primera vez; luego devuelve lo ya cargado).
  Future<ModelSpec> load();

  /// Ejecuta el modelo y devuelve la probabilidad de cada etiqueta,
  /// en el mismo orden que [ModelSpec.labels].
  Future<List<double>> run(Float32List modelInput);
}

/// Convierte la salida del modelo en probabilidades. Si ya suman 1 (softmax)
/// se dejan igual; si son "logits" se aplica softmax.
List<double> toProbabilities(List<double> output) {
  final sum = output.fold<double>(0, (a, b) => a + b);
  final looksLikeProbs =
      output.every((p) => p >= 0 && p <= 1) && (sum - 1).abs() < 0.01;
  if (looksLikeProbs) return List<double>.from(output);
  final maxV = output.reduce(math.max);
  final exps = output.map((v) => math.exp(v - maxV)).toList();
  final total = exps.fold<double>(0, (a, b) => a + b);
  return exps.map((e) => e / total).toList();
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
