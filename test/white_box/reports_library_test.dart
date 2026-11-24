import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mi_app/features/analysis/model/analysis_dto.dart';
import 'package:mi_app/features/analysis/model/leaf_diagnosis.dart';
import 'package:mi_app/features/analysis/recommendations/recommendations_data.dart';
import 'package:mi_app/features/diseases/model/library_entry.dart';
import 'package:mi_app/features/plants/model/plant_status.dart';
import 'package:mi_app/features/reports/analysis_pdf.dart';
import 'package:mi_app/features/reports/analysis_report.dart';

Uint8List _jpeg() {
  final im = img.Image(width: 64, height: 64);
  img.fill(im, color: img.ColorRgb8(40, 140, 50));
  return Uint8List.fromList(img.encodeJpg(im));
}

AnalysisDto _dto({
  String label = 'Roya_del_Maíz',
  String plantId = 'p1',
  String plant = 'Lote Norte',
  DateTime? date,
  Severity? severity = Severity.moderada,
  double? percent = 14.2,
}) => AnalysisDto(
  plantId: plantId,
  plantName: plant,
  type: AnalysisType.hoja,
  label: label,
  confidence: 0.87,
  affectionPercent: percent,
  severity: severity,
  date: date ?? DateTime(2026, 11, 20, 9, 30),
  photo: _jpeg(),
);

void main() {
  late RecommendationsData recs;

  setUpAll(() {
    recs = RecommendationsData.parse(
      File('assets/models/recomendaciones.json').readAsStringSync(),
    );
  });

  group('PDF de análisis', () {
    test('un análisis: genera un PDF válido con foto', () async {
      final bytes = await buildAnalysisPdf(
        items: [
          AnalysisReportItem.fromDto(_dto(), status: PlantStatus.enfermo),
        ],
        title: 'Reporte de análisis',
        recommendations: recs,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(3000));
    });

    test('varios análisis (historial) con sana y sin recomendaciones', () async {
      final items = [
        AnalysisReportItem.fromDto(_dto()),
        AnalysisReportItem.fromDto(
          _dto(label: 'Hoja_sana', severity: null, percent: 0.3),
        ),
        AnalysisReportItem.fromDto(
          _dto(label: 'Mancha_de_Asfalto', severity: Severity.severa),
        ),
      ];
      final withRecs = await buildAnalysisPdf(
        items: items,
        title: 'Historial completo',
        recommendations: recs,
        filterText: 'del 01/11/2026 al 23/11/2026',
      );
      final withoutRecs = await buildAnalysisPdf(
        items: items,
        title: 'Historial completo',
      );
      expect(String.fromCharCodes(withRecs.take(5)), '%PDF-');
      expect(String.fromCharCodes(withoutRecs.take(5)), '%PDF-');
    });

    test('limpia caracteres que la fuente del PDF no puede dibujar', () {
      // "í" escrita como i + tilde separada (como viene en etiquetas.txt).
      expect(pdfSafe('Ma${'i'}́z'), 'Maíz');
      expect(pdfSafe('Hola 🌽 ≥ 5'), 'Hola  >= 5');
      expect(pdfSafe('Cuídate • año…'), 'Cuídate - año...');
    });

    test('nombre del archivo con la fecha', () {
      expect(
        pdfFileName('historial', DateTime(2026, 11, 3)),
        'agrocare_historial_2026-11-03.pdf',
      );
    });
  });

  group('Filtros del historial', () {
    final a = _dto(date: DateTime(2026, 11, 5, 18));
    final b = _dto(
      label: 'Hoja_sana',
      plantId: 'p2',
      date: DateTime(2026, 11, 20),
    );

    test('por fecha (incluye el día final completo)', () {
      final f = HistoryFilters(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 5),
      );
      expect(f.matches(a), isTrue);
      expect(f.matches(b), isFalse);
    });

    test('por enfermedad y por planta', () {
      expect(const HistoryFilters(label: 'Hoja_sana').matches(b), isTrue);
      expect(const HistoryFilters(label: 'Hoja_sana').matches(a), isFalse);
      expect(const HistoryFilters(plantId: 'p2').matches(b), isTrue);
      expect(const HistoryFilters(plantId: 'p2').matches(a), isFalse);
      expect(HistoryFilters.none.isActive, isFalse);
    });
  });

  group('Biblioteca', () {
    late LibraryData data;

    setUpAll(() {
      data = LibraryData.parse(
        File(libraryAsset).readAsStringSync(),
      );
    });

    test('tiene muchas entradas completas', () {
      expect(data.entries.length, greaterThanOrEqualTo(15));
      final ids = <String>{};
      for (final e in data.entries) {
        expect(ids.add(e.id), isTrue, reason: 'id repetido: ${e.id}');
        expect(e.summary, isNotEmpty, reason: e.id);
        expect(e.symptoms, isNotEmpty, reason: e.id);
        expect(e.causes, isNotEmpty, reason: e.id);
        expect(e.management, isNotEmpty, reason: e.id);
        expect(e.prevention, isNotEmpty, reason: e.id);
      }
    });

    test('incluye todas las clases que detecta el modelo', () {
      final labels = File('assets/models/etiquetas.txt')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .map(normalizeForTest);
      final inLibrary = {
        for (final e in data.entries)
          if (e.modelLabel != null) normalizeForTest(e.modelLabel!),
      };
      for (final l in labels) {
        expect(inLibrary, contains(l), reason: 'falta $l');
      }
    });

    test('no escribe dosis en la biblioteca', () {
      final raw = File(libraryAsset).readAsStringSync().toLowerCase();
      expect(RegExp(r'\d+\s*(ml|l|kg|g|cc)\s*/\s*ha').hasMatch(raw), isFalse);
    });

    test('búsqueda sin tildes ni mayúsculas', () {
      final r = filterLibrary(data.entries, query: 'ROYA');
      expect(r.map((e) => e.id), containsAll(['roya_comun', 'roya_sur']));
      expect(filterLibrary(data.entries, query: 'fosforo'), isNotEmpty);
      expect(filterLibrary(data.entries, query: 'zzzz'), isEmpty);
    });

    test('filtros por tipo y "lo detecta la app"', () {
      final pests = filterLibrary(data.entries, type: LibraryType.plaga);
      expect(pests, isNotEmpty);
      expect(pests.every((e) => e.type == LibraryType.plaga), isTrue);
      final detected = filterLibrary(data.entries, onlyDetected: true);
      expect(detected.length, 4);
    });
  });
}

/// Compara etiquetas sin importar cómo se escribió la tilde.
String normalizeForTest(String s) => foldText(s);
