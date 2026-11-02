import 'dart:math' as math;
import 'dart:typed_data';

import 'cells.dart';

class _Ring {
  _Ring(this.lats, this.lons);
  final Float64List lats;
  final Float64List lons;

  bool contains(double lat, double lon) {
    var inside = false;
    final len = lats.length;
    for (var i = 0, j = len - 1; i < len; j = i++) {
      final yi = lats[i], yj = lats[j];
      if ((yi > lat) != (yj > lat)) {
        final x = (lons[j] - lons[i]) * (lat - yi) / (yj - yi) + lons[i];
        if (lon < x) inside = !inside;
      }
    }
    return inside;
  }

  /// Area in m², using a local flat projection (fine at city scale).
  double area() {
    var lat0 = 0.0;
    for (final l in lats) {
      lat0 += l;
    }
    lat0 /= lats.length;
    const r = 6371000.0;
    final kx = r * math.pi / 180 * math.cos(lat0 * math.pi / 180);
    const ky = r * math.pi / 180;
    var sum = 0.0;
    final len = lats.length;
    for (var i = 0, j = len - 1; i < len; j = i++) {
      sum += (lons[j] * kx) * (lats[i] * ky) - (lons[i] * kx) * (lats[j] * ky);
    }
    return sum.abs() / 2;
  }
}

class _Polygon {
  _Polygon(this.outer, this.holes);
  final _Ring outer;
  final List<_Ring> holes;

  bool contains(double lat, double lon) {
    if (!outer.contains(lat, lon)) return false;
    for (final h in holes) {
      if (h.contains(lat, lon)) return false;
    }
    return true;
  }

  double area() {
    var a = outer.area();
    for (final h in holes) {
      a -= h.area();
    }
    return a;
  }
}

/// A city boundary read from GeoJSON (Polygon or MultiPolygon).
class GeoShape {
  GeoShape._(this._polygons, this.minLat, this.maxLat, this.minLon,
      this.maxLon);

  final List<_Polygon> _polygons;
  final double minLat, maxLat, minLon, maxLon;

  double get centerLat => (minLat + maxLat) / 2;

  static GeoShape? fromGeoJson(Map<String, dynamic> g) {
    final type = g['type'];
    final coords = g['coordinates'];
    List<dynamic> polys;
    if (type == 'Polygon') {
      polys = [coords];
    } else if (type == 'MultiPolygon') {
      polys = coords as List<dynamic>;
    } else {
      return null;
    }
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    final result = <_Polygon>[];
    for (final poly in polys) {
      final rings = <_Ring>[];
      for (final ring in poly as List<dynamic>) {
        final pts = ring as List<dynamic>;
        final lats = Float64List(pts.length);
        final lons = Float64List(pts.length);
        for (var i = 0; i < pts.length; i++) {
          final pt = pts[i] as List<dynamic>;
          lons[i] = (pt[0] as num).toDouble();
          lats[i] = (pt[1] as num).toDouble();
          minLat = math.min(minLat, lats[i]);
          maxLat = math.max(maxLat, lats[i]);
          minLon = math.min(minLon, lons[i]);
          maxLon = math.max(maxLon, lons[i]);
        }
        if (pts.length >= 3) rings.add(_Ring(lats, lons));
      }
      if (rings.isNotEmpty) {
        result.add(_Polygon(rings.first, rings.sublist(1)));
      }
    }
    if (result.isEmpty) return null;
    return GeoShape._(result, minLat, maxLat, minLon, maxLon);
  }

  bool contains(double lat, double lon) {
    if (lat < minLat || lat > maxLat || lon < minLon || lon > maxLon) {
      return false;
    }
    for (final p in _polygons) {
      if (p.contains(lat, lon)) return true;
    }
    return false;
  }

  bool containsCell(int key) {
    final c = Cells.center(key);
    return contains(c.latitude, c.longitude);
  }

  double areaM2() {
    var a = 0.0;
    for (final p in _polygons) {
      a += p.area();
    }
    return a;
  }
}
