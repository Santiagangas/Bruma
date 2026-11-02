import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'geo/cells.dart';
import 'geo/shape.dart';
import 'ui/icons.dart';

class PoiCategory {
  const PoiCategory(this.label, this.plural, this.icon, this.teaser, this.xp);
  final String label;
  final String plural;

  /// One of [BrIcons].
  final String icon;

  /// How the place is hinted at while it is still a mystery.
  final String teaser;

  /// XP for discovering it.
  final int xp;
}

const poiCategories = <String, PoiCategory>{
  'monumento': PoiCategory('Monumento', 'Monumentos', BrIcons.monument,
      'Un monumento escondido', 100),
  'mirador': PoiCategory(
      'Mirador', 'Miradores', BrIcons.viewpoint, 'Un mirador te espera', 150),
  'museo': PoiCategory(
      'Museo', 'Museos', BrIcons.museum, 'Un museo por descubrir', 100),
  'arte': PoiCategory(
      'Arte', 'Arte', BrIcons.art, 'Una obra de arte oculta', 80),
  'parque': PoiCategory(
      'Parque', 'Parques', BrIcons.park, 'Un parque entre la niebla', 60),
  'naturaleza': PoiCategory('Natural', 'Naturales', BrIcons.nature,
      'Un rincón natural', 100),
  'historico': PoiCategory('Sitio histórico', 'Históricos', BrIcons.historic,
      'Un sitio con historia', 120),
};

class Poi {
  Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    this.discovered,
  });

  final String id;
  final String name;
  final String category;
  final double lat;
  final double lon;

  /// Milliseconds since epoch, or null while still a mystery.
  int? discovered;

  LatLng get point => LatLng(lat, lon);
  // Older data used 'atraccion' for tourist attractions.
  PoiCategory get info =>
      poiCategories[category] ?? poiCategories['monumento']!;

  /// Big areas (parks, reserves) are mapped to their centre, so they get a
  /// wider discovery radius.
  double get discoverRadius =>
      category == 'parque' || category == 'naturaleza' ? 80 : 40;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'lat': lat,
        'lon': lon,
        'discovered': discovered,
      };

  factory Poi.fromJson(Map<String, dynamic> j) => Poi(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        discovered: j['discovered'] as int?,
      );
}

class City {
  City({required this.id, required this.name, required this.geojson})
      : shape = GeoShape.fromGeoJson(
            jsonDecode(geojson) as Map<String, dynamic>)! {
    area = shape.areaM2();
  }

  final String id;
  final String name;
  final String geojson;
  final GeoShape shape;
  late final double area;

  /// Percentage of the city covered by [explored] cells.
  double percent(int explored) {
    if (area <= 0) return 0;
    final p = explored * Cells.cellAreaM2(shape.centerLat) / area * 100;
    return p > 100 ? 100 : p;
  }
}
