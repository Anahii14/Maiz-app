import 'package:flutter/material.dart';

import '../../features/plants/model/plant_status.dart';

/// Colores inspirados en el maíz: hojas verdes, granos dorados, tierra y agua.
class CornPalette {
  CornPalette._();

  static const leafDark = Color(0xFF1B5E20);
  static const leaf = Color(0xFF2E7D32);
  static const leafLight = Color(0xFF66BB6A);
  static const husk = Color(0xFFA5C46B);
  static const gold = Color(0xFFF2B705);
  static const goldDark = Color(0xFFD98E04);
  static const goldLight = Color(0xFFFFE08A);
  static const cream = Color(0xFFFFF8E1);
  static const tassel = Color(0xFFC79A3A);
  static const soil = Color(0xFF8D6E63);
  static const water = Color(0xFF29B6F6);
  static const waterDark = Color(0xFF0277BD);
  static const sick = Color(0xFF9C5A2C);
  static const watch = Color(0xFFE8892B);
  static const critical = Color(0xFFC62828);

  /// Color de la hoja según el estado de la planta.
  static Color leafFor(PlantStatus status) {
    switch (status) {
      case PlantStatus.saludable:
        return leaf;
      case PlantStatus.enObservacion:
        return const Color(0xFF8BA63A);
      case PlantStatus.enfermo:
        return const Color(0xFF9E9D24);
      case PlantStatus.critico:
        return const Color(0xFF8D7B3A);
    }
  }

  /// Color del indicador de estado.
  static Color statusColor(PlantStatus status) {
    switch (status) {
      case PlantStatus.saludable:
        return leaf;
      case PlantStatus.enObservacion:
        return goldDark;
      case PlantStatus.enfermo:
        return sick;
      case PlantStatus.critico:
        return critical;
    }
  }

  static IconData statusIcon(PlantStatus status) {
    switch (status) {
      case PlantStatus.saludable:
        return Icons.eco_rounded;
      case PlantStatus.enObservacion:
        return Icons.visibility_rounded;
      case PlantStatus.enfermo:
        return Icons.coronavirus_rounded;
      case PlantStatus.critico:
        return Icons.warning_rounded;
    }
  }
}
