import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/features/analysis/model/leaf_diagnosis.dart';
import 'package:mi_app/features/analysis/recommendations/dose_calculator.dart';
import 'package:mi_app/features/analysis/recommendations/recommendations_data.dart';
import 'package:mi_app/features/analysis/services/disease_classifier.dart';

/// Valores de PRUEBA (solo existen en este test, no en la app).
const _controlDePrueba = ChemicalControl(
  activeIngredients: ['Triazol'],
  type: 'Fungicida',
  dosePerHa: DoseInfo(value: 0.4, unit: 'L'),
  sprayVolumeLPerHa: 200,
);

void main() {
  group('Cálculo de cantidades', () {
    test('0.4 L/ha, 200 L/ha, 0.5 ha → 0.2 L, 100 L y 40 ml por mochila', () {
      final r = calculateDose(_controlDePrueba, 0.5);
      expect(formatQuantity(r.productTotal!, r.productUnit!), '0.2 L');
      expect(formatQuantity(r.mixTotalLiters!, 'L'), '100 L');
      expect(formatQuantity(r.perBackpack!, r.perBackpackUnit!), '40 ml');
    });

    test('con valores null NO calcula ni inventa nada', () {
      const sinDatos = ChemicalControl(
        activeIngredients: ['Triazol'],
        type: 'Fungicida',
        dosePerHa: DoseInfo(),
      );
      final r = calculateDose(sinDatos, 0.5);
      expect(r.hasProduct, isFalse);
      expect(r.hasMix, isFalse);
      expect(r.hasBackpack, isFalse);
      expect(r.productTotal, isNull);
      expect(r.perBackpack, isNull);
    });

    test('dosis sin volumen de caldo: calcula producto pero no la mochila', () {
      const soloDosis = ChemicalControl(
        activeIngredients: [],
        type: '',
        dosePerHa: DoseInfo(value: 0.4, unit: 'L'),
      );
      final r = calculateDose(soloDosis, 2);
      expect(formatQuantity(r.productTotal!, r.productUnit!), '0.8 L');
      expect(r.hasMix, isFalse);
      expect(r.hasBackpack, isFalse);
    });

    test('dosis en kg → mochila en gramos', () {
      const enKg = ChemicalControl(
        activeIngredients: [],
        type: '',
        dosePerHa: DoseInfo(value: 0.5, unit: 'kg'),
        sprayVolumeLPerHa: 250,
      );
      final r = calculateDose(enKg, 1);
      expect(formatQuantity(r.perBackpack!, r.perBackpackUnit!), '40 g');
    });
  });

  group('Conversión del área de la chacra a hectáreas', () {
    test('ha, m², km² y acres', () {
      expect(areaToHectares(1.5, 'ha'), 1.5);
      expect(areaToHectares(2, 'hectáreas'), 2);
      expect(areaToHectares(5000, 'm2'), 0.5);
      expect(areaToHectares(2500, 'm²'), 0.25);
      expect(areaToHectares(1, 'km2'), 100);
      expect(areaToHectares(1, 'acre'), closeTo(0.4047, 1e-4));
    });

    test('unidad desconocida → null (no se adivina)', () {
      expect(areaToHectares(3, 'yugadas'), isNull);
    });
  });

  group('Formato del tiempo de análisis', () {
    test('1400 ms → "1.4 s"', () => expect(formatAnalysisTime(1400), '1.4 s'));
    test('850 ms → "0.85 s"', () => expect(formatAnalysisTime(850), '0.85 s'));
  });

  group('recomendaciones.json', () {
    final data = RecommendationsData.parse(
      File('assets/models/recomendaciones.json').readAsStringSync(),
    );
    final labels = parseLabels(
      File('assets/models/etiquetas.txt').readAsStringSync(),
    );

    test('tiene cada enfermedad de etiquetas.txt (mismas claves)', () {
      for (final l in labels.where((l) => l != 'Hoja_sana')) {
        expect(data.of(l), isNotNull, reason: l);
        expect(data.of(l)!.actionsMild.length, inInclusiveRange(3, 5));
        expect(
          data.of(l)!.actionsModerateSevere.length,
          inInclusiveRange(3, 5),
        );
      }
    });

    test('las dosis vienen en null (las completa la usuaria)', () {
      for (final r in data.byLabel.values) {
        expect(r.chemical.dosePerHa.isComplete, isFalse, reason: r.label);
        expect(r.chemical.sprayVolumeLPerHa, isNull);
        expect(r.chemical.preHarvestDays, isNull);
      }
    });
  });
}
