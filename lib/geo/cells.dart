import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// The world is split into a Web Mercator grid at zoom 21: cells of about
/// 19 m at the equator. A cell is "explored" once you pass close to it.
class Cells {
  static const int zoom = 21;
  static const int n = 1 << zoom;
  static const double earthCircumference = 40075016.686;

  /// Cells whose centre is within this distance of a GPS fix are revealed.
  static const double revealRadius = 30;

  /// Buckets group 64x64 cells so the fog painter can skip off-screen areas.
  static const int bucketShift = 6;
  static const int bucketsPerSide = n >> bucketShift;

  static int key(int x, int y) => x * n + y;
  static int xOf(int key) => key ~/ n;
  static int yOf(int key) => key % n;

  static double lonToX(double lon) => (lon + 180) / 360 * n;

  static double latToY(double lat) {
    final r = lat * math.pi / 180;
    return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n;
  }

  static double xToLon(double x) => x / n * 360 - 180;

  static double yToLat(double y) {
    final m = math.pi * (1 - 2 * y / n);
    return 180 / math.pi * math.atan(0.5 * (math.exp(m) - math.exp(-m)));
  }

  static int keyAt(double lat, double lon) => key(
      lonToX(lon).floor().clamp(0, n - 1), latToY(lat).floor().clamp(0, n - 1));

  static LatLng center(int key) =>
      LatLng(yToLat(yOf(key) + 0.5), xToLon(xOf(key) + 0.5));

  static double cellSizeMeters(double lat) =>
      earthCircumference * math.cos(lat * math.pi / 180) / n;

  static double cellAreaM2(double lat) {
    final s = cellSizeMeters(lat);
    return s * s;
  }

  static int bucketOf(int key) =>
      (xOf(key) >> bucketShift) * bucketsPerSide + (yOf(key) >> bucketShift);

  static int bucketKey(int bx, int by) => bx * bucketsPerSide + by;

  /// Keys of every cell whose centre lies within [radius] metres of [p].
  static Iterable<int> around(LatLng p, double radius) sync* {
    final fx = lonToX(p.longitude);
    final fy = latToY(p.latitude);
    final r = radius / cellSizeMeters(p.latitude);
    final span = r.ceil();
    final cx = fx.floor();
    final cy = fy.floor();
    for (var dx = -span; dx <= span; dx++) {
      for (var dy = -span; dy <= span; dy++) {
        final x = cx + dx;
        final y = cy + dy;
        if (y < 0 || y >= n) continue;
        final ddx = x + 0.5 - fx;
        final ddy = y + 0.5 - fy;
        if (ddx * ddx + ddy * ddy <= r * r) {
          yield key(((x % n) + n) % n, y);
        }
      }
    }
  }
}

/// Fast distance in metres, accurate enough for short walking distances.
double quickDistance(LatLng a, LatLng b) {
  const r = 6371000.0;
  final lat0 = (a.latitude + b.latitude) / 2 * math.pi / 180;
  final dx = (b.longitude - a.longitude) * math.pi / 180 * math.cos(lat0);
  final dy = (b.latitude - a.latitude) * math.pi / 180;
  return r * math.sqrt(dx * dx + dy * dy);
}
