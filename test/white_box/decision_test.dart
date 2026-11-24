import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/features/analysis/logic/decision.dart';

/// Orden de clases de los casos: sana, roya, gris, asfalto.
Map<String, double> p(double sana, double roya, double gris, double asfalto) =>
    {
      'Hoja_sana': sana,
      'Roya_del_Maíz': roya,
      'Mancha_Gris_de_la_Hoja': gris,
      'Mancha_de_Asfalto': asfalto,
    };

const roya = 'Roya_del_Maíz';

void main() {
  group('decidir() – casos pedidos', () {
    test('sana 0.97, resto bajo, área 1 → SANA', () {
      final d = decidir(p(0.97, 0.01, 0.01, 0.01), 1);
      expect(d.estado, EstadoDiagnostico.sana);
      expect(d.enfermedad, isNull);
      expect(d.parcial, isFalse);
    });

    test('sana 0.80, roya 0.20, área 8 → ENFERMA roya, parcial', () {
      final d = decidir(p(0.80, 0.20, 0, 0), 8);
      expect(d.estado, EstadoDiagnostico.enferma);
      expect(d.enfermedad, roya);
      expect(d.parcial, isTrue);
      expect(d.confianza, closeTo(0.20, 1e-9)); // prob. de la clase mostrada
    });

    test('sana 0.88, roya 0.12, área 6 → ENFERMA roya, parcial (por área)', () {
      final d = decidir(p(0.88, 0.12, 0, 0), 6);
      expect(d.estado, EstadoDiagnostico.enferma);
      expect(d.enfermedad, roya);
      expect(d.parcial, isTrue);
      expect(d.regla, contains('área'));
      expect(d.regla, isNot(contains('prob')));
    });

    test('sana 0.88, roya 0.04, área 1 → SANA', () {
      final d = decidir(p(0.88, 0.04, 0.04, 0.04), 1);
      expect(d.estado, EstadoDiagnostico.sana);
    });

    test('roya 0.85, sana 0.10 → ENFERMA roya', () {
      final d = decidir(p(0.10, 0.85, 0.03, 0.02), 3);
      expect(d.estado, EstadoDiagnostico.enferma);
      expect(d.enfermedad, roya);
      expect(d.parcial, isFalse);
      expect(d.confianzaMedia, isFalse);
    });

    test('roya 0.55, gris 0.30, sana 0.10 → ENFERMA roya, confianza media', () {
      final d = decidir(p(0.10, 0.55, 0.30, 0.05), 12);
      expect(d.estado, EstadoDiagnostico.enferma);
      expect(d.enfermedad, roya);
      expect(d.confianzaMedia, isTrue);
      expect(d.parcial, isFalse);
      expect(d.top2.map((c) => c.etiqueta), [roya, 'Mancha_Gris_de_la_Hoja']);
    });

    test('todas por debajo de 0.40 → NO_RECONOCIDO', () {
      final d = decidir(p(0.30, 0.25, 0.25, 0.20), null);
      expect(d.estado, EstadoDiagnostico.noReconocido);
      expect(d.enfermedad, isNull);
    });
  });

  group('decidir() – otras reglas', () {
    test('si existe la clase No_es_hoja y gana → NO_ES_HOJA', () {
      final d = decidir({
        ...p(0.05, 0.05, 0.05, 0.05),
        'No_es_hoja': 0.80,
      }, null);
      expect(d.estado, EstadoDiagnostico.noEsHoja);
    });

    test(
      'en parcial se muestra la enfermedad más probable (nunca la sana)',
      () {
        final d = decidir(p(0.70, 0.05, 0.18, 0.07), 0);
        expect(d.enfermedad, 'Mancha_Gris_de_la_Hoja');
        expect(d.parcial, isTrue);
      },
    );

    test('límites exactos: 0.45 y 5.0 sí cuentan', () {
      expect(
        decidir(p(0.45, 0.30, 0.15, 0.10), 0).estado,
        isNot(EstadoDiagnostico.noReconocido),
      );
      final d = decidir(p(0.90, 0.04, 0.03, 0.03), 5.0);
      expect(d.parcial, isTrue);
    });
  });
}
