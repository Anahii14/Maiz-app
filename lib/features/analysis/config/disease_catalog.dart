import 'package:flutter/material.dart';

/// Cómo se muestra cada clase del modelo (clave = etiqueta de etiquetas.txt).
class DiseaseInfo {
  final String label;
  final String name;
  final String scientificName;
  final Color color;
  final IconData icon;

  const DiseaseInfo({
    required this.label,
    required this.name,
    required this.scientificName,
    required this.color,
    required this.icon,
  });
}

class DiseaseCatalog {
  DiseaseCatalog._();

  static const _items = <String, DiseaseInfo>{
    'Hoja_sana': DiseaseInfo(
      label: 'Hoja_sana',
      name: 'Hoja sana',
      scientificName: '',
      color: Color(0xFF2E7D32),
      icon: Icons.verified_rounded,
    ),
    'Roya_del_Maíz': DiseaseInfo(
      label: 'Roya_del_Maíz',
      name: 'Roya del maíz',
      scientificName: 'Puccinia sorghi',
      color: Color(0xFFD9640B),
      icon: Icons.blur_on_rounded,
    ),
    'Mancha_Gris_de_la_Hoja': DiseaseInfo(
      label: 'Mancha_Gris_de_la_Hoja',
      name: 'Mancha gris de la hoja',
      scientificName: 'Cercospora zeae-maydis',
      color: Color(0xFF607D8B),
      icon: Icons.grain_rounded,
    ),
    'Mancha_de_Asfalto': DiseaseInfo(
      label: 'Mancha_de_Asfalto',
      name: 'Mancha de asfalto',
      scientificName: 'Phyllachora maydis',
      color: Color(0xFF37474F),
      icon: Icons.scatter_plot_rounded,
    ),
  };

  /// Información de la etiqueta; si no existe, se genera desde el texto.
  static DiseaseInfo of(String label) =>
      _items[label] ??
      DiseaseInfo(
        label: label,
        name: label.replaceAll('_', ' '),
        scientificName: '',
        color: const Color(0xFF8D6E63),
        icon: Icons.coronavirus_outlined,
      );
}
