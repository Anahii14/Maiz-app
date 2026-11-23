import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mi_app/features/analysis/config/analysis_config.dart';
import 'package:mi_app/features/analysis/config/recommendations.dart';
import 'package:mi_app/features/analysis/model/leaf_diagnosis.dart';
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

class _FakeClassifier implements DiseaseClassifier {
  _FakeClassifier(this.result);
  final Classification result;
  @override
  Future<Classification> classify(Float32List modelInput) async => result;
}

void main() {
  group('Etiquetas del modelo', () {
    test('se leen en el orden real de etiquetas.txt (no asumido)', () {
      final labels = parseLabels(
        File('assets/models/etiquetas.txt').readAsStringSync(),
      );
      expect(labels, [
        'Hoja_sana',
        'Mancha_Gris_de_la_Hoja',
        'Mancha_de_Asfalto',
        'Roya_del_Maíz',
      ]);
      // Todas las enfermedades tienen rangos HSV y recomendaciones.
      for (final l in labels.where((l) => l != AnalysisConfig.healthyLabel)) {
        expect(
          AnalysisConfig.lesionRangesByLabel.containsKey(l),
          isTrue,
          reason: l,
        );
        expect(Recommendations.byLabel.containsKey(l), isTrue, reason: l);
      }
    });

    test('normaliza la tilde escrita por separado (i + U+0301)', () {
      expect(parseLabels('Roya_del_Mai\u0301z\r\n'), ['Roya_del_Ma\u00edz']);
    });

    test('pickTop elige la mayor probabilidad', () {
      final c = pickTop([0.05, 0.10, 0.80, 0.05], ['a', 'b', 'c', 'd']);
      expect(c.label, 'c');
      expect(c.confidence, closeTo(0.80, 1e-9));
    });

    test('pickTop aplica softmax si la salida no son probabilidades', () {
      final c = pickTop([1.0, 3.0, 0.5, -2.0], ['a', 'b', 'c', 'd']);
      expect(c.label, 'b');
      final total = c.probabilities.values.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1, 1e-9));
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
    test('entrada 224x224x3, RGB, valores 0–255 sin normalizar', () {
      final image = img.Image(width: 50, height: 50);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final input = ImagePreprocessor.toModelInput(image);
      expect(input.length, 224 * 224 * 3);
      expect(input.sublist(0, 3), [255.0, 0.0, 0.0]); // R, G, B
      expect(input.reduce((a, b) => a > b ? a : b), 255.0);
    });

    test('respeta la orientación EXIF (foto vertical)', () {
      final image = img.Image(width: 200, height: 100);
      img.fill(image, color: img.ColorRgb8(0, 255, 0));
      image.exif.imageIfd.orientation = 6; // girada 90°
      final jpg = Uint8List.fromList(img.encodeJpg(image));
      final prepared = ImagePreprocessor.prepare(jpg);
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
        Uint8List.fromList(img.encodeJpg(big, quality: 95)),
      );
      expect(
        prepared.storedJpeg.length,
        lessThanOrEqualTo(AnalysisConfig.storedPhotoMaxBytes),
      );
    });
  });

  group('Segmentación HSV', () {
    test('verde de hoja → HSV en el rango de hoja', () {
      final (h, s, v) = rgbToHsv(_leafGreen[0], _leafGreen[1], _leafGreen[2]);
      expect(AnalysisConfig.leafRanges.any((r) => r.contains(h, s, v)), isTrue);
    });

    test('hoja sin manchas → 0 % afectado', () {
      final r = segmentLeaf(_syntheticLeaf(), 'Roya_del_Maíz');
      expect(r.leafFound, isTrue);
      expect(r.affectedPercent, 0.0);
    });

    test('roya ~20 % → mide ~20 % e ignora el fondo', () {
      final r = segmentLeaf(_syntheticLeaf(fraction: 0.20), 'Roya_del_Maíz');
      expect(r.affectedPercent, closeTo(20, 1.5));
      // La hoja (300x200) ocupa 37,5 % de la imagen 400x400.
      expect(r.leafAreaPercent, closeTo(37.5, 2));
    });

    test('mancha de asfalto ~5 % → mide ~5 %', () {
      final r = segmentLeaf(
        _syntheticLeaf(spotColor: _asphaltBlack, fraction: 0.05),
        'Mancha_de_Asfalto',
      );
      expect(r.affectedPercent, closeTo(5, 1));
    });

    test('mancha gris ~35 % → mide ~35 %', () {
      final r = segmentLeaf(
        _syntheticLeaf(
          spotColor: _grayLesion,
          fraction: 0.35,
          spotSize: 12,
          gap: 5,
        ),
        'Mancha_Gris_de_la_Hoja',
      );
      expect(r.affectedPercent, closeTo(35, 2));
    });

    test('las manchas solo cuentan para su enfermedad', () {
      // Puntos negros no son pústulas de roya.
      final r = segmentLeaf(
        _syntheticLeaf(spotColor: _asphaltBlack, fraction: 0.10),
        'Roya_del_Maíz',
      );
      expect(r.affectedPercent, lessThan(1));
    });

    test('imagen sin hoja → no se mide (null)', () {
      final empty = img.Image(width: 200, height: 200);
      img.fill(empty, color: img.ColorRgb8(240, 240, 240));
      expect(segmentLeaf(empty, 'Roya_del_Maíz').affectedPercent, isNull);
    });
  });

  group('LeafAnalyzer (con clasificador de prueba)', () {
    Uint8List leafJpg(double fraction) => Uint8List.fromList(
      img.encodeJpg(
        _syntheticLeaf(fraction: fraction, spotSize: 12, gap: 5),
        quality: 95,
      ),
    );

    Classification cls(String label, double conf) => Classification(
      label: label,
      confidence: conf,
      probabilities: {label: conf},
    );

    test('confianza < 70 % → No reconocido, sin enfermedad ni %', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(cls('Roya_del_Maíz', 0.69)),
      ).analyze(leafJpg(0.2));
      expect(d.status, DiagnosisStatus.notRecognized);
      expect(d.affectedPercent, isNull);
      expect(d.severity, isNull);
    });

    test('hoja sana → sin porcentaje ni severidad', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(cls('Hoja_sana', 0.95)),
      ).analyze(leafJpg(0));
      expect(d.status, DiagnosisStatus.healthy);
      expect(d.affectedPercent, isNull);
      expect(d.severity, isNull);
    });

    test('enfermedad → % medido sobre la foto y severidad', () async {
      final d = await LeafAnalyzer(
        _FakeClassifier(cls('Roya_del_Maíz', 0.91)),
      ).analyze(leafJpg(0.2));
      expect(d.status, DiagnosisStatus.disease);
      expect(d.affectedPercent, closeTo(20, 2.5));
      expect(d.severity, Severity.moderada);
      expect(d.photoJpeg, isNotEmpty);
    });

    test('el resultado cambia con la imagen (no está fijo)', () async {
      final analyzer = LeafAnalyzer(
        _FakeClassifier(cls('Roya_del_Maíz', 0.91)),
      );
      final low = await analyzer.analyze(leafJpg(0.04));
      final high = await analyzer.analyze(leafJpg(0.40));
      expect(low.severity, Severity.leve);
      expect(high.severity, Severity.severa);
      expect(high.affectedPercent! > low.affectedPercent!, isTrue);
    });
  });
}
