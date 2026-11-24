import 'recommendations_data.dart';

/// Capacidad de la mochila de fumigar (litros).
const double litrosPorMochila = 20;

/// Convierte un área a hectáreas. Devuelve null si la unidad no se conoce
/// (en ese caso la app pide ingresar el área a mano, NO adivina).
///
/// Unidades admitidas: ha / hectárea(s), m2 / m² / metros cuadrados,
/// km2 / km², acre(s).
double? areaToHectares(double value, String unit) {
  final u = unit.trim().toLowerCase().replaceAll('.', '');
  const ha = {'ha', 'hectarea', 'hectárea', 'hectareas', 'hectáreas'};
  const m2 = {'m2', 'm²', 'metros cuadrados', 'metro cuadrado', 'mt2'};
  const km2 = {'km2', 'km²', 'kilometros cuadrados', 'kilómetros cuadrados'};
  const acre = {'acre', 'acres', 'ac'};
  if (ha.contains(u)) return value;
  if (m2.contains(u)) return value / 10000;
  if (km2.contains(u)) return value * 100;
  if (acre.contains(u)) return value * 0.40468564224;
  return null;
}

/// Resultado del cálculo de cantidades. Cada parte es null si falta un dato
/// en recomendaciones.json (la app muestra "mira la etiqueta").
class DoseResult {
  final double areaHa;

  /// Producto total para la chacra, en la unidad de la dosis.
  final double? productTotal;
  final String? productUnit;

  /// Litros de mezcla (caldo) para toda la chacra.
  final double? mixTotalLiters;

  /// Producto por mochila de 20 L (convertido a ml o g si corresponde).
  final double? perBackpack;
  final String? perBackpackUnit;

  const DoseResult({
    required this.areaHa,
    this.productTotal,
    this.productUnit,
    this.mixTotalLiters,
    this.perBackpack,
    this.perBackpackUnit,
  });

  bool get hasProduct => productTotal != null;
  bool get hasMix => mixTotalLiters != null;
  bool get hasBackpack => perBackpack != null;
}

/// producto_total = dosis_por_ha × área_ha
/// mezcla_total   = volumen_caldo_l_ha × área_ha
/// por_mochila    = dosis_por_ha × (20 / volumen_caldo_l_ha)
/// No inventa valores: si falta la dosis o el volumen, esa parte queda null.
DoseResult calculateDose(ChemicalControl c, double areaHa) {
  final dose = c.dosePerHa;
  final volume = c.sprayVolumeLPerHa;
  double? productTotal;
  double? perBackpack;
  String? perBackpackUnit;

  if (dose.isComplete && areaHa > 0) {
    productTotal = dose.value! * areaHa;
    if (volume != null && volume > 0) {
      final raw = dose.value! * (litrosPorMochila / volume);
      (perBackpack, perBackpackUnit) = _toSmallUnit(raw, dose.unit!);
    }
  }
  return DoseResult(
    areaHa: areaHa,
    productTotal: productTotal,
    productUnit: productTotal == null ? null : dose.unit,
    mixTotalLiters: (volume != null && volume > 0 && areaHa > 0)
        ? volume * areaHa
        : null,
    perBackpack: perBackpack,
    perBackpackUnit: perBackpackUnit,
  );
}

/// Para la mochila conviene ml o g: L → ml, kg → g. Otras unidades, igual.
(double, String) _toSmallUnit(double value, String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'l':
    case 'litro':
    case 'litros':
      return (value * 1000, 'ml');
    case 'kg':
    case 'kilo':
    case 'kilos':
    case 'kilogramo':
    case 'kilogramos':
      return (value * 1000, 'g');
    default:
      return (value, unit);
  }
}

/// Número legible: hasta 2 decimales, sin ceros sobrantes (0.2, 100, 1.25).
String formatAmount(double v) {
  final rounded = (v * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "0.2 L", "40 ml", "100 L".
String formatQuantity(double value, String unit) =>
    '${formatAmount(value)} $unit';
