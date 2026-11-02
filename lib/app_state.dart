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
  FogPoint(double lat, double lon, {this.born})
      : x = Cells.lonToX(lon),
        y = Cells.latToY(lat),
        r = Cells.revealRadius / Cells.cellSizeMeters(lat);
  final double x;
  final double y;
  final double r;

  /// When it was revealed during this run (null for loaded points); used to
  /// animate the circle opening.
  final DateTime? born;
}

enum EventKind { badge, place, level, city }

class GameEvent {
  GameEvent(this.kind, {this.poi, this.badge, this.city, this.level, this.xp = 0});
  final EventKind kind;
  final Poi? poi;
  final Achievement? badge;
  final City? city;
  final int? level;
  final int xp;
}

/// Where the XP total comes from (shown on the level-up screen).
class XpBreakdown {
  const XpBreakdown(this.cells, this.places, this.extras);
  final int cells;
  final int places;

  /// Cities and badges.
  final int extras;
  int get total => cells + places + extras;
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
  int sessions = 0;
  double walkSeconds = 0;

  /// Metres walked per day ("yyyy-mm-dd").
  final Map<String, double> dayMeters = {};

  /// Your notes about discovered places, by place id.
  final Map<String, String> notes = {};

  bool ready = false;
  bool tracking = false;
  LatLng? position;
  LatLng? lastKnown;
  double? accuracy;
  City? currentCity;

  /// Direction of travel in degrees, when moving.
  double? heading;
  bool moving = false;

  // Current exploration session.
  DateTime? sessionStart;
  double sessionMeters = 0;
  int sessionCells = 0;
  int sessionXpStart = 0;

  /// XP gained by the latest fix (for the "+4 XP" bubble); bumps each time.
  final ValueNotifier<(int, int)> gain = ValueNotifier((0, 0));

  /// Asks the map to fly to a point (from Descubrir or a place card). The
  /// number changes on every request.
  final ValueNotifier<(int, LatLng)?> focus = ValueNotifier(null);
  void focusOn(LatLng p) => focus.value = ((focus.value?.$1 ?? 0) + 1, p);

  /// Last time a map tile failed to load (no connection).
  final ValueNotifier<DateTime?> tileError = ValueNotifier(null);

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
    // Award badges already earned with existing progress, without a
    // celebration for each one.
    await _checkBadges(DateTime.now(), silent: true);
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
    dayMeters.clear();
    notes.clear();

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
    // Badges from older versions of the app no longer exist.
    unlocked.removeWhere((id, _) => badgeById(id) == null);
    days.addAll(await _store.loadDays());

    final meta = await _store.loadMeta();
    distanceM = double.tryParse(meta['distance_m'] ?? '') ?? 0;
    nightCells = int.tryParse(meta['night_cells'] ?? '') ?? 0;
    earlyCells = int.tryParse(meta['early_cells'] ?? '') ?? 0;
    sessions = int.tryParse(meta['sessions'] ?? '') ?? 0;
    walkSeconds = double.tryParse(meta['walk_s'] ?? '') ?? 0;
    meta.forEach((k, v) {
      if (k.startsWith('dist:')) {
        dayMeters[k.substring(5)] = double.tryParse(v) ?? 0;
      } else if (k.startsWith('note:') && v.isNotEmpty) {
        notes[k.substring(5)] = v;
      }
    });
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
  bool _addPoint(double lat, double lon, {DateTime? born}) {
    final key = Cells.keyAt(lat, lon);
    if (!_pointCells.add(key)) return false;
    (fogBuckets[Cells.bucketOf(key)] ??= []).add(FogPoint(lat, lon, born: born));
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

  XpBreakdown get xpBreakdown {
    var places = 0;
    for (final p in pois.values) {
      if (p.discovered != null) places += p.info.xp;
    }
    return XpBreakdown(cells.length, places,
        xpPerCity * cities.length + xpPerBadge * unlocked.length);
  }

  int get xp => xpBreakdown.total;

  int get level => levelFor(xp);

  double get _cellArea => Cells.cellAreaM2((position ?? lastKnown)?.latitude ?? 0);

  double get exploredKm2 => cells.length * _cellArea / 1e6;

  double get worldPercent => exploredKm2 / worldLandKm2 * 100;

  double cityPercent(City c) => c.percent(cityCells[c.id] ?? 0);

  double cityKm2(City c) =>
      (cityCells[c.id] ?? 0) * Cells.cellAreaM2(c.shape.centerLat) / 1e6;

  /// Places inside [c]: (discovered, total).
  (int, int) placesIn(City c) {
    var found = 0, total = 0;
    for (final p in pois.values) {
      if (!c.shape.contains(p.lat, p.lon)) continue;
      total++;
      if (p.discovered != null) found++;
    }
    return (found, total);
  }

  /// Order in which [poi] was discovered (1 = first).
  int discoveryNumber(Poi poi) {
    final at = poi.discovered;
    if (at == null) return 0;
    return pois.values
        .where((p) => p.discovered != null && p.discovered! <= at)
        .length;
  }

  /// The city containing a point, among those already known.
  City? cityAt(double lat, double lon) {
    for (final c in cities) {
      if (c.shape.contains(lat, lon)) return c;
    }
    return null;
  }

  /// First day with exploration, if any.
  DateTime? get firstDay {
    if (days.isEmpty) return null;
    final first = days.keys.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    return DateTime.tryParse(first);
  }

  Stats get stats {
    final byCat = <String, int>{};
    for (final p in pois.values) {
      if (p.discovered != null) {
        byCat[p.category] = (byCat[p.category] ?? 0) + 1;
      }
    }
    var maxPct = 0.0;
    String? maxName;
    var completed = 0;
    for (final c in cities) {
      final pct = cityPercent(c);
      if (pct >= completedCityPercent) completed++;
      if (maxName == null || pct > maxPct) {
        maxPct = pct;
        maxName = c.name;
      }
    }
    return Stats(
      cells: cells.length,
      km2: exploredKm2,
      distanceKm: distanceM / 1000,
      pois: discoveredCount,
      poisByCategory: byCat,
      cities: cities.length,
      maxCityPercent: maxPct,
      maxCityName: maxName,
      completedCities: completed,
      bestStreak: bestStreak(days),
      currentStreak: currentStreak(days),
      activeDays: days.values.where((v) => v >= streakMinCells).length,
      sessions: sessions,
      nightCells: nightCells,
      earlyCells: earlyCells,
    );
  }

  /// Locked badge closest to being unlocked.
  Achievement? get nextBadge {
    final s = stats;
    Achievement? best;
    var bestP = -1.0;
    for (final b in badges) {
      if (unlocked.containsKey(b.id)) continue;
      final p = b.progress(s);
      if (p > bestP) {
        bestP = p;
        best = b;
      }
    }
    return best;
  }

  Future<void> setNote(Poi poi, String text) async {
    final t = text.trim();
    if (t.isEmpty) {
      notes.remove(poi.id);
    } else {
      notes[poi.id] = t;
    }
    await _store.saveProgress(
        newCells: const [], ts: 0, day: '', meta: {'note:${poi.id}': t});
    notifyListeners();
  }

  /// Size of the progress database, in bytes.
  Future<int> databaseBytes() => _store.sizeBytes();

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

  /// Starts an exploration session. With [background] the phone keeps
  /// exploring with the screen off (shows a fixed notification).
  Future<String?> startTracking({bool background = true}) async {
    if (tracking) return null;
    final error = await _ensurePermission();
    if (error != null) return error;
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: background
          ? const ForegroundNotificationConfig(
              notificationTitle: 'Bruma está explorando',
              notificationText: 'Despejando la niebla a tu paso',
              notificationChannelName: 'Exploración',
              enableWakeLock: true,
              setOngoing: true,
            )
          : null,
    );
    sessionStart = DateTime.now();
    sessionMeters = 0;
    sessionCells = 0;
    sessionXpStart = xp;
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
    if (!tracking) return;
    tracking = false;
    sessionStart = null;
    moving = false;
    sessions++;
    await _saveMeta();
    await _checkBadges(DateTime.now());
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
    moving = p.speed > 0.5;
    if (moving && p.heading >= 0) heading = p.heading;
    // Fixes this imprecise would reveal places you never went.
    if (p.accuracy > 40) {
      notifyListeners();
      return;
    }

    final levelBefore = level;
    final xpBefore = xp;
    final now = DateTime.now();
    final fresh = <int>{};
    final freshPoints = <(double, double)>[];
    void reveal(LatLng q) {
      if (_addPoint(q.latitude, q.longitude, born: now)) {
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
        sessionMeters += d;
        final day = dayKey(now);
        dayMeters[day] = (dayMeters[day] ?? 0) + d;
        if (d > 1) walkSeconds += dt;
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
      sessionCells += fresh.length;
      if (now.hour >= 22 || now.hour < 4) nightCells += fresh.length;
      if (now.hour >= 4 && now.hour < 8) earlyCells += fresh.length;
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
      _events.add(GameEvent(EventKind.level, level: levelAfter));
    }
    final gained = xp - xpBefore;
    if (gained > 0) gain.value = (gain.value.$1 + 1, gained);
    notifyListeners();
  }

  Map<String, String> _metaValues() {
    final today = dayKey(DateTime.now());
    return {
        'distance_m': distanceM.toStringAsFixed(1),
        'night_cells': '$nightCells',
        'early_cells': '$earlyCells',
        'sessions': '$sessions',
        'walk_s': walkSeconds.toStringAsFixed(0),
        if (dayMeters[today] != null)
          'dist:$today': dayMeters[today]!.toStringAsFixed(1),
        if (lastKnown != null) 'last_lat': '${lastKnown!.latitude}',
        if (lastKnown != null) 'last_lon': '${lastKnown!.longitude}',
      };
  }

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
        _events.add(GameEvent(EventKind.place, poi: poi, xp: poi.info.xp));
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
      _events.add(GameEvent(EventKind.city, city: city, xp: xpPerCity));
      await _checkBadges(DateTime.now());
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo identificar la ciudad: $e');
    } finally {
      _cityBusy = false;
    }
  }

  // ----------------------------------------------------------------- badges

  Future<void> _checkBadges(DateTime now, {bool silent = false}) async {
    final s = stats;
    for (final b in badges) {
      if (unlocked.containsKey(b.id) || !b.test(s)) continue;
      unlocked[b.id] = now.millisecondsSinceEpoch;
      await _store.addBadge(b.id, now.millisecondsSinceEpoch);
      if (!silent) _events.add(GameEvent(EventKind.badge, badge: b, xp: xpPerBadge));
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
    sessions = 0;
    walkSeconds = 0;
    lastKnown = null;
    currentCity = null;
    _cityMisses.clear();
    await _loadAll();
    notifyListeners();
  }
}
