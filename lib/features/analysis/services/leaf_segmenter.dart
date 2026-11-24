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

/// Mide el % de la hoja afectado (marrón, amarillo intenso, gris o negro).
/// No depende de la enfermedad: se calcula antes de decidir.
SegmentationResult segmentLeaf(img.Image image) {
  final w = image.width;
  final h = image.height;
  final n = w * h;
  final leaf = Uint8List(n);
  // 0 = nada · 1 = mancha de color (marrón, naranja, amarillo intenso)
  // 2 = mancha neutra (gris o negro): solo cuenta si está dentro de la hoja.
  final lesion = Uint8List(n);
  const lesionRanges = AnalysisConfig.lesionRanges;
  const neutralRanges = AnalysisConfig.neutralLesionRanges;

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
      } else if (_inAny(neutralRanges, hh, ss, vv)) {
        lesion[i] = 2;
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
  //    Solo se rellenan huecos pequeños (manchas); los grandes son fondo.
  final maxHole = (n * AnalysisConfig.maxLesionHolePercent / 100).round();
  final region = _fillHoles(closed, w, h, maxHole, lesion);

  // 3) Sumar manchas DE COLOR pegadas al borde de la hoja (dentro del radio).
  //    Las neutras (gris/negro) del borde no se suman: suelen ser sombra.
  final near = _dilate(region, w, h, radius);
  var leafPixels = 0;
  var affected = 0;
  for (var i = 0; i < n; i++) {
    final inLeaf = region[i] == 1 || (lesion[i] == 1 && near[i] == 1);
    if (!inLeaf) continue;
    leafPixels++;
    if (lesion[i] != 0) affected++;
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

/// Rellena los huecos (zonas 0 rodeadas de 1 que no tocan el borde) que
/// midan como máximo [maxHolePixels]. De los huecos más grandes solo se
/// toman los píxeles de mancha DE COLOR ([lesion] == 1); el resto es fondo.
Uint8List _fillHoles(
  Uint8List mask,
  int w,
  int h,
  int maxHolePixels,
  Uint8List lesion,
) {
  final n = w * h;
  // 0 = sin visitar · 1 = fondo conectado al borde · 2 = hueco ya revisado
  final state = Uint8List(n);
  final out = Uint8List.fromList(mask);
  final queue = Queue<int>();

  void flood(int start, int mark, List<int>? collect) {
    state[start] = mark;
    queue.add(start);
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      collect?.add(i);
      final x = i % w;
      final y = i ~/ w;
      for (final j in [
        if (x > 0) i - 1,
        if (x < w - 1) i + 1,
        if (y > 0) i - w,
        if (y < h - 1) i + w,
      ]) {
        if (mask[j] == 0 && state[j] == 0) {
          state[j] = mark;
          queue.add(j);
        }
      }
    }
  }

  // Fondo que toca el borde de la imagen.
  for (var x = 0; x < w; x++) {
    for (final i in [x, (h - 1) * w + x]) {
      if (mask[i] == 0 && state[i] == 0) flood(i, 1, null);
    }
  }
  for (var y = 0; y < h; y++) {
    for (final i in [y * w, y * w + w - 1]) {
      if (mask[i] == 0 && state[i] == 0) flood(i, 1, null);
    }
  }
  // Huecos interiores: se rellenan solo si son pequeños.
  for (var i = 0; i < n; i++) {
    if (mask[i] == 0 && state[i] == 0) {
      final hole = <int>[];
      flood(i, 2, hole);
      final small = hole.length <= maxHolePixels;
      for (final j in hole) {
        if (small || lesion[j] == 1) out[j] = 1;
      }
    }
  }
  return out;
}
