import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../_shared/errors/exceptions.dart';
import '../config/analysis_config.dart';

/// Imagen lista para el análisis.
class PreparedImage {
  /// Entrada del modelo: N x N x 3 float32 (N, orden de color y escala salen
  /// de modelo_config.json). Orden: fila por fila, píxel por píxel.
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

/// Datos para preparar una foto (se envían a otro hilo con compute).
class PrepareRequest {
  final Uint8List bytes;
  final int inputSize;
  final bool bgr;
  final bool divideBy255;
  final bool applyExif;

  const PrepareRequest({
    required this.bytes,
    required this.inputSize,
    this.bgr = false,
    this.divideBy255 = false,
    this.applyExif = true,
  });
}

class ImagePreprocessor {
  ImagePreprocessor._();

  /// Decodifica la foto, aplica la orientación EXIF y prepara las 3 versiones.
  /// Es síncrono y pesado: llamarlo dentro de un isolate (compute).
  static PreparedImage prepare(PrepareRequest request) {
    final decoded = img.decodeImage(request.bytes);
    if (decoded == null) {
      throw ServerException(
        'No se pudo leer la imagen. Usa una foto en formato JPG o PNG.',
      );
    }
    // Gira la imagen según la etiqueta EXIF (fotos de celular en vertical).
    final oriented = request.applyExif ? img.bakeOrientation(decoded) : decoded;
    final rgb = oriented.numChannels == 3 && oriented.format == img.Format.uint8
        ? oriented
        : oriented.convert(format: img.Format.uint8, numChannels: 3);

    return PreparedImage(
      modelInput: toModelInput(
        rgb,
        request.inputSize,
        bgr: request.bgr,
        divideBy255: request.divideBy255,
      ),
      segmentationImage: _fit(rgb, AnalysisConfig.segmentationMaxSide),
      storedJpeg: _encodeStored(rgb),
    );
  }

  /// Redimensiona DIRECTO a [size] x [size] (sin recortar, como el
  /// entrenamiento en Keras) y entrega los píxeles en float32.
  /// Por defecto: orden RGB y valores 0–255 SIN dividir entre 255.
  static Float32List toModelInput(
    img.Image image,
    int size, {
    bool bgr = false,
    bool divideBy255 = false,
  }) {
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    final scale = divideBy255 ? 1 / 255 : 1.0;
    final input = Float32List(size * size * 3);
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        final r = p.r * scale, g = p.g * scale, b = p.b * scale;
        input[i++] = (bgr ? b : r).toDouble();
        input[i++] = g.toDouble();
        input[i++] = (bgr ? r : b).toDouble();
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
