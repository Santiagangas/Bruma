import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models.dart';

/// Free OpenStreetMap services. Only coordinates of the area being looked up
/// are sent; your history and progress never leave the phone.
class OsmClient {
  static const userAgent = 'Bruma/1.0 (app personal de exploracion)';
  static const poiTileZoom = 14;

  final http.Client _http = http.Client();

  /// OSM admin_level used for municipalities in each country (8 elsewhere).
  static const _municipalityLevel = {
    'CO': 6, 'MX': 6, 'EC': 6, 'VE': 6, 'BO': 6, 'PY': 6,
  };

  /// The municipality at [p] with its boundary: Overpass finds which
  /// boundaries contain the point, Nominatim provides the outline.
  Future<({String id, String name, String geojson})?> cityAt(LatLng p) async {
    final q = '[out:json][timeout:25];'
        'is_in(${p.latitude},${p.longitude})->.a;'
        'rel(pivot.a)[boundary=administrative];out tags;';
    final rels = [
      for (final e in (await _overpass(q))['elements'] as List<dynamic>)
        e as Map<String, dynamic>
    ];
    int levelOf(Map<String, dynamic> e) =>
        int.tryParse('${(e['tags'] as Map?)?['admin_level']}') ?? 0;
    String? country;
    for (final e in rels) {
      if (levelOf(e) == 2) {
        country = (e['tags'] as Map)['ISO3166-1:alpha2'] as String? ??
            (e['tags'] as Map)['ISO3166-1'] as String?;
      }
    }
    final target = _municipalityLevel[country] ?? 8;
    // The exact level if present, otherwise the closest larger area.
    Map<String, dynamic>? pick;
    for (final e in rels) {
      final l = levelOf(e);
      if (l < 3 || l > target) continue;
      if (pick == null || l > levelOf(pick)) pick = e;
    }
    if (pick == null) return null;
    final id = pick['id'];

    final uri = Uri.https('nominatim.openstreetmap.org', '/lookup', {
      'osm_ids': 'R$id',
      'format': 'jsonv2',
      'polygon_geojson': '1',
      'polygon_threshold': '0.0002',
      'accept-language': 'es',
    });
    final res = await _http
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    if (list.isEmpty) return null;
    final j = list.first as Map<String, dynamic>;
    final geo = j['geojson'];
    if (geo is! Map<String, dynamic>) return null;
    if (geo['type'] != 'Polygon' && geo['type'] != 'MultiPolygon') return null;
    final tagName = ((pick['tags'] as Map)['name'] as String?)?.trim();
    final name = (j['name'] as String?)?.trim();
    return (
      id: 'relation/$id',
      name: (name != null && name.isNotEmpty)
          ? name
          : (tagName ?? 'Lugar sin nombre'),
      geojson: jsonEncode(geo),
    );
  }

  /// Runs an Overpass query, waiting and retrying if the free server is busy.
  Future<Map<String, dynamic>> _overpass(String query) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: 8 * attempt));
      }
      try {
        final res = await _http
            .post(Uri.https('overpass-api.de', '/api/interpreter'),
                headers: {'User-Agent': userAgent}, body: {'data': query})
            .timeout(const Duration(seconds: 40));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
        lastError = http.ClientException('Overpass ${res.statusCode}');
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? http.ClientException('Overpass sin respuesta');
  }

  /// Points of interest inside one zoom-14 tile, via the Overpass API.
  Future<List<Poi>> poisInTile(int tile) async {
    final n = 1 << poiTileZoom;
    final x = tile ~/ n, y = tile % n;
    final west = x / n * 360 - 180;
    final east = (x + 1) / n * 360 - 180;
    final north = _tileLat(y, n);
    final south = _tileLat(y + 1, n);
    final bbox = '$south,$west,$north,$east';
    final query = '[out:json][timeout:25];('
        'nwr["historic"]["name"]($bbox);'
        'nwr["tourism"~"^(attraction|viewpoint|museum|gallery|artwork)\$"]["name"]($bbox);'
        'nwr["leisure"~"^(park|garden|nature_reserve)\$"]["name"]($bbox);'
        'nwr["natural"~"^(peak|waterfall|cave_entrance|spring|volcano|beach)\$"]["name"]($bbox);'
        ');out center tags;';
    final j = await _overpass(query);
    final out = <Poi>[];
    for (final e in j['elements'] as List<dynamic>) {
      final el = e as Map<String, dynamic>;
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? {};
      final name = tags['name'] as String?;
      final pos = el['center'] as Map<String, dynamic>? ?? el;
      final lat = (pos['lat'] as num?)?.toDouble();
      final lon = (pos['lon'] as num?)?.toDouble();
      final cat = _category(tags);
      if (name == null || lat == null || lon == null || cat == null) continue;
      out.add(Poi(
        id: '${el['type']}/${el['id']}',
        name: name,
        category: cat,
        lat: lat,
        lon: lon,
      ));
    }
    return out;
  }

  static int tileOf(LatLng p) {
    final n = 1 << poiTileZoom;
    final x = ((p.longitude + 180) / 360 * n).floor().clamp(0, n - 1);
    final r = p.latitude * math.pi / 180;
    final y = ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n)
        .floor()
        .clamp(0, n - 1);
    return x * n + y;
  }

  /// The tile at [tile] plus its 8 neighbours.
  static List<int> neighbourhood(int tile) {
    final n = 1 << poiTileZoom;
    final x = tile ~/ n, y = tile % n;
    return [
      for (var dx = -1; dx <= 1; dx++)
        for (var dy = -1; dy <= 1; dy++)
          if (y + dy >= 0 && y + dy < n) ((x + dx + n) % n) * n + (y + dy)
    ];
  }

  static double _tileLat(int y, int n) {
    final m = math.pi * (1 - 2 * y / n);
    return 180 / math.pi * math.atan(0.5 * (math.exp(m) - math.exp(-m)));
  }

  static String? _category(Map<String, dynamic> t) {
    final tourism = t['tourism'];
    if (tourism == 'viewpoint') return 'mirador';
    if (tourism == 'museum' || tourism == 'gallery') return 'museo';
    if (tourism == 'artwork') return 'arte';
    if (t['natural'] != null) return 'naturaleza';
    if (t['leisure'] == 'nature_reserve') return 'naturaleza';
    if (t['leisure'] == 'park' || t['leisure'] == 'garden') return 'parque';
    if (t['historic'] != null) return 'monumento';
    if (tourism == 'attraction') return 'atraccion';
    return null;
  }
}
