import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../_shared/errors/exceptions.dart';
import '../config/analysis_config.dart';
import '../model/model_config.dart';
import 'disease_classifier.dart';

DiseaseClassifier createClassifier() => TfliteDiseaseClassifier();

/// Implementación real con TensorFlow Lite (funciona sin internet).
///
/// El intérprete se crea UNA sola vez (la primera vez que se pide, o antes
/// con [load] al abrir la pantalla de análisis) y se reutiliza en cada foto.
class TfliteDiseaseClassifier implements DiseaseClassifier {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  Future<ModelSpec>? _loading;

  @override
  Future<ModelSpec> load() => _loading ??= _load();

  Future<ModelSpec> _load() async {
    try {
      final sw = Stopwatch()..start();
      final config = ModelConfig.fromJson(
        await rootBundle.loadString(AnalysisConfig.modelConfigAsset),
      );
      final labels = parseLabels(
        await rootBundle.loadString(
          '${AnalysisConfig.modelsFolder}/${config.labelsFile}',
        ),
      );
      final interpreter = await Interpreter.fromAsset(
        '${AnalysisConfig.modelsFolder}/${config.modelFile}',
        // Varios núcleos del procesador: el análisis es mucho más rápido.
        options: InterpreterOptions()..threads = AnalysisConfig.cpuThreads,
      );
      _checkShapes(interpreter, config, labels);
      _interpreter = interpreter;
      _isolate = await IsolateInterpreter.create(address: interpreter.address);
      debugPrint(
        '[MODELO] cargado una vez en ${sw.elapsedMilliseconds} ms · '
        'entrada ${config.inputSize}x${config.inputSize} · etiquetas $labels',
      );
      return ModelSpec(config: config, labels: labels);
    } catch (e) {
      _loading = null; // permite reintentar
      if (e is ServerException) rethrow;
      throw ServerException('No se pudo cargar el modelo de IA: $e');
    }
  }

  /// Verifica que modelo_config.json y etiquetas.txt coincidan con el modelo.
  void _checkShapes(
    Interpreter interpreter,
    ModelConfig config,
    List<String> labels,
  ) {
    final s = config.inputSize;
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final okInput =
        input.shape.length == 4 &&
        input.shape[1] == s &&
        input.shape[2] == s &&
        input.shape[3] == config.channels &&
        input.type == TensorType.float32;
    if (!okInput) {
      throw ServerException(
        'El modelo espera ${input.shape} ${input.type}, pero '
        'modelo_config.json indica [1, $s, $s, ${config.channels}] float32.',
      );
    }
    if (output.shape.last != labels.length) {
      throw ServerException(
        'El modelo tiene ${output.shape.last} clases y etiquetas.txt '
        '${labels.length}.',
      );
    }
  }

  @override
  Future<List<double>> run(Float32List modelInput) async {
    final spec = await load();
    final outputBytes = Uint8List(spec.labels.length * 4);
    await _isolate!.run(modelInput.buffer, outputBytes);
    return toProbabilities(outputBytes.buffer.asFloat32List().toList());
  }

  void dispose() {
    _isolate?.close();
    _interpreter?.close();
  }
}
