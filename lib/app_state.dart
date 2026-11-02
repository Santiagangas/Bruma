import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'data/store.dart';
import 'game/progress.dart';
import 'geo/cells.dart';
import 'models.dart';
import 'services/osm.dart';

/// Land area of the Earth, used for the "% of the world" figure.
const worldLandKm2 = 148940000.0;

/// A place you passed through, in grid units (see [Cells]), with the radius
/// of fog it clears, also in grid units.
class FogPoint {
  FogPoint(double lat, double lon)
      : x = Cells.lonToX(lon),
        y = Cells.latToY(lat),
        r = Cells.revealRadius / Cells.cellSizeMeters(lat);
  final double x;
  final double y;
  final double r;
}

enum EventKind { badge, place, level, city }

class GameEvent {
  GameEvent(this.kind, this.title, this.subtitle);
  final EventKind kind;
  final String title;
  final String subtitle;
}

/// Counts explored cells per city. Runs in a background isolate because it
/// can mean hundreds of thousands of point-in-polygon tests.
Map<String, int> _countCellsPerCity(
    List<int> cells, Map<String, String> cityGeojson) {
  final cities = [
    for (final e in cityGeojson.entries)
      City(id: e.key, name: '', geojson: e.value)
  ];
  final counts = {for (final c in cities) c.id: 0};
  for (final key in cells) {
    final p = Cells.center(key);
    for (final c in cities) {
      if (c.shape.contains(p.latitude, p.longitude)) {
        counts[c.id] = counts[c.id]! + 1;
      }
    }
  }
  return counts;
}

Future<Map<String, int>> _countInBackground(
        List<int> cells, Map<String, String> geo) =>
    Isolate.run(() => _countCellsPerCity(cells, geo));

class AppState extends ChangeNotifier {
  final Store _store = Store();
  final OsmClient _osm = OsmClient();

  final Set<int> cells = {};
  final Map<int, List<int>> buckets = {};

  /// Fog-clearing points, grouped by bucket for fast drawing.
  final Map<int, List<FogPoint>> fogBuckets = {};
  final Set<int> _pointCells = {};

  /// Bumped whenever cells change, so the fog repaints.
  final ValueNotifier<int> cellsVersion = ValueNotifier(0);

  final Map<String, Poi> pois = {};
  final Set<int> _poiTiles = {};
  final List<City> cities = [];
  final Map<String, int> cityCells = {};
  final Map<String, int> unlocked = {};
  final Map<String, int> days = {};

  double distanceM = 0;
  int nightCells = 0;
  int earlyCells = 0;

  bool ready = false;
  bool tracking = false;
  LatLng? position;
  LatLng? lastKnown;
  double? accuracy;
  City? currentCity;

  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  StreamSubscription<Position>? _sub;
  Position? _lastFix;
  Future<void> _chain = Future.value();
  DateTime _lastMetaSave = DateTime.fromMillisecondsSinceEpoch(0);

  // City lookups are throttled (Nominatim allows 1 request per second, and
  // we need far less than that).
  bool _cityBusy = false;
  DateTime _lastCityLookup = DateTime.fromMillisecondsSinceEpoch(0);
  final List<LatLng> _cityMisses = [];

  // POI downloads, one tile at a time.
  final List<int> _tileQueue = [];
  final Map<int, DateTime> _tileFailures = {};
  bool _tilesBusy = false;

  // ---------------------------------------------------------------- loading

  Future<void> init() async {
    await _store.open();
    await _loadAll();
    ready = true;
    notifyListeners();
  }

  Future<void> _loadAll() async {
    cells.clear();
    buckets.clear();
    fogBuckets.clear();
    _pointCells.clear();
    pois.clear();
    _poiTiles.clear();
    cities.clear();
    cityCells.clear();
    unlocked.clear();
    days.clear();

    final cellList = await _store.loadCells();
    _addToMemory(cellList);
    for (final (lat, lon) in await _store.loadPoints()) {
      _addPoint(lat, lon);
    }
    for (final p in await _store.loadPois()) {
      pois[p.id] = p;
    }
    _poiTiles.addAll(await _store.loadPoiTiles());
    cities.addAll(await _store.loadCities());
    unlocked.addAll(await _store.loadBadges());
    days.addAll(await _store.loadDays());

    final meta = await _store.loadMeta();
    distanceM = double.tryParse(meta['distance_m'] ?? '') ?? 0;
    nightCells = int.tryParse(meta['night_cells'] ?? '') ?? 0;
    earlyCells = int.tryParse(meta['early_cells'] ?? '') ?? 0;
    final lat = double.tryParse(meta['last_lat'] ?? '');
    final lon = double.tryParse(meta['last_lon'] ?? '');
    if (lat != null && lon != null) lastKnown = LatLng(lat, lon);
    currentCity = null;

    if (cities.isNotEmpty) {
      cityCells.addAll(await _countInBackground(
          cellList, {for (final c in cities) c.id: c.geojson}));
    }
    if (lastKnown != null) _updateCurrentCity(lastKnown!);
    cellsVersion.value++;
  }

  /// Adds a fog point unless its cell already has one. Returns true if added.
  bool _addPoint(double lat, double lon) {
    final key = Cells.keyAt(lat, lon);
    if (!_pointCells.add(key)) return false;
    (fogBuckets[Cells.bucketOf(key)] ??= []).add(FogPoint(lat, lon));
    return true;
  }

  void _addToMemory(Iterable<int> keys) {
    for (final k in keys) {
      if (cells.add(k)) {
        (buckets[Cells.bucketOf(k)] ??= []).add(k);
      }
    }
  }

  // ---------------------------------------------------------------- derived

  int get discoveredCount => pois.values.where((p) => p.discovered != null).length;

  int get xp =>
      cells.length +
      50 * discoveredCount +
      200 * cities.length +
      100 * unlocked.length;

  int get level => levelFor(xp);

  double get exploredKm2 {
    final lat = (position ?? lastKnown)?.latitude ?? 0;
    return cells.length * Cells.cellAreaM2(lat) / 1e6;
  }

  double get worldPercent => exploredKm2 / worldLandKm2 * 100;

  double cityPercent(City c) => c.percent(cityCells[c.id] ?? 0);

  Stats get stats {
    final byCat = <String, int>{};
    for (final p in pois.values) {
      if (p.discovered != null) {
        byCat[p.category] = (byCat[p.category] ?? 0) + 1;
      }
    }
    var maxPct = 0.0;
    for (final c in cities) {
      final pct = cityPercent(c);
      if (pct > maxPct) maxPct = pct;
    }
    var bestDay = 0;
    for (final v in days.values) {
      if (v > bestDay) bestDay = v;
    }
    return Stats(
      cells: cells.length,
      distanceKm: distanceM / 1000,
      pois: discoveredCount,
      poisByCategory: byCat,
      cities: cities.length,
      maxCityPercent: maxPct,
      bestStreak: bestStreak(days),
      bestDay: bestDay,
      nightCells: nightCells,
      earlyCells: earlyCells,
    );
  }

  // --------------------------------------------------------------- tracking

  /// Returns an error message for the user, or null on success.
  Future<String?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Activa la ubicación (GPS) del teléfono.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return 'Bruma necesita el permiso de ubicación para despejar la niebla.';
    }
    return null;
  }

  Future<String?> startTracking() async {
    if (tracking) return null;
    final error = await _ensurePermission();
    if (error != null) return error;
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Bruma está explorando',
        notificationText: 'Despejando la niebla a tu paso',
        notificationChannelName: 'Exploración',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _lastFix = null;
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) => _chain = _chain.then((_) => _onFix(p)).catchError((Object e) {
        debugPrint('Error procesando posición: $e');
      }),
      onError: (Object e) {
        debugPrint('Error de GPS: $e');
        stopTracking();
      },
    );
    tracking = true;
    notifyListeners();
    return null;
  }

  Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
    tracking = false;
    await _saveMeta();
    notifyListeners();
  }

  /// One-off location, used by the "centre on me" button when not exploring.
  Future<String?> locateOnce() async {
    final error = await _ensurePermission();
    if (error != null) return error;
    final p = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high));
    position = LatLng(p.latitude, p.longitude);
    accuracy = p.accuracy;
    notifyListeners();
    return null;
  }

  Future<void> _onFix(Position p) async {
    final here = LatLng(p.latitude, p.longitude);
    position = here;
    accuracy = p.accuracy;
    // Fixes this imprecise would reveal places you never went.
    if (p.accuracy > 40) {
      notifyListeners();
      return;
    }

    final levelBefore = level;
    final now = DateTime.now();
    final fresh = <int>{};
    final freshPoints = <(double, double)>[];
    void reveal(LatLng q) {
      if (_addPoint(q.latitude, q.longitude)) {
        freshPoints.add((q.latitude, q.longitude));
      }
      for (final k in Cells.around(q, Cells.revealRadius)) {
        if (!cells.contains(k)) fresh.add(k);
      }
    }

    final last = _lastFix;
    if (last != null) {
      final from = LatLng(last.latitude, last.longitude);
      final d = quickDistance(from, here);
      final dt = p.timestamp.difference(last.timestamp).inMilliseconds.abs() / 1000;
      // Fill the gap between fixes, unless it looks like a GPS jump.
      if (d < 300 && dt < 300 && (dt == 0 || d / dt < 45)) {
        final steps = (d / 10).ceil().clamp(1, 30);
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          reveal(LatLng(from.latitude + (here.latitude - from.latitude) * t,
              from.longitude + (here.longitude - from.longitude) * t));
        }
        distanceM += d;
      } else {
        reveal(here);
      }
    } else {
      reveal(here);
    }
    _lastFix = p;
    lastKnown = here;

    _updateCurrentCity(here);

    if (fresh.isNotEmpty || freshPoints.isNotEmpty) {
      _addToMemory(fresh);
      final day = dayKey(now);
      if (fresh.isNotEmpty) days[day] = (days[day] ?? 0) + fresh.length;
      if (now.hour < 5) nightCells += fresh.length;
      if (now.hour >= 5 && now.hour < 7) earlyCells += fresh.length;
      for (final c in cities) {
        for (final k in fresh) {
          if (c.shape.containsCell(k)) {
            cityCells[c.id] = (cityCells[c.id] ?? 0) + 1;
          }
        }
      }
      await _store.saveProgress(
        newCells: fresh,
        newPoints: freshPoints,
        ts: now.millisecondsSinceEpoch,
        day: day,
        meta: _metaValues(),
      );
      _lastMetaSave = now;
      cellsVersion.value++;
    } else if (now.difference(_lastMetaSave).inSeconds > 30) {
      await _saveMeta();
    }

    await _checkPlaces(here, now);
    _queuePoiTiles(here);
    unawaited(_maybeLookupCity(here));
    await _checkBadges(now);
    final levelAfter = level;
    if (levelAfter > levelBefore) {
      _events.add(GameEvent(EventKind.level, '¡Nivel $levelAfter!',
          titleFor(levelAfter)));
    }
    notifyListeners();
  }

  Map<String, String> _metaValues() => {
        'distance_m': distanceM.toStringAsFixed(1),
        'night_cells': '$nightCells',
        'early_cells': '$earlyCells',
        if (lastKnown != null) 'last_lat': '${lastKnown!.latitude}',
        if (lastKnown != null) 'last_lon': '${lastKnown!.longitude}',
      };

  Future<void> _saveMeta() async {
    _lastMetaSave = DateTime.now();
    await _store.saveProgress(
        newCells: const [], ts: 0, day: '', meta: _metaValues());
  }

  // ----------------------------------------------------------------- places

  Future<void> _checkPlaces(LatLng here, DateTime now) async {
    for (final poi in pois.values) {
      if (poi.discovered != null) continue;
      if ((poi.lat - here.latitude).abs() > 0.002) continue;
      if (quickDistance(poi.point, here) <= poi.discoverRadius) {
        poi.discovered = now.millisecondsSinceEpoch;
        await _store.markDiscovered(poi.id, poi.discovered!);
        _events.add(GameEvent(EventKind.place, '¡Lugar descubierto!',
            '${poi.name} · ${poi.info.label}  (+50 XP)'));
      }
    }
  }

  void _queuePoiTiles(LatLng here) {
    final now = DateTime.now();
    for (final t in OsmClient.neighbourhood(OsmClient.tileOf(here))) {
      if (_poiTiles.contains(t) || _tileQueue.contains(t)) continue;
      final failed = _tileFailures[t];
      if (failed != null && now.difference(failed).inMinutes < 5) continue;
      _tileQueue.add(t);
    }
    unawaited(_drainTiles());
  }

  Future<void> _drainTiles() async {
    if (_tilesBusy) return;
    _tilesBusy = true;
    try {
      while (_tileQueue.isNotEmpty) {
        final tile = _tileQueue.removeAt(0);
        try {
          final found = await _osm.poisInTile(tile);
          await _store.addPois(found, tile, DateTime.now().millisecondsSinceEpoch);
          _poiTiles.add(tile);
          for (final p in found) {
            pois.putIfAbsent(p.id, () => p);
          }
          notifyListeners();
        } catch (e) {
          debugPrint('No se pudieron descargar lugares: $e');
          _tileFailures[tile] = DateTime.now();
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    } finally {
      _tilesBusy = false;
    }
  }

  // ----------------------------------------------------------------- cities

  void _updateCurrentCity(LatLng here) {
    City? found;
    for (final c in cities) {
      if (c.shape.contains(here.latitude, here.longitude)) {
        found = c;
        break;
      }
    }
    currentCity = found;
  }

  Future<void> _maybeLookupCity(LatLng here) async {
    if (currentCity != null || _cityBusy) return;
    if (DateTime.now().difference(_lastCityLookup).inSeconds < 60) return;
    for (final miss in _cityMisses) {
      if (quickDistance(miss, here) < 1000) return;
    }
    _cityBusy = true;
    _lastCityLookup = DateTime.now();
    try {
      final r = await _osm.cityAt(here);
      final City? city = r == null
          ? null
          : City(id: r.id, name: r.name, geojson: r.geojson);
      if (city == null ||
          !city.shape.contains(here.latitude, here.longitude) ||
          cities.any((c) => c.id == city.id)) {
        _cityMisses.add(here);
        return;
      }
      final counts = await _countInBackground(
          cells.toList(), {city.id: city.geojson});
      await _store.addCity(city, DateTime.now().millisecondsSinceEpoch);
      cities.add(city);
      cityCells[city.id] = counts[city.id] ?? 0;
      _updateCurrentCity(here);
      _events.add(GameEvent(
          EventKind.city, 'Nueva ciudad: ${city.name}', '+200 XP'));
      await _checkBadges(DateTime.now());
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo identificar la ciudad: $e');
    } finally {
      _cityBusy = false;
    }
  }

  // ----------------------------------------------------------------- badges

  Future<void> _checkBadges(DateTime now) async {
    final s = stats;
    for (final b in badges) {
      if (unlocked.containsKey(b.id) || !b.test(s)) continue;
      unlocked[b.id] = now.millisecondsSinceEpoch;
      await _store.addBadge(b.id, now.millisecondsSinceEpoch);
      _events.add(GameEvent(EventKind.badge, 'Insignia: ${b.name}',
          '${b.description}  (+100 XP)'));
    }
  }

  // ------------------------------------------------------------ backup/data

  Future<String> exportJson() async => jsonEncode(await _store.exportAll());

  Future<void> importJson(String text) async {
    final data = jsonDecode(text) as Map<String, dynamic>;
    await _store.importAll(data);
    await _loadAll();
    await _checkBadges(DateTime.now());
    notifyListeners();
  }

  Future<void> wipe() async {
    await stopTracking();
    await _store.wipe();
    distanceM = 0;
    nightCells = 0;
    earlyCells = 0;
    lastKnown = null;
    currentCity = null;
    _cityMisses.clear();
    await _loadAll();
    notifyListeners();
  }
}
