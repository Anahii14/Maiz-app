import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../_shared/errors/exceptions.dart';
import '../config/analysis_config.dart';
import 'disease_classifier.dart';

DiseaseClassifier createClassifier() => TfliteDiseaseClassifier();

/// Implementación real con TensorFlow Lite (funciona sin internet).
class TfliteDiseaseClassifier implements DiseaseClassifier {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  List<String>? _labels;
  Future<void>? _loading;

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      _labels = parseLabels(
        await rootBundle.loadString(AnalysisConfig.labelsAsset),
      );
      final interpreter = await Interpreter.fromAsset(
        AnalysisConfig.modelAsset,
      );
      _checkShapes(interpreter);
      _interpreter = interpreter;
      _isolate = await IsolateInterpreter.create(address: interpreter.address);
    } catch (e) {
      _loading = null; // permite reintentar
      if (e is ServerException) rethrow;
      throw ServerException('No se pudo cargar el modelo de IA: $e');
    }
  }

  void _checkShapes(Interpreter interpreter) {
    const s = AnalysisConfig.inputSize;
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final okInput =
        input.shape.length == 4 &&
        input.shape[1] == s &&
        input.shape[2] == s &&
        input.shape[3] == 3 &&
        input.type == TensorType.float32;
    if (!okInput) {
      throw ServerException(
        'El modelo espera ${input.shape} ${input.type}, '
        'pero la app envía [1, $s, $s, 3] float32.',
      );
    }
    if (output.shape.last != _labels!.length) {
      throw ServerException(
        'El modelo tiene ${output.shape.last} clases y etiquetas.txt '
        '${_labels!.length}.',
      );
    }
  }

  @override
  Future<Classification> classify(Float32List modelInput) async {
    await _ensureLoaded();
    final labels = _labels!;
    final outputBytes = Uint8List(labels.length * 4);
    await _isolate!.run(modelInput.buffer, outputBytes);
    final output = outputBytes.buffer.asFloat32List().toList();
    return pickTop(output, labels);
  }

  void dispose() {
    _isolate?.close();
    _interpreter?.close();
  }
}
