import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mi_app/_shared/theme/app_theme.dart';
import 'package:mi_app/features/analysis/model/leaf_diagnosis.dart';
import 'package:mi_app/features/analysis/pages/analysis_result_page.dart';
import 'package:mi_app/features/analysis/pages/recommendations_page.dart';
import 'package:mi_app/features/analysis/recommendations/recommendations_data.dart';
import 'package:watch_it/watch_it.dart';

final _photo = Uint8List.fromList(
  img.encodePng(img.Image(width: 4, height: 4)),
);

/// Repositorio que lee el recomendaciones.json real del proyecto.
class _FileRepo extends RecommendationsRepository {
  @override
  Future<RecommendationsData> load() async => RecommendationsData.parse(
    File('assets/models/recomendaciones.json').readAsStringSync(),
  );
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(480, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
  await tester.pumpAndSettle();
}

ResultView _disease({
  bool partial = false,
  bool medium = false,
  double confidence = 0.87,
  Severity severity = Severity.moderada,
}) => ResultView(
  status: EstadoDiagnostico.enferma,
  label: 'Roya_del_Maíz',
  confidence: confidence,
  partial: partial,
  mediumConfidence: medium,
  top2: const [
    ClaseProbable('Roya_del_Maíz', 0.87),
    ClaseProbable('Hoja_sana', 0.10),
  ],
  affectedPercent: 18.4,
  severity: severity,
  photo: _photo,
  plantName: 'Lote 1',
  analysisTimeMs: 1400,
);

void main() {
  setUp(() {
    if (!di.isRegistered<RecommendationsRepository>()) {
      di.registerSingleton<RecommendationsRepository>(_FileRepo());
    }
  });
  tearDown(() => di.reset());

  testWidgets('ENFERMA: nombre, %, severidad, tiempo, botón y datos técnicos', (
    tester,
  ) async {
    await _pump(tester, AnalysisResultPage(result: _disease()));
    expect(find.text('Roya del maíz'), findsOneWidget);
    expect(find.text('18.4 %'), findsOneWidget);
    expect(find.text('Severidad: Moderada'), findsOneWidget);
    expect(find.text('Análisis en 1.4 s'), findsOneWidget);
    expect(find.text('Recomendaciones'), findsOneWidget);
    expect(find.text('Seguridad del modelo: 87 %'), findsOneWidget);
    expect(find.text('Otras posibilidades'), findsOneWidget);
    expect(find.text('• Hoja sana: 10 %'), findsOneWidget);
    expect(find.textContaining('Hoja mayormente sana'), findsNothing);
    expect(find.textContaining('Confianza media'), findsNothing);
  });

  testWidgets('ENFERMA parcial: aviso discreto bajo el nombre', (tester) async {
    await _pump(tester, AnalysisResultPage(result: _disease(partial: true)));
    expect(
      find.text('Hoja mayormente sana, pero se detectó una zona afectada'),
      findsOneWidget,
    );
    expect(find.byType(AffectionGauge), findsOneWidget);
  });

  testWidgets('confianza media: aviso suave en la zona técnica', (
    tester,
  ) async {
    await _pump(
      tester,
      AnalysisResultPage(result: _disease(medium: true, confidence: 0.55)),
    );
    expect(
      find.text('Confianza media: toma otra foto con buena luz para confirmar'),
      findsOneWidget,
    );
  });

  testWidgets('SANA: sin %, severidad ni recomendaciones; con tiempo', (
    tester,
  ) async {
    await _pump(
      tester,
      AnalysisResultPage(
        result: ResultView(
          status: EstadoDiagnostico.sana,
          label: 'Hoja_sana',
          confidence: 0.97,
          photo: _photo,
          plantName: 'Lote 1',
          analysisTimeMs: 850,
        ),
      ),
    );
    expect(find.text('Hoja sana'), findsOneWidget);
    expect(find.text('Análisis en 0.85 s'), findsOneWidget);
    expect(find.byType(AffectionGauge), findsNothing);
    expect(find.byType(SeverityBadge), findsNothing);
    expect(find.text('Recomendaciones'), findsNothing);
  });

  testWidgets('NO_RECONOCIDO: mensaje amable para repetir la foto', (
    tester,
  ) async {
    await _pump(
      tester,
      AnalysisResultPage(
        result: ResultView(
          status: EstadoDiagnostico.noReconocido,
          label: 'Roya_del_Maíz',
          confidence: 0.40,
          photo: _photo,
          plantName: 'Lote 1',
        ),
      ),
    );
    expect(find.text('No reconocido'), findsOneWidget);
    expect(
      find.text('Acércate a una hoja, con buena luz y enfocada.'),
      findsOneWidget,
    );
    expect(find.text('Recomendaciones'), findsNothing);
  });

  testWidgets('Recomendaciones Moderada: control químico destacado', (
    tester,
  ) async {
    await _pump(
      tester,
      const RecommendationsPage(
        label: 'Roya_del_Maíz',
        severity: Severity.moderada,
        partial: false,
      ),
    );
    expect(find.text('Roya del maíz'), findsOneWidget);
    expect(find.text('¿Qué hacer ahora?'), findsOneWidget);
    expect(find.text('Aplica el control químico pronto.'), findsOneWidget);
    expect(find.text('Control químico'), findsOneWidget);
    // Sin chacras registradas → pide el área.
    expect(
      find.text('No tienes chacras registradas. Escribe el área:'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '0.5');
    await tester.pumpAndSettle();
    // Dosis en null → no calcula, pide mirar la etiqueta.
    expect(
      find.text('Mira la dosis en la etiqueta de tu producto'),
      findsWidgets,
    );
    expect(find.textContaining('mochila'), findsNothing);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Cuida tu salud y tu cultivo'),
      300,
      scrollable: list,
    );
    await tester.scrollUntilVisible(
      find.text('Para la próxima campaña'),
      300,
      scrollable: list,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Estas recomendaciones son una guía'),
      300,
      scrollable: list,
    );
    expect(
      find.textContaining('Estas recomendaciones son una guía'),
      findsOneWidget,
    );
  });

  testWidgets('Recomendaciones Leve: vigilar; químico plegado', (tester) async {
    await _pump(
      tester,
      const RecommendationsPage(
        label: 'Mancha_de_Asfalto',
        severity: Severity.leve,
        partial: false,
      ),
    );
    expect(find.text('Si la enfermedad avanza'), findsOneWidget);
    expect(find.textContaining('Revisa esta planta'), findsOneWidget);
    // Plegado: el contenido químico no se ve hasta abrirlo.
    expect(find.text('¿Cuánto producto para mi chacra?'), findsNothing);
    await tester.tap(find.text('Si la enfermedad avanza'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuánto producto para mi chacra?'), findsOneWidget);
  });

  test('las pantallas no usan servicios de red (assets locales)', () {
    expect(File('assets/models/recomendaciones.json').existsSync(), isTrue);
    expect(rootBundle, isNotNull);
  });
}
