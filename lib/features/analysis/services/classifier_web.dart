import 'dart:typed_data';

import '../../../_shared/errors/exceptions.dart';
import 'disease_classifier.dart';

DiseaseClassifier createClassifier() => _WebClassifier();

/// TensorFlow Lite no funciona en el navegador.
class _WebClassifier implements DiseaseClassifier {
  @override
  Future<Classification> classify(Float32List modelInput) async {
    throw ServerException(
      'El análisis con IA funciona en la app Android/iOS (sin internet). '
      'La versión web no incluye el modelo.',
    );
  }
}
