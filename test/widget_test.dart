import 'package:bruma/game/progress.dart';
import 'package:bruma/geo/cells.dart';
import 'package:bruma/geo/shape.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('cell keys round-trip to nearby centres', () {
    const p = LatLng(4.7110, -74.0721);
    final keys = Cells.around(p, Cells.revealRadius).toList();
    expect(keys, isNotEmpty);
    for (final k in keys) {
      expect(quickDistance(Cells.center(k), p), lessThan(Cells.revealRadius + 20));
    }
  });

  test('shape contains points and has a sensible area', () {
    // Roughly a 1 km x 1 km square near the equator.
    final shape = GeoShape.fromGeoJson({
      'type': 'Polygon',
      'coordinates': [
        [[0.0, 0.0], [0.009, 0.0], [0.009, 0.009], [0.0, 0.009], [0.0, 0.0]]
      ],
    })!;
    expect(shape.contains(0.004, 0.004), isTrue);
    expect(shape.contains(0.02, 0.004), isFalse);
    expect(shape.areaM2(), closeTo(1.0e6, 0.03e6));
  });

  test('levels and streaks', () {
    expect(levelFor(0), 1);
    expect(levelFor(100), 2);
    expect(xpForLevel(levelFor(450)), lessThanOrEqualTo(450));
    expect(bestStreak({'2026-03-07': 20, '2026-03-08': 15, '2026-03-09': 12, '2026-03-11': 50}), 3);
  });

  test('percent formatting keeps tiny values readable', () {
    expect(formatPercent(12.5), '12.50 %');
    expect(formatPercent(0.0000213), '0.000021 %');
    expect(formatPercent(0), '0 %');
  });
}
