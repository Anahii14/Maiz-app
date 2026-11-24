import 'dart:typed_data';

import '../../../_shared/errors/exceptions.dart';
import 'disease_classifier.dart';

DiseaseClassifier createClassifier() => _WebClassifier();

/// TensorFlow Lite no funciona en el navegador.
class _WebClassifier implements DiseaseClassifier {
  static final _error = ServerException(
    'El análisis con IA funciona en la app Android/iOS (sin internet). '
    'La versión web no incluye el modelo.',
  );

  @override
  Future<ModelSpec> load() async => throw _error;

  @override
  Future<List<double>> run(Float32List modelInput) async => throw _error;
}
