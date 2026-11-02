import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'geo/cells.dart';
import 'geo/shape.dart';

class PoiCategory {
  const PoiCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

const poiCategories = <String, PoiCategory>{
  'monumento': PoiCategory('Monumento', Icons.account_balance, Color(0xFFE0A458)),
  'mirador': PoiCategory('Mirador', Icons.landscape, Color(0xFF6EC6CA)),
  'museo': PoiCategory('Museo', Icons.museum, Color(0xFFB388FF)),
  'arte': PoiCategory('Arte', Icons.palette, Color(0xFFFF8A80)),
  'parque': PoiCategory('Parque', Icons.park, Color(0xFF81C784)),
  'naturaleza': PoiCategory('Naturaleza', Icons.terrain, Color(0xFFA5D6A7)),
  'atraccion': PoiCategory('Atracción', Icons.star, Color(0xFFFFD54F)),
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
  PoiCategory get info => poiCategories[category] ?? poiCategories['atraccion']!;

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
