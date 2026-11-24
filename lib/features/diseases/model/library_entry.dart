import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../analysis/services/disease_classifier.dart' show normalizeLabel;

/// Archivo con los datos de la Biblioteca (se edita sin tocar el código).
const libraryAsset = 'assets/data/biblioteca_maiz.json';

/// Tipos de problema, con su nombre, icono y color para los filtros.
enum LibraryType {
  sana('Sana', Icons.eco_rounded, Color(0xFF2E7D32)),
  hongo('Hongos', Icons.coronavirus_rounded, Color(0xFF8D4A2B)),
  bacteria('Bacterias', Icons.biotech_rounded, Color(0xFF6A1B9A)),
  virus('Virus', Icons.bubble_chart_rounded, Color(0xFF00838F)),
  plaga('Plagas', Icons.pest_control_rounded, Color(0xFF5D4037)),
  nutricion('Nutrición', Icons.science_rounded, Color(0xFFF9A825)),
  clima('Agua y clima', Icons.wb_sunny_rounded, Color(0xFF0277BD));

  final String label;
  final IconData icon;
  final Color color;

  const LibraryType(this.label, this.icon, this.color);

  static LibraryType parse(String? v) => LibraryType.values.firstWhere(
    (t) => t.name == v,
    orElse: () => LibraryType.hongo,
  );
}

/// Icono de cada entrada (campo "icono" del JSON).
const _icons = <String, IconData>{
  'hoja': Icons.eco_rounded,
  'roya': Icons.blur_on_rounded,
  'mancha': Icons.grain_rounded,
  'puntos': Icons.scatter_plot_rounded,
  'tizon': Icons.texture_rounded,
  'hongo': Icons.coronavirus_rounded,
  'agalla': Icons.bubble_chart_outlined,
  'moho': Icons.cloud_rounded,
  'bacteria': Icons.biotech_rounded,
  'virus': Icons.bubble_chart_rounded,
  'gusano': Icons.pest_control_rounded,
  'insecto': Icons.bug_report_rounded,
  'pulgon': Icons.bug_report_outlined,
  'nutriente': Icons.science_rounded,
  'agua': Icons.water_drop_rounded,
  'sol': Icons.wb_sunny_rounded,
};

const _parts = <String, String>{
  'hoja': 'Hoja',
  'tallo': 'Tallo',
  'mazorca': 'Mazorca',
  'raiz': 'Raíz',
  'planta': 'Toda la planta',
};

class LibraryEntry {
  final String id;
  final String name;
  final String scientificName;
  final LibraryType type;
  final IconData icon;
  final Color color;
  final List<String> parts;

  /// Etiqueta del modelo (si la app la detecta con una foto).
  final String? modelLabel;
  final String summary;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> management;
  final List<String> prevention;

  const LibraryEntry({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.type,
    required this.icon,
    required this.color,
    required this.parts,
    required this.modelLabel,
    required this.summary,
    required this.symptoms,
    required this.causes,
    required this.management,
    required this.prevention,
  });

  bool get detectedByApp => modelLabel != null;

  List<String> get partNames => [for (final p in parts) _parts[p] ?? p];

  factory LibraryEntry.fromJson(Map<String, dynamic> j) {
    List<String> list(String k) => [
      for (final v in (j[k] as List<dynamic>? ?? const [])) '$v',
    ];
    final hex = (j['color'] as String? ?? '#2E7D32').replaceFirst('#', '');
    final label = j['etiqueta_modelo'] as String?;
    return LibraryEntry(
      id: j['id'] as String,
      name: j['nombre'] as String,
      scientificName: j['nombre_cientifico'] as String? ?? '',
      type: LibraryType.parse(j['tipo'] as String?),
      icon: _icons[j['icono']] ?? Icons.eco_rounded,
      color: Color(int.parse('FF$hex', radix: 16)),
      parts: list('partes'),
      modelLabel: label == null ? null : normalizeLabel(label),
      summary: j['resumen'] as String? ?? '',
      symptoms: list('sintomas'),
      causes: list('causas'),
      management: list('manejo'),
      prevention: list('prevencion'),
    );
  }
}

class LibraryData {
  final String notice;
  final List<LibraryEntry> entries;

  const LibraryData({required this.notice, required this.entries});

  factory LibraryData.parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return LibraryData(
      notice: j['aviso'] as String? ?? '',
      entries: [
        for (final e in j['entradas'] as List<dynamic>)
          LibraryEntry.fromJson(e as Map<String, dynamic>),
      ],
    );
  }
}

/// Carga la Biblioteca una sola vez.
class LibraryRepository {
  static Future<LibraryData>? _cache;

  static Future<LibraryData> load() => _cache ??= rootBundle
      .loadString(libraryAsset)
      .then(LibraryData.parse)
      .catchError((Object e) {
        _cache = null;
        throw e;
      });
}

/// Búsqueda sin importar mayúsculas ni tildes ("roya", "Róya", "ROYA").
String foldText(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  final out = StringBuffer();
  for (final ch in normalizeLabel(s).split('')) {
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString().toLowerCase();
}

/// Filtra por texto (nombre, nombre científico, resumen y síntomas), tipo y
/// "solo lo que detecta la app".
List<LibraryEntry> filterLibrary(
  List<LibraryEntry> entries, {
  String query = '',
  LibraryType? type,
  bool onlyDetected = false,
}) {
  final words = foldText(
    query,
  ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return entries.where((e) {
    if (type != null && e.type != type) return false;
    if (onlyDetected && !e.detectedByApp) return false;
    if (words.isEmpty) return true;
    final haystack = foldText(
      [
        e.name,
        e.scientificName,
        e.summary,
        ...e.symptoms,
        ...e.partNames,
      ].join(' '),
    );
    return words.every(haystack.contains);
  }).toList();
}
