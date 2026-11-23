import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/analysis_config.dart';

/// Resultado de medir la hoja.
class SegmentationResult {
  /// Píxeles que pertenecen a la hoja (sana + manchas).
  final int leafPixels;

  /// Píxeles de la hoja marcados como afectados.
  final int affectedPixels;

  /// Total de píxeles de la imagen analizada.
  final int totalPixels;

  const SegmentationResult({
    required this.leafPixels,
    required this.affectedPixels,
    required this.totalPixels,
  });

  /// % de la imagen que ocupa la hoja.
  double get leafAreaPercent =>
      totalPixels == 0 ? 0 : leafPixels / totalPixels * 100;

  /// true si la hoja se distingue lo suficiente del fondo para medirla.
  bool get leafFound => leafAreaPercent >= AnalysisConfig.minLeafAreaPercent;

  /// % afectado = píxeles afectados / píxeles de hoja × 100, con 1 decimal.
  /// null si no se encontró la hoja.
  double? get affectedPercent {
    if (!leafFound || leafPixels == 0) return null;
    return (affectedPixels / leafPixels * 1000).round() / 10;
  }
}

/// Convierte RGB (0–255) a HSV con la escala de OpenCV:
/// H 0–179, S 0–255, V 0–255.
(int, int, int) rgbToHsv(int r, int g, int b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;
  final v = maxC;
  final s = maxC == 0 ? 0 : (delta * 255 / maxC).round();
  double h;
  if (delta == 0) {
    h = 0;
  } else if (maxC == r) {
    h = 60 * (((g - b) / delta) % 6);
  } else if (maxC == g) {
    h = 60 * (((b - r) / delta) + 2);
  } else {
    h = 60 * (((r - g) / delta) + 4);
  }
  if (h < 0) h += 360;
  return ((h / 2).round() % 180, s, v);
}

bool _inAny(List<HsvRange> ranges, int h, int s, int v) {
  for (final r in ranges) {
    if (r.contains(h, s, v)) return true;
  }
  return false;
}

/// Rangos de "mancha" que se usan para una enfermedad (comunes + propios).
List<HsvRange> lesionRangesFor(String label) => [
  ...AnalysisConfig.commonLesionRanges,
  ...?AnalysisConfig.lesionRangesByLabel[label],
];

/// Mide el área afectada de la hoja para la enfermedad [label].
SegmentationResult segmentLeaf(img.Image image, String label) {
  final w = image.width;
  final h = image.height;
  final n = w * h;
  final leaf = Uint8List(n);
  final lesion = Uint8List(n);
  final lesionRanges = lesionRangesFor(label);

  // 1) Clasificar cada píxel: tejido verde (hoja sana) o color de mancha.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final (hh, ss, vv) = rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
      final i = y * w + x;
      if (_inAny(AnalysisConfig.leafRanges, hh, ss, vv)) {
        leaf[i] = 1; // el verde tiene prioridad sobre "mancha"
      } else if (_inAny(lesionRanges, hh, ss, vv)) {
        lesion[i] = 1;
      }
    }
  }

  // 2) Silueta de la hoja: cerrar (dilatar + erosionar) el verde y rellenar
  //    los huecos interiores (las manchas quedan dentro de la hoja).
  final radius = math.max(
    1,
    (math.max(w, h) * AnalysisConfig.leafClosingRadiusPercent / 100).round(),
  );
  final closed = _erode(_dilate(leaf, w, h, radius), w, h, radius);
  final region = _fillHoles(closed, w, h);

  // 3) Sumar manchas pegadas al borde de la hoja (dentro del radio).
  final near = _dilate(region, w, h, radius);
  var leafPixels = 0;
  var affected = 0;
  for (var i = 0; i < n; i++) {
    final inLeaf = region[i] == 1 || (lesion[i] == 1 && near[i] == 1);
    if (!inLeaf) continue;
    leafPixels++;
    if (lesion[i] == 1) affected++;
  }

  return SegmentationResult(
    leafPixels: leafPixels,
    affectedPixels: affected,
    totalPixels: n,
  );
}

// ---------------------------------------------------------------------------
//  Operaciones morfológicas sobre máscaras binarias (0/1), ventana cuadrada.
// ---------------------------------------------------------------------------

/// Cuenta, para cada píxel, cuántos 1 hay en la ventana (2r+1)x(2r+1).
Int32List _boxCount(Uint8List mask, int w, int h, int r) {
  final rows = Int32List(w * h);
  for (var y = 0; y < h; y++) {
    var acc = 0;
    final base = y * w;
    for (var x = 0; x < math.min(r, w); x++) {
      acc += mask[base + x];
    }
    for (var x = 0; x < w; x++) {
      final add = x + r;
      if (add < w) acc += mask[base + add];
      rows[base + x] = acc;
      final rem = x - r;
      if (rem >= 0) acc -= mask[base + rem];
    }
  }
  final out = Int32List(w * h);
  for (var x = 0; x < w; x++) {
    var acc = 0;
    for (var y = 0; y < math.min(r, h); y++) {
      acc += rows[y * w + x];
    }
    for (var y = 0; y < h; y++) {
      final add = y + r;
      if (add < h) acc += rows[add * w + x];
      out[y * w + x] = acc;
      final rem = y - r;
      if (rem >= 0) acc -= rows[rem * w + x];
    }
  }
  return out;
}

Uint8List _dilate(Uint8List mask, int w, int h, int r) {
  final c = _boxCount(mask, w, h, r);
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = c[i] > 0 ? 1 : 0;
  }
  return out;
}

Uint8List _erode(Uint8List mask, int w, int h, int r) {
  final c = _boxCount(mask, w, h, r);
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final wy = math.min(h - 1, y + r) - math.max(0, y - r) + 1;
    for (var x = 0; x < w; x++) {
      final wx = math.min(w - 1, x + r) - math.max(0, x - r) + 1;
      final i = y * w + x;
      // Fuera de la imagen no cuenta: solo se exige la parte dentro.
      out[i] = c[i] == wx * wy ? 1 : 0;
    }
  }
  return out;
}

/// Rellena los huecos (zonas 0 rodeadas de 1 que no tocan el borde).
Uint8List _fillHoles(Uint8List mask, int w, int h) {
  final outside = Uint8List(w * h);
  final queue = Queue<int>();
  void seed(int i) {
    if (mask[i] == 0 && outside[i] == 0) {
      outside[i] = 1;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w;
    final y = i ~/ w;
    if (x > 0) seed(i - 1);
    if (x < w - 1) seed(i + 1);
    if (y > 0) seed(i - w);
    if (y < h - 1) seed(i + w);
  }
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = outside[i] == 1 ? 0 : 1;
  }
  return out;
}
