import 'plant_dto.dart';

// ============================================================================
//  RIEGO Y ETAPAS DEL MAÍZ
//  Cálculos sencillos que se muestran en "Mis plantas" y en el Resumen.
//  No se guarda nada nuevo en Firestore: todo sale de las fechas de riego y
//  de la fecha de siembra que ya existen.
// ============================================================================

class WateringConfig {
  WateringConfig._();

  /// Días entre riegos cuando todavía no hay suficientes riegos para
  /// calcular el promedio de la planta.
  static const defaultIntervalDays = 3;

  /// Límites del intervalo calculado (para evitar valores raros).
  static const minIntervalDays = 1;
  static const maxIntervalDays = 14;

  /// Cuántos riegos recientes se usan para calcular el promedio.
  static const recentWaterings = 5;
}

/// Etapas simples del maíz según los días desde la siembra.
enum CornStage {
  emergencia('Brotando', 0),
  crecimiento('Creciendo', 11),
  floracion('Floración', 46),
  llenado('Formando mazorca', 66),
  madurez('Lista para cosechar', 111);

  final String label;

  /// Día desde la siembra en que empieza la etapa.
  final int fromDay;

  const CornStage(this.label, this.fromDay);

  static CornStage fromDays(int days) {
    var stage = CornStage.emergencia;
    for (final s in CornStage.values) {
      if (days >= s.fromDay) stage = s;
    }
    return stage;
  }
}

/// Quita la hora: deja solo el día.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Días calendario entre dos fechas (sin importar la hora).
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inHours ~/ 24;

extension PlantWatering on PlantDto {
  /// Días promedio entre los últimos riegos de esta planta.
  int get wateringIntervalDays {
    // Solo riegos reales: al crear la planta, "último riego" es la fecha de
    // siembra, que no cuenta como riego.
    final days = {for (final d in wateringHistory) dateOnly(d)}.toList()
      ..sort((a, b) => b.compareTo(a));
    final recent = days.take(WateringConfig.recentWaterings + 1).toList();
    if (recent.length < 2) return WateringConfig.defaultIntervalDays;
    var total = 0;
    for (var i = 0; i < recent.length - 1; i++) {
      total += daysBetween(recent[i + 1], recent[i]);
    }
    final avg = (total / (recent.length - 1)).round();
    return avg.clamp(
      WateringConfig.minIntervalDays,
      WateringConfig.maxIntervalDays,
    );
  }

  DateTime get nextWateringDate =>
      dateOnly(lastWateringDate).add(Duration(days: wateringIntervalDays));

  /// Negativo = el riego está atrasado. 0 = toca hoy.
  int daysUntilWatering([DateTime? now]) =>
      daysBetween(now ?? DateTime.now(), nextWateringDate);

  int daysSinceWatering([DateTime? now]) =>
      daysBetween(lastWateringDate, now ?? DateTime.now());

  /// Agua que "le queda" a la planta: 1 = recién regada, 0 = toca regar.
  double waterLevel([DateTime? now]) {
    final left = 1 - daysSinceWatering(now) / wateringIntervalDays;
    return left.clamp(0.0, 1.0);
  }

  bool wateredOn(DateTime day) {
    final d = dateOnly(day);
    return wateringHistory.any((w) => dateOnly(w) == d);
  }

  int daysSincePlanting([DateTime? now]) {
    final days = daysBetween(plantedDate, now ?? DateTime.now());
    return days < 0 ? 0 : days;
  }

  CornStage stage([DateTime? now]) =>
      CornStage.fromDays(daysSincePlanting(now));

  /// Crecimiento de 0 a 1 para dibujar la planta (1 = madura).
  double growth([DateTime? now]) =>
      (daysSincePlanting(now) / CornStage.madurez.fromDay).clamp(0.08, 1.0);
}

/// Texto simple para el próximo riego: "Hoy", "Mañana", "En 3 días",
/// "Atrasado 2 días".
String nextWateringText(int daysUntil) {
  if (daysUntil < 0) {
    final late = -daysUntil;
    return late == 1 ? 'Atrasado 1 día' : 'Atrasado $late días';
  }
  if (daysUntil == 0) return 'Hoy';
  if (daysUntil == 1) return 'Mañana';
  return 'En $daysUntil días';
}

/// "Hoy", "Ayer" o "Hace N días".
String daysAgoText(int days) {
  if (days <= 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  return 'Hace $days días';
}
