import 'dart:convert';

import '../../../_shared/errors/exceptions.dart';

/// Valores de `assets/models/modelo_config.json`: cómo se debe preparar la
/// imagen para el modelo. La app NO asume el tamaño de entrada: lo lee aquí
/// y además lo compara con el modelo real al cargarlo.
class ModelConfig {
  final String modelFile;
  final String labelsFile;
  final int inputSize;
  final int channels;
  final String dataType;
  final String colorOrder;
  final bool divideBy255;
  final String resize;
  final bool applyExif;

  const ModelConfig({
    required this.modelFile,
    required this.labelsFile,
    required this.inputSize,
    this.channels = 3,
    this.dataType = 'float32',
    this.colorOrder = 'RGB',
    this.divideBy255 = false,
    this.resize = 'directo_sin_recorte',
    this.applyExif = true,
  });

  factory ModelConfig.fromJson(String raw) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw ServerException('modelo_config.json no es un JSON válido.');
    }
    final size = j['tamano_entrada'];
    if (size is! int || size <= 0) {
      throw ServerException(
        'modelo_config.json: falta "tamano_entrada" (número entero).',
      );
    }
    final config = ModelConfig(
      modelFile: (j['modelo'] ?? 'modelo_plantas.tflite') as String,
      labelsFile: (j['etiquetas'] ?? 'etiquetas.txt') as String,
      inputSize: size,
      channels: (j['canales'] ?? 3) as int,
      dataType: ((j['tipo_dato'] ?? 'float32') as String).toLowerCase(),
      colorOrder: ((j['orden_color'] ?? 'RGB') as String).toUpperCase(),
      divideBy255: (j['dividir_entre_255'] ?? false) as bool,
      resize: (j['redimensionado'] ?? 'directo_sin_recorte') as String,
      applyExif: (j['aplicar_orientacion_exif'] ?? true) as bool,
    );
    if (config.channels != 3 ||
        config.dataType != 'float32' ||
        (config.colorOrder != 'RGB' && config.colorOrder != 'BGR')) {
      throw ServerException(
        'modelo_config.json: la app solo admite 3 canales float32 RGB o BGR.',
      );
    }
    return config;
  }
}
