import 'dart:typed_data';

import '../analysis/config/disease_catalog.dart';
import '../analysis/model/analysis_dto.dart';
import '../analysis/model/leaf_diagnosis.dart';
import '../plants/model/plant_status.dart';

/// Datos de UN análisis para el reporte PDF. Se arma desde el historial
/// (AnalysisDto) o desde la pantalla de resultado, así ambos PDF son iguales.
class AnalysisReportItem {
  final String plantId;
  final String plantName;

  /// Estado actual de la planta (Saludable, Enfermo…), si se conoce.
  final PlantStatus? plantStatus;
  final String label;
  final bool isHealthy;
  final bool partial;
  final double confidence;
  final double? affectedPercent;
  final Severity? severity;
  final DateTime date;
  final Uint8List? photo;

  const AnalysisReportItem({
    required this.plantId,
    required this.plantName,
    required this.label,
    required this.isHealthy,
    required this.confidence,
    required this.date,
    this.plantStatus,
    this.partial = false,
    this.affectedPercent,
    this.severity,
    this.photo,
  });

  factory AnalysisReportItem.fromDto(AnalysisDto dto, {PlantStatus? status}) =>
      AnalysisReportItem(
        plantId: dto.plantId,
        plantName: dto.plantName,
        plantStatus: status,
        label: dto.label,
        isHealthy: dto.isHealthy,
        partial: dto.partial,
        confidence: dto.confidence,
        affectedPercent: dto.affectionPercent,
        severity: dto.severity,
        date: dto.date,
        photo: dto.photo,
      );

  String get diseaseName => DiseaseCatalog.of(label).name;
  String get scientificName => DiseaseCatalog.of(label).scientificName;

  /// Moderada o severa (y no parcial) → acciones de control.
  bool get isUrgent =>
      !partial &&
      (severity == Severity.moderada || severity == Severity.severa);
}

/// Filtros del historial (también se usan para el PDF "filtrado").
class HistoryFilters {
  final DateTime? from;
  final DateTime? to;
  final String? label;
  final String? plantId;

  const HistoryFilters({this.from, this.to, this.label, this.plantId});

  static const none = HistoryFilters();

  bool get isActive =>
      from != null || to != null || label != null || plantId != null;

  HistoryFilters copyWith({
    DateTime? from,
    DateTime? to,
    String? label,
    String? plantId,
    bool clearDates = false,
    bool clearLabel = false,
    bool clearPlant = false,
  }) => HistoryFilters(
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    label: clearLabel ? null : (label ?? this.label),
    plantId: clearPlant ? null : (plantId ?? this.plantId),
  );

  bool matches(AnalysisDto a) {
    if (label != null && a.label != label) return false;
    if (plantId != null && a.plantId != plantId) return false;
    final day = DateTime(a.date.year, a.date.month, a.date.day);
    if (from != null && day.isBefore(from!)) return false;
    if (to != null && day.isAfter(to!)) return false;
    return true;
  }
}
