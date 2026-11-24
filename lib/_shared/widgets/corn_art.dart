import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/corn_palette.dart';

// ============================================================================
//  DIBUJOS DEL MAÍZ (hechos con código, sin imágenes)
//  - CornPlantArt : planta de maíz que crece según los días desde la siembra.
//  - CornCobChart : mazorca cuyos granos muestran plantas sanas / enfermas.
//  - WaterDropGauge: gota que se vacía con los días sin riego.
// ============================================================================

/// Planta de maíz. [growth] va de 0 (brote) a 1 (madura con mazorca).
/// Si [sway] es true, se mece suavemente como con el viento.
class CornPlantArt extends StatefulWidget {
  final double growth;
  final Color leafColor;
  final bool spots;
  final double size;
  final bool sway;

  const CornPlantArt({
    super.key,
    required this.growth,
    this.leafColor = CornPalette.leaf,
    this.spots = false,
    this.size = 72,
    this.sway = false,
  });

  @override
  State<CornPlantArt> createState() => _CornPlantArtState();
}

class _CornPlantArtState extends State<CornPlantArt>
    with SingleTickerProviderStateMixin {
  AnimationController? _wind;

  @override
  void initState() {
    super.initState();
    if (widget.sway) {
      _wind = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _wind?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Al aparecer, la planta "crece" desde el suelo hasta su tamaño real.
    final plant = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.growth),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, g, _) => _paint(g, 0),
    );
    final wind = _wind;
    if (wind == null) return plant;
    return AnimatedBuilder(
      animation: wind,
      builder: (_, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.growth),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, g, _) =>
            _paint(g, (Curves.easeInOut.transform(wind.value) - 0.5) * 0.06),
      ),
    );
  }

  Widget _paint(double growth, double swayAngle) => SizedBox.square(
    dimension: widget.size,
    child: CustomPaint(
      painter: _CornPlantPainter(
        growth: growth,
        leafColor: widget.leafColor,
        spots: widget.spots,
        sway: swayAngle,
      ),
    ),
  );
}

class _CornPlantPainter extends CustomPainter {
  final double growth;
  final Color leafColor;
  final bool spots;
  final double sway;

  _CornPlantPainter({
    required this.growth,
    required this.leafColor,
    required this.spots,
    required this.sway,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final g = growth.clamp(0.0, 1.0);
    final ground = h * 0.9;

    // Tierra.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, ground),
        width: w * 0.7,
        height: h * 0.1,
      ),
      Paint()..color = CornPalette.soil.withValues(alpha: 0.35),
    );
    if (g <= 0.01) return;

    canvas.save();
    canvas.translate(w / 2, ground);
    canvas.rotate(sway);

    final stalkH = h * (0.18 + 0.66 * g);
    final stalkW = w * (0.025 + 0.03 * g);

    // Tallo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-stalkW / 2, -stalkH, stalkW, stalkH),
        Radius.circular(stalkW),
      ),
      Paint()..color = Color.lerp(leafColor, CornPalette.leafDark, 0.25)!,
    );

    // Hojas alternadas a cada lado, más grandes abajo.
    final leaves = 2 + (g * 6).round();
    final leafPaint = Paint()..color = leafColor;
    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.008);
    final spotPaint = Paint()..color = CornPalette.sick;
    for (var i = 0; i < leaves; i++) {
      final t = (i + 1) / (leaves + 1);
      final y = -stalkH * (0.12 + 0.8 * t);
      final side = i.isEven ? 1.0 : -1.0;
      final len = w * (0.42 - 0.18 * t) * (0.55 + 0.45 * g);
      final droop = h * (0.05 + 0.06 * (1 - t));
      final tip = Offset(side * len, y + droop);
      final ctrlUp = Offset(side * len * 0.45, y - h * 0.11);
      final ctrlDown = Offset(side * len * 0.55, y - h * 0.02);
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(ctrlUp.dx, ctrlUp.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(ctrlDown.dx, ctrlDown.dy, 0, y + h * 0.025);
      canvas.drawPath(path, leafPaint);
      canvas.drawPath(
        Path()
          ..moveTo(0, y + h * 0.01)
          ..quadraticBezierTo(
            side * len * 0.5,
            y - h * 0.06,
            tip.dx * 0.92,
            tip.dy - h * 0.005,
          ),
        veinPaint,
      );
      if (spots && i < leaves - 1) {
        for (var k = 0; k < 3; k++) {
          final f = 0.35 + k * 0.18;
          canvas.drawCircle(
            Offset(side * len * f, y - h * 0.04 + droop * f),
            w * 0.018,
            spotPaint,
          );
        }
      }
    }

    // Panoja (flor de arriba) desde la floración.
    if (g > 0.4) {
      final tp = Paint()
        ..color = CornPalette.tassel
        ..strokeWidth = math.max(1.2, w * 0.016)
        ..strokeCap = StrokeCap.round;
      final top = Offset(0, -stalkH);
      for (final a in [-0.55, -0.2, 0.2, 0.55]) {
        final l = h * 0.1 * ((g - 0.4) / 0.6).clamp(0.4, 1.0);
        canvas.drawLine(
          top,
          top + Offset(math.sin(a) * l, -math.cos(a) * l),
          tp,
        );
      }
    }

    // Mazorca desde el llenado de grano.
    if (g > 0.58) {
      final s = ((g - 0.58) / 0.42).clamp(0.35, 1.0);
      final center = Offset(stalkW * 1.6, -stalkH * 0.5);
      final cob = Rect.fromCenter(
        center: center,
        width: w * 0.11 * s,
        height: h * 0.24 * s,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(0.35);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(cob, Paint()..color = CornPalette.gold);
      // Hoja que envuelve la mazorca (chala).
      canvas.drawPath(
        Path()
          ..moveTo(cob.left, cob.bottom)
          ..quadraticBezierTo(
            cob.left - cob.width * 0.3,
            cob.center.dy,
            cob.center.dx,
            cob.top + cob.height * 0.25,
          )
          ..quadraticBezierTo(
            cob.left + cob.width * 0.2,
            cob.center.dy,
            cob.center.dx,
            cob.bottom,
          )
          ..close(),
        Paint()..color = CornPalette.husk,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CornPlantPainter old) =>
      old.growth != growth ||
      old.sway != sway ||
      old.leafColor != leafColor ||
      old.spots != spots;
}

/// Mazorca con granos de colores: cada grano representa una parte de tus
/// plantas. Dorado = sanas, amarillo claro = en observación, marrón = enfermas.
class CornCobChart extends StatelessWidget {
  final int healthy;
  final int watch;
  final int sick;
  final double height;

  const CornCobChart({
    super.key,
    required this.healthy,
    required this.watch,
    required this.sick,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => SizedBox(
        width: height * 0.62,
        height: height,
        child: CustomPaint(
          painter: _CobPainter(
            healthy: healthy,
            watch: watch,
            sick: sick,
            progress: t,
          ),
        ),
      ),
    );
  }
}

class _CobPainter extends CustomPainter {
  final int healthy, watch, sick;
  final double progress;

  _CobPainter({
    required this.healthy,
    required this.watch,
    required this.sick,
    required this.progress,
  });

  static const _rows = 11;
  static const _cols = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cob = Rect.fromLTWH(w * 0.2, h * 0.02, w * 0.6, h * 0.82);

    // Fondo de la mazorca.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        cob,
        topLeft: Radius.elliptical(cob.width / 2, cob.height * 0.3),
        topRight: Radius.elliptical(cob.width / 2, cob.height * 0.3),
        bottomLeft: Radius.elliptical(cob.width / 2, cob.height * 0.12),
        bottomRight: Radius.elliptical(cob.width / 2, cob.height * 0.12),
      ),
      Paint()..color = CornPalette.goldDark.withValues(alpha: 0.35),
    );

    final total = healthy + watch + sick;
    const n = _rows * _cols;
    // Cuántos granos le tocan a cada grupo (redondeo justo).
    int share(int count) => total == 0 ? 0 : (count / total * n).round();
    final healthyK = share(healthy);
    final watchK = math.min(n - healthyK, share(watch));
    final visible = (progress * n).round();

    final kh = cob.height / (_rows + 0.6);
    var k = 0;
    // Se llena de abajo hacia arriba.
    for (var r = _rows - 1; r >= 0; r--) {
      final y = cob.top + kh * (r + 0.55);
      // La mazorca es más angosta arriba.
      final narrow = r < 3 ? (3 - r) * 0.09 : 0.0;
      final rowW = cob.width * (0.92 - narrow);
      final kw = rowW / _cols;
      for (var c = 0; c < _cols; c++) {
        final Color color;
        if (total == 0) {
          color = CornPalette.cream;
        } else if (k >= visible) {
          color = CornPalette.goldLight.withValues(alpha: 0.45);
        } else if (k < healthyK) {
          color = CornPalette.gold;
        } else if (k < healthyK + watchK) {
          color = CornPalette.watch;
        } else {
          color = CornPalette.sick;
        }
        final x = cob.center.dx - rowW / 2 + kw * c;
        final kernel = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + kw * 0.08, y - kh * 0.45, kw * 0.84, kh * 0.88),
          Radius.circular(kw * 0.35),
        );
        canvas.drawRRect(kernel, Paint()..color = color);
        // Brillo del grano.
        canvas.drawCircle(
          Offset(x + kw * 0.35, y - kh * 0.15),
          kw * 0.1,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
        k++;
      }
    }

    // Hojas de la chala a los lados.
    final husk = Paint()..color = CornPalette.leafLight;
    final huskDark = Paint()..color = CornPalette.leaf;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h)
        ..quadraticBezierTo(w * 0.02, h * 0.75, w * 0.08, h * 0.32)
        ..quadraticBezierTo(w * 0.22, h * 0.7, w * 0.5, h * 0.86)
        ..close(),
      huskDark,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h)
        ..quadraticBezierTo(w * 0.98, h * 0.75, w * 0.92, h * 0.38)
        ..quadraticBezierTo(w * 0.78, h * 0.72, w * 0.5, h * 0.86)
        ..close(),
      husk,
    );
  }

  @override
  bool shouldRepaint(_CobPainter old) =>
      old.progress != progress ||
      old.healthy != healthy ||
      old.watch != watch ||
      old.sick != sick;
}

/// Gota de agua que se llena según [level] (1 = recién regada).
class WaterDropGauge extends StatelessWidget {
  final double level;
  final double size;

  const WaterDropGauge({super.key, required this.level, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: level.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => SizedBox(
        width: size * 0.78,
        height: size,
        child: CustomPaint(painter: _DropPainter(v)),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  final double level;

  _DropPainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final drop = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.62, h * 0.22, w, h * 0.45, w, h * 0.66)
      ..arcToPoint(Offset(0, h * 0.66), radius: Radius.circular(w / 2))
      ..cubicTo(0, h * 0.45, w * 0.38, h * 0.22, w / 2, 0)
      ..close();

    canvas.drawPath(
      drop,
      Paint()..color = CornPalette.water.withValues(alpha: 0.15),
    );
    canvas.save();
    canvas.clipPath(drop);
    final top = h * (1 - level);
    canvas.drawRect(
      Rect.fromLTWH(0, top, w, h - top),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CornPalette.water, CornPalette.waterDark],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.restore();
    canvas.drawPath(
      drop,
      Paint()
        ..color = CornPalette.waterDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.05),
    );
    // Brillo.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.24, h * 0.5, w * 0.16, h * 0.18),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.level != level;
}

/// Aparece con un desvanecido y un pequeño deslizamiento hacia arriba.
/// [delayMs] permite que las tarjetas aparezcan una tras otra.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    final total = 380 + delayMs;
    final start = delayMs / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
