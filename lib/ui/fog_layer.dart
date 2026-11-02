import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../app_state.dart';
import '../geo/cells.dart';

/// Covers the map in solid fog and cuts a sharp circle around every place
/// you have passed through.
class FogLayer extends StatelessWidget {
  const FogLayer({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: ValueListenableBuilder<int>(
        valueListenable: state.cellsVersion,
        builder: (context, version, _) => CustomPaint(
          size: camera.size,
          isComplex: true,
          painter: _FogPainter(camera, state, version),
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter(this.camera, this.state, this.version);
  final MapCamera camera;
  final AppState state;
  final int version;

  static const fogColor = Color(0xFF151B2C);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = fogColor);

    // Pixels per grid unit at the current zoom.
    final unitPx = camera.getWorldWidthAtZoom() / Cells.n;
    final origin = camera.pixelOrigin;
    // Widen the visible window by one reveal radius (~2 units, with margin).
    const margin = 4.0;
    final x0 = origin.dx / unitPx - margin;
    final y0 = origin.dy / unitPx - margin;
    final x1 = (origin.dx + size.width) / unitPx + margin;
    final y1 = (origin.dy + size.height) / unitPx + margin;

    final path = Path();
    void addPoint(FogPoint p) {
      if (p.x < x0 || p.x > x1 || p.y < y0 || p.y > y1) return;
      path.addOval(Rect.fromCircle(
        center: Offset(p.x * unitPx - origin.dx, p.y * unitPx - origin.dy),
        radius: math.max(p.r * unitPx, 1.5),
      ));
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

    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FogPainter old) => true;
}
