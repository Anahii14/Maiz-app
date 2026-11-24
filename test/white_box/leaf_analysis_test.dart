import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mi_app/features/analysis/config/analysis_config.dart';
import 'package:mi_app/features/analysis/model/leaf_diagnosis.dart';
import 'package:mi_app/features/analysis/model/model_config.dart';
import 'package:mi_app/features/analysis/services/disease_classifier.dart';
import 'package:mi_app/features/analysis/services/image_preprocessor.dart';
import 'package:mi_app/features/analysis/services/leaf_analyzer.dart';
import 'package:mi_app/features/analysis/services/leaf_segmenter.dart';

// Colores de prueba (RGB).
const _leafGreen = [60, 140, 50];
const _rustOrange = [200, 90, 20];
const _asphaltBlack = [20, 20, 20];
const _grayLesion = [150, 150, 140];
const _background = [245, 245, 245]; // papel/mesa casi blanca

/// Hoja rectangular de [leafW]x[leafH] centrada en un fondo claro, con
/// manchas cuadradas de [spotSize] que cubren aprox. [fraction] de la hoja.
img.Image _syntheticLeaf({
  int size = 400,
  int leafW = 300,
  int leafH = 200,
  List<int> spotColor = _rustOrange,
  double fraction = 0,
  int spotSize = 10,
  int gap = 10,
}) {
  final image = img.Image(width: size, height: size);
  img.fill(
    image,
    color: img.ColorRgb8(_background[0], _background[1], _background[2]),
  );
  final x0 = (size - leafW) ~/ 2;
  final y0 = (size - leafH) ~/ 2;
  img.fillRect(
    image,
    x1: x0,
    y1: y0,
    x2: x0 + leafW - 1,
    y2: y0 + leafH - 1,
    color: img.ColorRgb8(_leafGreen[0], _leafGreen[1], _leafGreen[2]),
  );
  if (fraction > 0) {
    final target = (leafW * leafH * fraction).round();
    var painted = 0;
    // Manchas en rejilla, separadas, siempre dentro de la hoja.
    outer:
    for (
      var y = y0 + gap;
      y < y0 + leafH - spotSize - gap;
      y += spotSize + gap
    ) {
      for (
        var x = x0 + gap;
        x < x0 + leafW - spotSize - gap;
        x += spotSize + gap
      ) {
        img.fillRect(
          image,
          x1: x,
          y1: y,
          x2: x + spotSize - 1,
          y2: y + spotSize - 1,
          color: img.ColorRgb8(spotColor[0], spotColor[1], spotColor[2]),
        );
        painted += spotSize * spotSize;
        if (painted >= target) break outer;
      }
    }
  }
  return image;
}

/// Clasificador de PRUEBA: devuelve probabilidades fijas (solo en tests).
class _FakeClassifier implements DiseaseClassifier {
  _FakeClassifier(this.output);
  final List<double> output;
  int? lastInputLength;

  static final labels = parseLabels(
    File('assets/models/etiquetas.txt').readAsStringSync(),
  );
  static final config = ModelConfig.fromJson(
    File('assets/models/modelo_config.json').readAsStringSync(),
  );

  @override
  Future<ModelSpec> load() async => ModelSpec(config: config, labels: labels);

  @override
  Future<List<double>> run(Float32List modelInput) async {
    lastInputLength = modelInput.length;
    return output;
  }
}

/// Probabilidades en el orden REAL de etiquetas.txt.
List<double> probs({
  double sana = 0,
  double gris = 0,
  double asfalto = 0,
  double roya = 0,
}) {
  final byLabel = {
    'Hoja_sana': sana,
    'Mancha_Gris_de_la_Hoja': gris,
    'Mancha_de_Asfalto': asfalto,
    'Roya_del_Maíz': roya,
  };
  return [for (final l in _FakeClassifier.labels) byLabel[l]!];
}

void main() {
  group('Modelo, configuración y etiquetas', () {
    test('se leen en el orden real de etiquetas.txt (no asumido)', () {
      expect(_FakeClassifier.labels, [
        'Hoja_sana',
        'Mancha_Gris_de_la_Hoja',
        'Mancha_de_Asfalto',
        'Roya_del_Maíz',
      ]);
    });

    test('normaliza la tilde escrita por separado (i + U+0301)', () {
      final separada = 'Roya_del_Mai${String.fromCharCode(0x301)}z\r\n';
      expect(parseLabels(separada), ['Roya_del_Maíz']);
    });

    test('modelo_config.json: entrada 320, float32, RGB, 0–255, EXIF', () {
      final c = _FakeClassifier.config;
      expect(c.inputSize, 320);
      expect(c.dataType, 'float32');
      expect(c.colorOrder, 'RGB');
      expect(c.divideBy255, isFalse);
      expect(c.applyExif, isTrue);
      final raw = jsonDecode(
        File('assets/models/modelo_config.json').readAsStringSync(),
      );
      expect(raw['redimensionado'], 'directo_sin_recorte');
    });

    test('toProbabilities deja igual una salida softmax', () {
      expect(toProbabilities([0.1, 0.2, 0.7]), [0.1, 0.2, 0.7]);
    });

    test('toProbabilities aplica softmax a "logits"', () {
      final p = toProbabilities([1.0, 3.0, 0.5, -2.0]);
      expect(p.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(p.indexOf(p.reduce((a, b) => a > b ? a : b)), 1);
    });
  });

  group('Severidad', () {
    test('<10 leve, 10–30 moderada, >30 severa', () {
      expect(SeverityX.fromPercent(0.5), Severity.leve);
      expect(SeverityX.fromPercent(9.9), Severity.leve);
      expect(SeverityX.fromPercent(10.0), Severity.moderada);
      expect(SeverityX.fromPercent(30.0), Severity.moderada);
      expect(SeverityX.fromPercent(30.1), Severity.severa);
    });
  });

  group('Preparación de la imagen', () {
    test('tamaño desde la config, RGB, 0–255 sin dividir entre 255', () {
      final image = img.Image(width: 50, height: 50);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final input = ImagePreprocessor.toModelInput(image, 320);
      expect(input.length, 320 * 320 * 3);
      expect(input.sublist(0, 3), [255.0, 0.0, 0.0]); // R, G, B
      expect(input.reduce((a, b) => a > b ? a : b), 255.0);
    });

    test('redimensiona directo, sin recortar (imagen no cuadrada)', () {
      // Mitad izquierda roja, mitad derecha azul: ambas deben seguir ahí.
      final image = img.Image(width: 400, height: 100);
      img.fillRect(
        image,
        x1: 0,
        y1: 0,
        x2: 199,
        y2: 99,
        color: img.ColorRgb8(255, 0, 0),
      );
      img.fillRect(
        image,
        x1: 200,
        y1: 0,
        x2: 399,
        y2: 99,
        color: img.ColorRgb8(0, 0, 255),
      );
      final input = ImagePreprocessor.toModelInput(image, 320);
      expect(input.sublist(0, 3), [255.0, 0.0, 0.0]); // borde izquierdo
      const last = (320 - 1) * 3;
      expect(input.sublist(last, last + 3), [0.0, 0.0, 255.0]); // derecho
    });

    test('respeta la orientación EXIF (foto vertical)', () {
      final image = img.Image(width: 200, height: 100);
      img.fill(image, color: img.ColorRgb8(0, 255, 0));
      image.exif.imageIfd.orientation = 6; // girada 90°
      final jpg = Uint8List.fromList(img.encodeJpg(image));
      final prepared = ImagePreprocessor.prepare(
        PrepareRequest(bytes: jpg, inputSize: 320),
      );
      expect(prepared.segmentationImage.width, 100);
      expect(prepared.segmentationImage.height, 200);
    });

    test('la foto guardada no supera el límite para Firestore', () {
      final big = img.Image(width: 3000, height: 2000);
      for (final p in big) {
        p
          ..r = (p.x * 7) % 256
          ..g = (p.y * 13) % 256
          ..b = (p.x * p.y) % 256;
      }
      final prepared = ImagePreprocessor.prepare(
        PrepareRequest(
          bytes: Uint8List.fromList(img.encodeJpg(big, quality: 95)),
          inputSize: 320,
        ),
      );
      expect(
        prepared.storedJpeg.length,
        lessThanOrEqualTo(AnalysisConfig.storedPhotoMaxBytes),
      );
    });
  });

  group('Segmentación HSV (misma para todas las enfermedades)', () {
    test('verde de hoja → HSV en el rango de hoja', () {
      final (h, s, v) = rgbToHsv(_leafGreen[0], _leafGreen[1], _leafGreen[2]);
      expect(AnalysisConfig.leafRanges.any((r) => r.contains(h, s, v)), isTrue);
    });

    test('hoja sin manchas → 0 % afectado', () {
      final r = segmentLeaf(_syntheticLeaf());
      expect(r.leafFound, isTrue);
      expect(r.affectedPercent, 0.0);
    });

    test('naranja/marrón ~20 % → mide ~20 % e ignora el fondo', () {
      final r = segmentLeaf(_syntheticLeaf(fraction: 0.20));
      expect(r.affectedPercent, closeTo(20, 1.5));
      // La hoja (300x200) ocupa 37,5 % de la imagen 400x400.
      expect(r.leafAreaPercent, closeTo(37.5, 2));
    });

    test('negro dentro de la hoja ~5 % → mide ~5 %', () {
      final r = segmentLeaf(
        _syntheticLeaf(spotColor: _asphaltBlack, fraction: 0.05),
      );
      expect(r.affectedPercent, closeTo(5, 1));
    });

    test('gris dentro de la hoja ~35 % → mide ~35 %', () {
      final r = segmentLeaf(
        _syntheticLeaf(
          spotColor: _grayLesion,
          fraction: 0.35,
          spotSize: 12,
          gap: 5,
        ),
      );
      expect(r.affectedPercent, closeTo(35, 2));
    });

    test('sombra gris FUERA del borde de la hoja no cuenta', () {
      final image = _syntheticLeaf();
      // Franja gris pegada al borde derecho de la hoja (como una sombra).
      img.fillRect(
        image,
        x1: 350,
        y1: 100,
        x2: 365,
        y2: 299,
        color: img.ColorRgb8(_grayLesion[0], _grayLesion[1], _grayLesion[2]),
      );
      expect(segmentLeaf(image).affectedPercent, lessThan(1));
    });

    test('imagen sin hoja → no se mide (null)', () {
      final empty = img.Image(width: 200, height: 200);
      img.fill(empty, color: img.ColorRgb8(240, 240, 240));
      expect(segmentLeaf(empty).affectedPercent, isNull);
    });
  });

  group('LeafAnalyzer (con clasificador de prueba)', () {
    Uint8List leafJpg(double fraction) => Uint8List.fromList(
      img.encodeJpg(
        _syntheticLeaf(fraction: fraction, spotSize: 12, gap: 5),
        quality: 95,
      ),
    );

    test('usa el tamaño de entrada de la config (320)', () async {
      final c = _FakeClassifier(probs(roya: 0.9, sana: 0.1));
      await LeafAnalyzer(c).analyze(leafJpg(0.1));
      expect(c.lastInputLength, 320 * 320 * 3);
    });

    test('todas bajo 0.45 → NO_RECONOCIDO, sin % ni severidad', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(probs(sana: 0.3, roya: 0.3, gris: 0.2, asfalto: 0.2)),
      ).analyze(leafJpg(0.2));
      expect(d.status, EstadoDiagnostico.noReconocido);
      expect(d.affectedPercent, isNull); // no se segmenta
      expect(d.severity, isNull);
    });

    test('sana sin manchas → SANA (el % se mide, sin severidad)', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(
          probs(sana: 0.97, roya: 0.01, gris: 0.01, asfalto: 0.01),
        ),
      ).analyze(leafJpg(0));
      expect(d.status, EstadoDiagnostico.sana);
      expect(d.affectedPercent, 0.0);
      expect(d.severity, isNull);
    });

    test('modelo dice "sana" pero el área ≥ 5 % → ENFERMA parcial', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(
          probs(sana: 0.90, roya: 0.06, gris: 0.02, asfalto: 0.02),
        ),
      ).analyze(leafJpg(0.12));
      expect(d.status, EstadoDiagnostico.enferma);
      expect(d.label, 'Roya_del_Maíz');
      expect(d.partial, isTrue);
      expect(d.severity, Severity.moderada);
    });

    test(
      'el % y la severidad dependen de la imagen (no están fijos)',
      () async {
        final analyzer = LeafAnalyzer(
          _FakeClassifier(probs(roya: 0.91, sana: 0.05, gris: 0.04)),
        );
        final low = await analyzer.analyze(leafJpg(0.04));
        final high = await analyzer.analyze(leafJpg(0.40));
        expect(low.severity, Severity.leve);
        expect(high.severity, Severity.severa);
        expect(high.affectedPercent! > low.affectedPercent!, isTrue);
      },
    );

    test('mide el tiempo de análisis en ms', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(probs(roya: 0.91, sana: 0.09)),
      ).analyze(leafJpg(0.1));
      expect(d.analysisTimeMs, greaterThanOrEqualTo(0));
      expect(formatAnalysisTime(d.analysisTimeMs), endsWith(' s'));
    });
  });
}
