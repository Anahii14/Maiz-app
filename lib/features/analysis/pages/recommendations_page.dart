import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_dto.dart';
import '../config/disease_catalog.dart';
import '../model/leaf_diagnosis.dart';
import '../recommendations/dose_calculator.dart';
import '../recommendations/recommendations_data.dart';
import '../../reports/analysis_report.dart';
import '../../reports/pdf_report_page.dart';
import 'analysis_result_page.dart' show SeverityBadge, severityColor;

/// Recomendaciones para el agricultor: letra grande, frases cortas,
/// tarjetas separadas. Todo sale de recomendaciones.json (sin internet).
class RecommendationsPage extends StatelessWidget {
  final String label;
  final Severity? severity;
  final bool partial;
  final String plantId;

  /// Datos del análisis para el PDF. Si es null (por ejemplo, desde la
  /// Biblioteca), no se muestra el botón "Descargar PDF".
  final AnalysisReportItem? report;

  const RecommendationsPage({
    super.key,
    required this.label,
    required this.severity,
    required this.partial,
    this.plantId = '',
    this.report,
  });

  /// Leve, parcial o sin medir → acciones de vigilancia; si no, control.
  bool get isUrgent =>
      !partial &&
      (severity == Severity.moderada || severity == Severity.severa);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recomendaciones')),
      body: FutureBuilder<RecommendationsData>(
        future: di<RecommendationsRepository>().load(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const _Message(
              'No se pudieron leer las recomendaciones (recomendaciones.json).',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final rec = data.of(label);
          if (rec == null) {
            return const _Message(
              'Todavía no hay recomendaciones para esta enfermedad.',
            );
          }
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _Header(rec: rec, severity: severity, partial: partial),
                    if (report != null) ...[
                      const SizedBox(height: 12),
                      _PdfButton(report: report!),
                    ],
                    const SizedBox(height: 18),
                    _BigCard(
                      icon: Icons.checklist_rounded,
                      color: isUrgent
                          ? severityColor(severity)
                          : const Color(0xFF2E7D32),
                      title: '¿Qué hacer ahora?',
                      child: _NumberedList(
                        isUrgent ? rec.actionsModerateSevere : rec.actionsMild,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ChemicalCard(
                      rec: rec,
                      general: data.general,
                      urgent: isUrgent,
                      severity: severity,
                      plantId: plantId,
                    ),
                    const SizedBox(height: 18),
                    _BigCard(
                      icon: Icons.health_and_safety_outlined,
                      color: const Color(0xFF1565C0),
                      title: data.general.healthTitle,
                      child: _BulletList(data.general.health),
                    ),
                    const SizedBox(height: 18),
                    _BigCard(
                      icon: Icons.event_repeat_rounded,
                      color: const Color(0xFF6D4C41),
                      title: 'Para la próxima campaña',
                      child: _BulletList(rec.prevention),
                    ),
                    const SizedBox(height: 18),
                    _FinalNotice(data.general.finalNotice),
                    if (report != null) ...[
                      const SizedBox(height: 18),
                      _PdfButton(report: report!),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================== Secciones

/// "Descargar PDF": el mismo reporte que el Historial (mismo código).
class _PdfButton extends StatelessWidget {
  final AnalysisReportItem report;

  const _PdfButton({required this.report});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => openAnalysisPdf(
        context,
        items: [report],
        title: 'Reporte de análisis',
        fileKind: 'analisis',
      ),
      icon: const Icon(Icons.picture_as_pdf_rounded, size: 24),
      label: const Text('Descargar PDF'),
    );
  }
}

class _Header extends StatelessWidget {
  final DiseaseRecommendation rec;
  final Severity? severity;
  final bool partial;

  const _Header({
    required this.rec,
    required this.severity,
    required this.partial,
  });

  @override
  Widget build(BuildContext context) {
    final info = DiseaseCatalog.of(rec.label);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: info.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, color: info.color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rec.name,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SeverityBadge(severity: severity),
              if (partial)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: const Text(
                    'Solo una zona de la hoja',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rec.summary,
            style: text.titleMedium?.copyWith(
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChemicalCard extends StatelessWidget {
  final DiseaseRecommendation rec;
  final GeneralTexts general;
  final bool urgent;
  final Severity? severity;
  final String plantId;

  const _ChemicalCard({
    required this.rec,
    required this.general,
    required this.urgent,
    required this.severity,
    required this.plantId,
  });

  @override
  Widget build(BuildContext context) {
    final c = rec.chemical;
    final text = Theme.of(context).textTheme;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubTitle('Ingredientes activos (no marcas)'),
        _BulletList(c.activeIngredients),
        if (c.type.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(c.type, style: _bigBody(context)),
        ],
        const SizedBox(height: 18),
        const _SubTitle('¿Cuánto producto para mi chacra?'),
        _DoseCalculator(chemical: c, general: general, plantId: plantId),
        const SizedBox(height: 18),
        const _SubTitle('¿Cuándo aplicar?'),
        if (c.intervalDays != null)
          _InfoLine(
            Icons.repeat_rounded,
            'Repite cada ${c.intervalDays} días.',
          ),
        if (c.maxApplications != null)
          _InfoLine(
            Icons.filter_9_plus_rounded,
            'Máximo ${c.maxApplications} aplicaciones por campaña.',
          ),
        if (c.preHarvestDays != null)
          _InfoLine(
            Icons.agriculture_rounded,
            'Espera ${c.preHarvestDays} días antes de cosechar '
            '(período de carencia).',
          ),
        if (c.intervalDays == null &&
            c.maxApplications == null &&
            c.preHarvestDays == null)
          _InfoLine(Icons.label_outline_rounded, general.noSchedule),
        const SizedBox(height: 8),
        _InfoLine(Icons.swap_horiz_rounded, general.alternateActives),
        if (c.source.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Fuente: ${c.source}',
            style: text.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ],
    );

    if (urgent) {
      return _BigCard(
        icon: Icons.science_rounded,
        color: severityColor(severity),
        title: 'Control químico',
        highlighted: true,
        child: body,
      );
    }
    // Leve / parcial: plegado, solo si la enfermedad avanza.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: const Icon(
            Icons.science_outlined,
            size: 30,
            color: Color(0xFF616161),
          ),
          title: Text(
            'Si la enfermedad avanza',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Control químico',
            style: text.bodyLarge?.copyWith(color: Colors.black54),
          ),
          children: [body],
        ),
      ),
    );
  }
}

/// Calcula cuánto producto usar según el área de la chacra.
class _DoseCalculator extends StatefulWidget {
  final ChemicalControl chemical;
  final GeneralTexts general;
  final String plantId;

  const _DoseCalculator({
    required this.chemical,
    required this.general,
    required this.plantId,
  });

  @override
  State<_DoseCalculator> createState() => _DoseCalculatorState();
}

class _DoseCalculatorState extends State<_DoseCalculator> {
  static const _manual = '__manual__';

  late final List<PlantEntry> _plants;
  late String _selected;
  final _areaCtrl = TextEditingController();
  String _unit = 'ha';

  @override
  void initState() {
    super.initState();
    // Chacras registradas (área guardada en hectáreas: campo areaHectares).
    _plants = di.isRegistered<PlantsManager>()
        ? di<PlantsManager>().plants.value
              .where((p) => p.dto.areaHectares > 0)
              .toList()
        : const [];
    final associated = _plants.where((p) => p.id == widget.plantId);
    _selected = associated.isNotEmpty
        ? associated.first.id
        : (_plants.length == 1 ? _plants.first.id : _manual);
    if (_plants.length > 1 && associated.isEmpty) {
      _selected = _plants.first.id;
    }
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  /// Área elegida en hectáreas (null si falta o la unidad no se conoce).
  double? get _areaHa {
    if (_selected != _manual) {
      final p = _plants.firstWhere((e) => e.id == _selected);
      return areaToHectares(p.dto.areaHectares, 'ha');
    }
    final v = double.tryParse(_areaCtrl.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return areaToHectares(v, _unit);
  }

  @override
  Widget build(BuildContext context) {
    final area = _areaHa;
    final result = area == null ? null : calculateDose(widget.chemical, area);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_plants.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _selected,
            isExpanded: true,
            style: _bigBody(context),
            decoration: const InputDecoration(labelText: 'Chacra'),
            items: [
              for (final p in _plants)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${p.dto.name} (${formatAmount(p.dto.areaHectares)} ha)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const DropdownMenuItem(
                value: _manual,
                child: Text('Escribir otra área'),
              ),
            ],
            onChanged: (v) => setState(() => _selected = v ?? _manual),
          ),
        if (_selected == _manual) ...[
          if (_plants.isNotEmpty) const SizedBox(height: 12),
          if (_plants.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No tienes chacras registradas. Escribe el área:',
                style: _bigBody(context),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _areaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: _bigBody(context),
                  decoration: const InputDecoration(labelText: 'Área'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ha', label: Text('ha')),
                  ButtonSegment(value: 'm2', label: Text('m²')),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (area == null)
          Text(
            'Elige o escribe el área de tu chacra.',
            style: _bigBody(context),
          )
        else ...[
          if (result!.hasProduct)
            _BigNumber(
              caption: 'Para tu chacra de ${formatAmount(area)} ha:',
              value: formatQuantity(result.productTotal!, result.productUnit!),
              suffix: 'de producto',
            )
          else
            _InfoLine(Icons.label_outline_rounded, widget.general.noDose),
          if (result.hasMix)
            _BigNumber(
              caption: 'Mezcla con agua (caldo) para toda la chacra:',
              value: formatQuantity(result.mixTotalLiters!, 'L'),
            ),
          if (result.hasBackpack)
            _BigNumber(
              caption:
                  'En cada mochila de ${formatAmount(litrosPorMochila)} L:',
              value: formatQuantity(
                result.perBackpack!,
                result.perBackpackUnit!,
              ),
              suffix: 'de producto',
            ),
        ],
      ],
    );
  }
}

// ============================================================ Componentes

TextStyle? _bigBody(BuildContext context) => Theme.of(context)
    .textTheme
    .bodyLarge
    ?.copyWith(fontSize: 18, height: 1.4, color: Colors.black87);

class _BigCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  final bool highlighted;

  const _BigCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.07) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted ? color : Colors.black12,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NumberedList extends StatelessWidget {
  final List<String> items;

  const _NumberedList(this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black87,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(items[i], style: _bigBody(context))),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;

  const _BulletList(this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3, right: 10),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                Expanded(child: Text(item, style: _bigBody(context))),
              ],
            ),
          ),
      ],
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;

  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 19,
        color: Colors.black,
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _bigBody(context))),
      ],
    ),
  );
}

class _BigNumber extends StatelessWidget {
  final String caption;
  final String value;
  final String? suffix;

  const _BigNumber({required this.caption, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: _bigBody(context)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                if (suffix != null)
                  TextSpan(text: '  $suffix', style: _bigBody(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalNotice extends StatelessWidget {
  final String text;

  const _FinalNotice(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEF6C00), width: 1.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFE65100),
          size: 30,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: _bigBody(context)?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center, style: _bigBody(context)),
    ),
  );
}
