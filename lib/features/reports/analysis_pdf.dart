import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../analysis/config/disease_catalog.dart';
import '../analysis/model/leaf_diagnosis.dart';
import '../analysis/recommendations/recommendations_data.dart';
import 'analysis_report.dart';

// ============================================================================
//  REPORTE PDF DE ANÁLISIS (el MISMO para el Historial y para la pantalla
//  de Recomendaciones). Funciona sin internet: no descarga fuentes.
// ============================================================================

const _appName = 'AgroCare';

const _green = PdfColor.fromInt(0xFF1B5E20);
const _greenLight = PdfColor.fromInt(0xFFE8F5E9);
const _gold = PdfColor.fromInt(0xFFF2B705);
const _grey = PdfColor.fromInt(0xFF616161);
const _greyLight = PdfColor.fromInt(0xFFF5F5F5);
const _border = PdfColor.fromInt(0xFFDDDDDD);

/// Verde / amarillo / rojo según la severidad (igual que en la app).
PdfColor severityPdfColor(Severity? s, {bool healthy = false}) {
  if (healthy) return const PdfColor.fromInt(0xFF2E7D32);
  return switch (s) {
    Severity.leve => const PdfColor.fromInt(0xFF2E7D32),
    Severity.moderada => const PdfColor.fromInt(0xFFF9A825),
    Severity.severa => const PdfColor.fromInt(0xFFC62828),
    null => _grey,
  };
}

/// Arma el PDF. [title] va en el encabezado ("Reporte de análisis",
/// "Historial completo"...). [filterText] describe los filtros usados.
Future<Uint8List> buildAnalysisPdf({
  required List<AnalysisReportItem> items,
  required String title,
  RecommendationsData? recommendations,
  String? filterText,
  DateTime? generatedAt,
}) async {
  final now = generatedAt ?? DateTime.now();
  final doc = pw.Document(
    title: pdfSafe('$_appName - $title'),
    author: _appName,
  );
  final single = items.length == 1;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
      header: (ctx) => _header(title, now),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        if (filterText != null && filterText.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              pdfSafe('Filtros: $filterText'),
              style: const pw.TextStyle(fontSize: 10, color: _grey),
            ),
          ),
        if (items.isEmpty)
          pw.Text('No hay análisis para mostrar.')
        else ...[
          if (!single) ...[_summary(items), pw.SizedBox(height: 14)],
          for (var i = 0; i < items.length; i++) ...[
            _analysisCard(
              items[i],
              counter: single ? null : 'Análisis ${i + 1} de ${items.length}',
            ),
            pw.SizedBox(height: 8),
            ..._recommendation(items[i], recommendations, full: single),
            pw.SizedBox(height: 16),
          ],
        ],
        if (recommendations != null) ...[
          _sectionTitle(pdfSafe(recommendations.general.healthTitle)),
          ..._bullets(recommendations.general.health),
          pw.SizedBox(height: 12),
          _notice(recommendations.general.finalNotice),
        ],
      ],
    ),
  );
  return doc.save();
}

// --------------------------------------------------------------- secciones

pw.Widget _header(String title, DateTime now) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 14),
  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: const pw.BoxDecoration(
    color: _green,
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
  ),
  child: pw.Row(
    children: [
      // Grano de maíz como logo.
      pw.Container(
        width: 26,
        height: 26,
        decoration: const pw.BoxDecoration(
          color: _gold,
          shape: pw.BoxShape.circle,
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'A',
          style: pw.TextStyle(
            color: _green,
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _appName,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              pdfSafe(title),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
            ),
          ],
        ),
      ),
      pw.Text(
        'Generado: ${formatPdfDate(now)}',
        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
      ),
    ],
  ),
);

pw.Widget _footer(pw.Context ctx) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 10),
  padding: const pw.EdgeInsets.only(top: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: _border)),
  ),
  child: pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          pdfSafe(
            '$_appName · Diagnóstico con IA. Confirma con un ingeniero agrónomo.',
          ),
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ),
      pw.Text(
        'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: _grey),
      ),
    ],
  ),
);

/// Tabla resumen (solo cuando hay varios análisis).
pw.Widget _summary(List<AnalysisReportItem> items) {
  final sick = items.where((i) => !i.isHealthy).length;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle('Resumen'),
      pw.Text(
        pdfSafe(
          '${items.length} análisis · ${items.length - sick} sanos · $sick con enfermedad',
        ),
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Fecha', 'Planta', 'Resultado', 'Severidad', '% afectado'],
        data: [
          for (final i in items)
            [
              formatPdfDate(i.date),
              pdfSafe(i.plantName),
              pdfSafe(i.diseaseName),
              i.isHealthy ? '-' : (i.severity?.label ?? '-'),
              i.isHealthy || i.affectedPercent == null
                  ? '-'
                  : '${i.affectedPercent!.toStringAsFixed(1)} %',
            ],
        ],
        headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: _green),
        cellStyle: const pw.TextStyle(fontSize: 9),
        oddRowDecoration: const pw.BoxDecoration(color: _greyLight),
        border: pw.TableBorder.all(color: _border, width: 0.5),
        cellAlignment: pw.Alignment.centerLeft,
      ),
    ],
  );
}

/// Tarjeta del análisis: foto + datos.
pw.Widget _analysisCard(AnalysisReportItem item, {String? counter}) {
  final color = severityPdfColor(item.severity, healthy: item.isHealthy);
  final status = item.isHealthy
      ? 'Sana'
      : '${item.severity?.label ?? 'Sin medir'}${item.partial ? ' (zona parcial)' : ''}';
  final photo = item.photo;

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: photo != null
              ? pw.Image(
                  pw.MemoryImage(photo),
                  width: 150,
                  height: 150,
                  fit: pw.BoxFit.cover,
                )
              : pw.Container(
                  width: 150,
                  height: 150,
                  color: _greyLight,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Sin foto',
                    style: const pw.TextStyle(color: _grey),
                  ),
                ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (counter != null)
                pw.Text(
                  counter,
                  style: const pw.TextStyle(fontSize: 9, color: _grey),
                ),
              pw.Text(
                pdfSafe(item.diseaseName),
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF212121),
                ),
              ),
              if (item.scientificName.isNotEmpty)
                pw.Text(
                  pdfSafe(item.scientificName),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: _grey,
                  ),
                ),
              pw.SizedBox(height: 8),
              // Etiqueta de severidad de color.
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10),
                  ),
                ),
                child: pw.Text(
                  pdfSafe(item.isHealthy ? 'Hoja sana' : 'Severidad: $status'),
                  style: pw.TextStyle(
                    // En amarillo se lee mejor el texto oscuro.
                    color: !item.isHealthy && item.severity == Severity.moderada
                        ? PdfColors.black
                        : PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _row('Planta', item.plantName),
              _row('Estado de la planta', item.plantStatus?.label ?? '-'),
              _row(
                'Área afectada',
                item.isHealthy || item.affectedPercent == null
                    ? '-'
                    : '${item.affectedPercent!.toStringAsFixed(1)} %',
              ),
              _row(
                'Seguridad del modelo',
                '${(item.confidence * 100).round()} %',
              ),
              _row('Fecha', formatPdfDate(item.date)),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _row(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 110,
        child: pw.Text(
          pdfSafe(label),
          style: const pw.TextStyle(fontSize: 10, color: _grey),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          pdfSafe(value),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  ),
);

/// Recomendación (los mismos textos de recomendaciones.json que la app).
List<pw.Widget> _recommendation(
  AnalysisReportItem item,
  RecommendationsData? data, {
  required bool full,
}) {
  if (item.isHealthy) {
    return [
      _sectionTitle('Recomendación'),
      _para(
        'La hoja está sana. Sigue revisando tu chacra una vez por semana y '
        'vuelve a analizar si aparecen manchas.',
      ),
    ];
  }
  final rec = data?.of(item.label);
  if (rec == null) {
    return [
      _sectionTitle('Recomendación'),
      _para(
        'Consulta a un ingeniero agrónomo para el manejo de esta enfermedad.',
      ),
    ];
  }
  final chem = rec.chemical;
  final dose = chem.dosePerHa;
  return [
    _sectionTitle('¿Qué hacer ahora?'),
    ..._numbered(item.isUrgent ? rec.actionsModerateSevere : rec.actionsMild),
    pw.SizedBox(height: 6),
    _sectionTitle(
      item.isUrgent
          ? 'Control químico'
          : 'Control químico (si la enfermedad avanza)',
    ),
    _para('Ingredientes activos: ${chem.activeIngredients.join(', ')}.'),
    if (chem.type.isNotEmpty) _para(chem.type),
    _para(
      dose.value == null
          ? data!.general.noDose
          : 'Dosis: ${dose.value} ${dose.unit ?? ''} por hectárea.',
      bold: true,
    ),
    _para(data!.general.alternateActives),
    if (full) ...[
      pw.SizedBox(height: 6),
      _sectionTitle('Para la próxima campaña'),
      ..._bullets(rec.prevention),
    ],
  ];
}

pw.Widget _sectionTitle(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: const pw.BoxDecoration(
    color: _greenLight,
    border: pw.Border(left: pw.BorderSide(color: _green, width: 3)),
  ),
  child: pw.Text(
    pdfSafe(text),
    style: pw.TextStyle(
      fontSize: 11.5,
      fontWeight: pw.FontWeight.bold,
      color: _green,
    ),
  ),
);

pw.Widget _para(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.Text(
    pdfSafe(text),
    style: pw.TextStyle(
      fontSize: 10.5,
      lineSpacing: 1.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

List<pw.Widget> _numbered(List<String> items) => [
  for (var i = 0; i < items.length; i++)
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3, left: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 16,
            child: pw.Text(
              '${i + 1}.',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              pdfSafe(items[i]),
              style: const pw.TextStyle(fontSize: 10.5),
            ),
          ),
        ],
      ),
    ),
];

List<pw.Widget> _bullets(List<String> items) => [
  for (final t in items)
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3, left: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4,
            height: 4,
            margin: const pw.EdgeInsets.only(top: 5, right: 8),
            decoration: const pw.BoxDecoration(
              color: _green,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              pdfSafe(t),
              style: const pw.TextStyle(fontSize: 10.5),
            ),
          ),
        ],
      ),
    ),
];

pw.Widget _notice(String text) => pw.Container(
  padding: const pw.EdgeInsets.all(10),
  decoration: const pw.BoxDecoration(
    color: PdfColor.fromInt(0xFFFFF8E1),
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
  ),
  child: pw.Text(
    pdfSafe(text),
    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
  ),
);

// ------------------------------------------------------------------ ayudas

/// "23/11/2026 14:05".
String formatPdfDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Nombre del archivo: agrocare_historial_2026-11-23.pdf
String pdfFileName(String kind, [DateTime? now]) {
  final d = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'agrocare_${kind}_${d.year}-${two(d.month)}-${two(d.day)}.pdf';
}

/// Las fuentes del PDF (Helvetica) solo tienen letras latinas: se unen las
/// tildes "separadas" (í escrita como i + ´) y se quitan emojis u otros
/// símbolos que no se pueden dibujar.
String pdfSafe(String text) {
  const acute = 0x301, tilde = 0x303, diaeresis = 0x308;
  const composed = {
    acute: {
      'a': 'á',
      'e': 'é',
      'i': 'í',
      'o': 'ó',
      'u': 'ú',
      'A': 'Á',
      'E': 'É',
      'I': 'Í',
      'O': 'Ó',
      'U': 'Ú',
    },
    tilde: {'n': 'ñ', 'N': 'Ñ'},
    diaeresis: {'u': 'ü', 'U': 'Ü'},
  };
  // Símbolos fuera del alfabeto latino básico → equivalentes simples.
  const replace = {
    '•': '-',
    '–': '-',
    '—': '-',
    '…': '...',
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
    '≥': '>=',
    '≤': '<=',
  };
  final out = StringBuffer();
  final runes = text.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    final next = i + 1 < runes.length ? runes[i + 1] : null;
    final merged = composed[next]?[ch];
    if (merged != null) {
      out.write(merged);
      i++;
      continue;
    }
    final r = runes[i];
    final swap = replace[ch];
    if (swap != null) {
      out.write(swap);
    } else if (r == 9 || r == 10 || (r >= 32 && r <= 0xFF)) {
      out.write(ch);
    }
  }
  return out.toString();
}

/// Etiqueta de la enfermedad para el resumen de filtros.
String diseaseLabelName(String label) => DiseaseCatalog.of(label).name;
