import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../_shared/errors/exceptions.dart';
import '../config/analysis_config.dart';

/// Imagen lista para el análisis.
class PreparedImage {
  /// Entrada del modelo: 224 x 224 x 3, float32, RGB, valores 0–255
  /// (sin dividir entre 255). Orden: fila por fila, píxel por píxel, R G B.
  final Float32List modelInput;

  /// Imagen reducida para medir el área afectada.
  final img.Image segmentationImage;

  /// Foto JPEG reducida para mostrar y guardar en el historial.
  final Uint8List storedJpeg;

  const PreparedImage({
    required this.modelInput,
    required this.segmentationImage,
    required this.storedJpeg,
  });
}

class ImagePreprocessor {
  ImagePreprocessor._();

  /// Decodifica la foto, corrige la orientación EXIF y prepara las 3 versiones.
  /// Es síncrono y pesado: llamarlo dentro de un isolate (compute).
  static PreparedImage prepare(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ServerException(
        'No se pudo leer la imagen. Usa una foto en formato JPG o PNG.',
      );
    }
    // Gira la imagen según la etiqueta EXIF (fotos de celular en vertical).
    final oriented = img.bakeOrientation(decoded);
    final rgb = oriented.numChannels == 3 && oriented.format == img.Format.uint8
        ? oriented
        : oriented.convert(format: img.Format.uint8, numChannels: 3);

    return PreparedImage(
      modelInput: toModelInput(rgb),
      segmentationImage: _fit(rgb, AnalysisConfig.segmentationMaxSide),
      storedJpeg: _encodeStored(rgb),
    );
  }

  /// Redimensiona a 224 x 224 (sin recortar, como el entrenamiento en Keras)
  /// y entrega los píxeles RGB en 0–255 como float32.
  static Float32List toModelInput(img.Image image) {
    const size = AnalysisConfig.inputSize;
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    final input = Float32List(size * size * 3);
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        input[i++] = p.r.toDouble();
        input[i++] = p.g.toDouble();
        input[i++] = p.b.toDouble();
      }
    }
    return input;
  }

  static img.Image _fit(img.Image image, int maxSide) {
    if (image.width <= maxSide && image.height <= maxSide) return image;
    final landscape = image.width >= image.height;
    return img.copyResize(
      image,
      width: landscape ? maxSide : null,
      height: landscape ? null : maxSide,
      interpolation: img.Interpolation.average,
    );
  }

  static Uint8List _encodeStored(img.Image image) {
    var side = AnalysisConfig.storedPhotoMaxSide;
    var quality = AnalysisConfig.storedPhotoQuality;
    while (true) {
      final jpg = Uint8List.fromList(
        img.encodeJpg(_fit(image, side), quality: quality),
      );
      if (jpg.length <= AnalysisConfig.storedPhotoMaxBytes || side <= 320) {
        return jpg;
      }
      if (quality > 55) {
        quality -= 10;
      } else {
        side = (side * 0.75).round();
      }
    }
  }
}
