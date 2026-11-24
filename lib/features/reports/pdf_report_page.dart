import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:watch_it/watch_it.dart';

import '../analysis/recommendations/recommendations_data.dart';
import 'analysis_pdf.dart';
import 'analysis_report.dart';

/// Abre la vista previa del PDF con los análisis indicados.
/// La usan el Historial y la pantalla de Recomendaciones (mismo diseño).
Future<void> openAnalysisPdf(
  BuildContext context, {
  required List<AnalysisReportItem> items,
  required String title,
  required String fileKind,
  String? filterText,
}) {
  Future<Uint8List> build() async {
    RecommendationsData? recs;
    try {
      recs = await di<RecommendationsRepository>().load();
    } catch (_) {
      recs = null; // el PDF sale igual, sin recomendaciones
    }
    return buildAnalysisPdf(
      items: items,
      title: title,
      recommendations: recs,
      filterText: filterText,
    );
  }

  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfReportPage(
        title: title,
        fileName: pdfFileName(fileKind),
        build: build,
      ),
    ),
  );
}

/// Vista previa del PDF con botones grandes para guardar/compartir e imprimir.
/// "Guardar o compartir" abre el menú del teléfono (Android e iOS): ahí se
/// puede guardar en Archivos/Drive o enviar por WhatsApp o correo.
class PdfReportPage extends StatefulWidget {
  final String title;
  final String fileName;
  final Future<Uint8List> Function() build;

  const PdfReportPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.build,
  });

  @override
  State<PdfReportPage> createState() => _PdfReportPageState();
}

class _PdfReportPageState extends State<PdfReportPage> {
  late final Future<Uint8List> _pdf = widget.build();

  Future<void> _share() async {
    final bytes = await _pdf;
    await Printing.sharePdf(bytes: bytes, filename: widget.fileName);
  }

  Future<void> _print() async {
    final bytes = await _pdf;
    await Printing.layoutPdf(onLayout: (_) => bytes, name: widget.fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo crear el PDF: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Preparando el PDF…'),
                ],
              ),
            );
          }
          final bytes = snap.data!;
          return PdfPreview(
            build: (_) => bytes,
            pdfFileName: widget.fileName,
            useActions: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            scrollViewDecoration: const BoxDecoration(color: Color(0xFFE9EEE6)),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: _share,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Guardar o compartir'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _print,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Imprimir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
