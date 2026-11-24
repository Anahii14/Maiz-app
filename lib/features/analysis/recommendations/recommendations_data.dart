import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../config/analysis_config.dart';

/// Dosis por hectárea (de la etiqueta del producto). Puede venir en null.
class DoseInfo {
  final double? value;
  final String? unit;

  const DoseInfo({this.value, this.unit});

  bool get isComplete => value != null && unit != null && unit!.isNotEmpty;
}

class ChemicalControl {
  final List<String> activeIngredients;
  final String type;
  final DoseInfo dosePerHa;
  final double? sprayVolumeLPerHa;
  final int? intervalDays;
  final int? maxApplications;
  final int? preHarvestDays;
  final String source;

  const ChemicalControl({
    required this.activeIngredients,
    required this.type,
    required this.dosePerHa,
    this.sprayVolumeLPerHa,
    this.intervalDays,
    this.maxApplications,
    this.preHarvestDays,
    this.source = '',
  });
}

class DiseaseRecommendation {
  final String label;
  final String name;
  final String scientificName;
  final String summary;
  final List<String> actionsMild;
  final List<String> actionsModerateSevere;
  final List<String> prevention;
  final ChemicalControl chemical;

  const DiseaseRecommendation({
    required this.label,
    required this.name,
    required this.scientificName,
    required this.summary,
    required this.actionsMild,
    required this.actionsModerateSevere,
    required this.prevention,
    required this.chemical,
  });
}

class GeneralTexts {
  final String healthTitle;
  final List<String> health;
  final String alternateActives;
  final String noDose;
  final String noSchedule;
  final String finalNotice;

  const GeneralTexts({
    required this.healthTitle,
    required this.health,
    required this.alternateActives,
    required this.noDose,
    required this.noSchedule,
    required this.finalNotice,
  });
}

/// Contenido de assets/models/recomendaciones.json (funciona sin internet).
class RecommendationsData {
  final GeneralTexts general;
  final Map<String, DiseaseRecommendation> byLabel;

  const RecommendationsData({required this.general, required this.byLabel});

  DiseaseRecommendation? of(String label) => byLabel[label];

  static RecommendationsData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final g = j['general'] as Map<String, dynamic>;
    List<String> strings(dynamic v) =>
        (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    double? num_(dynamic v) => (v as num?)?.toDouble();
    int? int_(dynamic v) => (v as num?)?.toInt();

    final diseases = <String, DiseaseRecommendation>{};
    (j['enfermedades'] as Map<String, dynamic>).forEach((label, value) {
      final d = value as Map<String, dynamic>;
      final c = d['control_quimico'] as Map<String, dynamic>? ?? const {};
      final dose = c['dosis_por_ha'] as Map<String, dynamic>? ?? const {};
      diseases[label] = DiseaseRecommendation(
        label: label,
        name: (d['nombre'] ?? label) as String,
        scientificName: (d['nombre_cientifico'] ?? '') as String,
        summary: (d['resumen_simple'] ?? '') as String,
        actionsMild: strings(d['acciones_leve']),
        actionsModerateSevere: strings(d['acciones_moderada_severa']),
        prevention: strings(d['prevencion']),
        chemical: ChemicalControl(
          activeIngredients: strings(c['ingredientes_activos']),
          type: (c['tipo'] ?? '') as String,
          dosePerHa: DoseInfo(
            value: num_(dose['valor']),
            unit: dose['unidad'] as String?,
          ),
          sprayVolumeLPerHa: num_(c['volumen_caldo_l_ha']),
          intervalDays: int_(c['intervalo_dias']),
          maxApplications: int_(c['max_aplicaciones']),
          preHarvestDays: int_(c['periodo_carencia_dias']),
          source: (c['fuente'] ?? '') as String,
        ),
      );
    });

    return RecommendationsData(
      general: GeneralTexts(
        healthTitle:
            (g['titulo_salud'] ?? 'Cuida tu salud y tu cultivo') as String,
        health: strings(g['salud']),
        alternateActives: (g['alternar_ingredientes'] ?? '') as String,
        noDose:
            (g['sin_dosis'] ?? 'Mira la dosis en la etiqueta de tu producto')
                as String,
        noSchedule:
            (g['sin_frecuencia'] ??
                    'Mira en la etiqueta cada cuántos días repetir.')
                as String,
        finalNotice: (g['aviso_final'] ?? '') as String,
      ),
      byLabel: diseases,
    );
  }
}

/// Carga recomendaciones.json una sola vez y lo guarda en memoria.
class RecommendationsRepository {
  RecommendationsData? _data;
  Future<RecommendationsData>? _loading;

  /// Datos ya cargados (o null si todavía no se cargaron).
  RecommendationsData? get cached => _data;

  Future<RecommendationsData> load() => _loading ??= () async {
    final raw = await rootBundle.loadString(
      AnalysisConfig.recommendationsAsset,
    );
    return _data = RecommendationsData.parse(raw);
  }();
}
