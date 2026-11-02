import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';

import '../app_state.dart';
import '../geo/cells.dart';
import '../settings.dart';
import 'theme.dart';

/// Covers the map in opaque fog and opens a 30 m circle around every place
/// you have passed through. The edge of each opening has a 1.5 px green
/// border and the fog casts a soft shadow onto the map, as in the design.
class FogLayer extends StatefulWidget {
  const FogLayer({super.key, required this.state, required this.settings});
  final AppState state;
  final Settings settings;

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<FogLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  DateTime _until = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.state.cellsVersion.addListener(_animate);
  }

  @override
  void dispose() {
    widget.state.cellsVersion.removeListener(_animate);
    _ticker.dispose();
    super.dispose();
  }

  void _animate() {
    _until = DateTime.now().add(_FogPainter.openTime);
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    if (DateTime.now().isAfter(_until)) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    return MobileLayerTransformer(
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => CustomPaint(
          size: camera.size,
          isComplex: true,
          painter: _FogPainter(
            camera: camera,
            state: widget.state,
            fog: widget.settings.fog.color,
            contours: widget.settings.contours,
            now: DateTime.now(),
            animate: !reduce,
          ),
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter({
    required this.camera,
    required this.state,
    required this.fog,
    required this.contours,
    required this.now,
    required this.animate,
  });

  final MapCamera camera;
  final AppState state;
  final Color fog;
  final bool contours;
  final DateTime now;
  final bool animate;

  /// A new circle opens from its centre in this time.
  static const openTime = Duration(milliseconds: 420);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Pixels per grid unit at the current zoom.
    final unitPx = camera.getWorldWidthAtZoom() / Cells.n;
    final origin = camera.pixelOrigin;
    const margin = 4.0;
    final x0 = origin.dx / unitPx - margin;
    final y0 = origin.dy / unitPx - margin;
    final x1 = (origin.dx + size.width) / unitPx + margin;
    final y1 = (origin.dy + size.height) / unitPx + margin;

    final holes = Path();
    final edges = Path();
    void addPoint(FogPoint p) {
      if (p.x < x0 || p.x > x1 || p.y < y0 || p.y > y1) return;
      var r = math.max(p.r * unitPx, 1.5);
      final born = p.born;
      if (animate && born != null) {
        final t = now.difference(born).inMilliseconds / openTime.inMilliseconds;
        if (t < 1) r *= Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
      }
      final c = Offset(p.x * unitPx - origin.dx, p.y * unitPx - origin.dy);
      holes.addOval(Rect.fromCircle(center: c, radius: r));
      edges.addOval(Rect.fromCircle(center: c, radius: r + 1.5));
    }

    const shift = Cells.bucketShift;
    final bx0 = math.max(x0.floor(), 0) >> shift;
    final bx1 = math.max(x1.ceil(), 0) >> shift;
    final by0 = math.max(y0.floor(), 0) >> shift;
    final by1 = math.max(y1.ceil(), 0) >> shift;
    final visibleBuckets = (bx1 - bx0 + 1) * (by1 - by0 + 1);
    if (visibleBuckets < state.fogBuckets.length) {
      for (var bx = bx0; bx <= bx1; bx++) {
        for (var by = by0; by <= by1; by++) {
          state.fogBuckets[Cells.bucketKey(bx, by)]?.forEach(addPoint);
        }
      }
    } else {
      for (final list in state.fogBuckets.values) {
        list.forEach(addPoint);
      }
    }

    final cut = Paint()
      ..blendMode = BlendMode.dstOut
      ..isAntiAlias = true;

    // 1. Shadow the fog casts on the map (2 px down, blur 4, 45 %).
    canvas.saveLayer(
        rect, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4));
    canvas.translate(0, 2);
    canvas.drawRect(rect.inflate(8), Paint()..color = Br.bg.withValues(alpha: .45));
    canvas.drawPath(holes, cut);
    canvas.restore();

    // 2. Green border: everywhere except inside the openings.
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Br.green);
    canvas.drawPath(holes, cut);
    canvas.restore();

    // 3. The fog itself, with its contour texture, 1.5 px further out.
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = fog);
    if (contours) _paintContours(canvas, size, origin);
    canvas.drawPath(edges, cut);
    canvas.restore();
  }

  /// Atlas-style contour lines, anchored to the map so they move with it.
  void _paintContours(Canvas canvas, Size size, Offset origin) {
    final paint = Paint()
      ..color = Br.fogLineFor(fog)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    final grid = Paint()
      ..color = Br.fogLineFor(fog)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    const w = _Contours.width, h = _Contours.height;
    final ox = -(origin.dx % w);
    final oy = -(origin.dy % h);
    for (var x = ox; x < size.width; x += w) {
      for (var y = oy; y < size.height; y += h) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPath(_Contours.lines, paint);
        canvas.drawPath(_Contours.grid, grid);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) => true;
}

/// One 390 × 844 tile of the fog texture, taken from the design.
abstract final class _Contours {
  static const width = 390.0;
  static const height = 844.0;

  static Path _loop(List<double> p) {
    // Closed cubic loop: p = [x0,y0, (c1x,c1y,c2x,c2y,x,y)×4].
    final path = Path()..moveTo(p[0], p[1]);
    for (var i = 2; i + 5 < p.length; i += 6) {
      path.cubicTo(p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4], p[i + 5]);
    }
    return path..close();
  }

  static Path _scaled(Path p, Offset c, double s) => p.transform(
      (Matrix4.identity()
            ..translateByDouble(c.dx, c.dy, 0, 1)
            ..scaleByDouble(s, s, 1, 1)
            ..translateByDouble(-c.dx, -c.dy, 0, 1))
          .storage);

  static final Path lines = () {
    final a = _loop([250, 230, 250, 165, 296, 140, 336, 146, 380, 152, 402, 196,
      396, 242, 390, 290, 346, 306, 306, 300, 270, 294, 250, 268, 250, 230]);
    final b = _loop([40, 130, 46, 92, 96, 76, 140, 84, 190, 94, 214, 124, 206,
      158, 198, 194, 150, 206, 104, 200, 62, 194, 34, 168, 40, 130]);
    final c = _loop([268, 560, 272, 520, 316, 500, 356, 510, 396, 520, 410, 556,
      400, 592, 390, 628, 344, 640, 308, 628, 278, 618, 264, 592, 268, 560]);
    final out = Path();
    for (final s in [1.0, .76, .52, .28]) {
      out.addPath(_scaled(a, const Offset(330, 225), s), Offset.zero);
    }
    for (final s in [1.0, .72, .44]) {
      out.addPath(_scaled(b, const Offset(124, 142), s), Offset.zero);
    }
    for (final s in [1.0, .7, .4]) {
      out.addPath(_scaled(c, const Offset(336, 570), s), Offset.zero);
    }
    out
      ..moveTo(-10, 760)
      ..cubicTo(60, 730, 120, 770, 190, 742)
      ..cubicTo(260, 714, 320, 750, 400, 720)
      ..moveTo(-10, 790)
      ..cubicTo(70, 762, 130, 800, 200, 774)
      ..cubicTo(270, 748, 330, 782, 400, 754)
      ..moveTo(-10, 318)
      ..cubicTo(40, 300, 70, 330, 120, 316)
      ..moveTo(-10, 336)
      ..cubicTo(44, 318, 76, 350, 128, 334);
    return out;
  }();

  /// Dashed survey grid (dash 2, gap 5).
  static final Path grid = () {
    final out = Path();
    void dashed(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 7) {
        final s = a + dir * d;
        final e = a + dir * math.min(d + 2, len);
        out
          ..moveTo(s.dx, s.dy)
          ..lineTo(e.dx, e.dy);
      }
    }

    for (final x in [0.0, 130.0, 260.0]) {
      dashed(Offset(x, 0), Offset(x, height));
    }
    for (final y in [0.0, 211.0, 422.0, 633.0]) {
      dashed(Offset(0, y), Offset(width, y));
    }
    return out;
  }();
}
