import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mi_app/_shared/theme/app_theme.dart';
import 'package:mi_app/features/analysis/config/recommendations.dart';
import 'package:mi_app/features/analysis/model/leaf_diagnosis.dart';
import 'package:mi_app/features/analysis/pages/analysis_result_page.dart';

final _photo = Uint8List.fromList(
  img.encodePng(img.Image(width: 4, height: 4)),
);

Future<void> _pump(WidgetTester tester, ResultView view) async {
  tester.view.physicalSize = const Size(480, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AnalysisResultPage(result: view),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('enfermedad: nombre, %, severidad, confianza y botón', (
    tester,
  ) async {
    await _pump(
      tester,
      ResultView(
        status: DiagnosisStatus.disease,
        label: 'Roya_del_Maíz',
        confidence: 0.934,
        affectedPercent: 18.4,
        severity: Severity.moderada,
        photo: _photo,
        plantName: 'Lote 1',
      ),
    );
    expect(find.text('Roya del maíz'), findsOneWidget);
    expect(find.text('Puccinia sorghi'), findsOneWidget);
    expect(find.text('18.4%'), findsOneWidget);
    expect(find.text('Severidad: Moderada'), findsOneWidget);
    expect(find.text('Confianza del modelo: 93.4%'), findsOneWidget);
    expect(find.text('Foto analizada'), findsOneWidget);
    expect(find.byType(AffectionGauge), findsOneWidget);

    await tester.tap(find.text('Recomendaciones'));
    await tester.pumpAndSettle();
    // Moderada → control químico recomendado + advertencias siempre.
    expect(find.text('Control químico recomendado'), findsOneWidget);
    for (final w in Recommendations.warnings.take(2)) {
      expect(find.text(w, skipOffstage: false), findsOneWidget);
    }
  });

  testWidgets('leve: énfasis en monitoreo y prevención', (tester) async {
    await _pump(
      tester,
      ResultView(
        status: DiagnosisStatus.disease,
        label: 'Mancha_de_Asfalto',
        confidence: 0.81,
        affectedPercent: 4.2,
        severity: Severity.leve,
        plantName: 'Lote 2',
      ),
    );
    await tester.tap(find.text('Recomendaciones'));
    await tester.pumpAndSettle();
    expect(
      find.text('Control químico (solo si la enfermedad avanza)'),
      findsOneWidget,
    );
    expect(
      find.text(Recommendations.emphasisFor(Severity.leve)),
      findsOneWidget,
    );
  });

  testWidgets('hoja sana: sin porcentaje, severidad ni recomendaciones', (
    tester,
  ) async {
    await _pump(
      tester,
      ResultView(
        status: DiagnosisStatus.healthy,
        label: 'Hoja_sana',
        confidence: 0.97,
        photo: _photo,
        plantName: 'Lote 1',
      ),
    );
    expect(find.text('Hoja sana'), findsOneWidget);
    expect(find.byType(AffectionGauge), findsNothing);
    expect(find.byType(SeverityBadge), findsNothing);
    expect(find.text('Recomendaciones'), findsNothing);
    expect(find.textContaining('%'), findsOneWidget); // solo la confianza
  });

  testWidgets('no reconocido: mensaje y sin enfermedad', (tester) async {
    await _pump(
      tester,
      ResultView(
        status: DiagnosisStatus.notRecognized,
        label: 'Roya_del_Maíz',
        confidence: 0.55,
        photo: _photo,
        plantName: 'Lote 1',
      ),
    );
    expect(
      find.text(
        'No reconocido, intenta con otra foto (hoja bien iluminada y '
        'enfocada).',
      ),
      findsOneWidget,
    );
    expect(find.text('Roya del maíz'), findsNothing);
    expect(find.byType(AffectionGauge), findsNothing);
  });
}
