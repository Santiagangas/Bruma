import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../geo/cells.dart';
import '../models.dart';

/// Everything Bruma knows lives in this SQLite file on the phone.
class Store {
  late Database _db;

  Future<void> open() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'bruma.db'),
      version: 2,
      onUpgrade: (db, from, to) async {
        if (from < 2) await _createPoints(db, fromCells: true);
      },
      onCreate: (db, version) async {
        await _createPoints(db, fromCells: false);
        await db.execute(
            'CREATE TABLE cells (id INTEGER PRIMARY KEY, ts INTEGER NOT NULL)');
        await db.execute('CREATE TABLE pois (id TEXT PRIMARY KEY, '
            'name TEXT NOT NULL, category TEXT NOT NULL, lat REAL NOT NULL, '
            'lon REAL NOT NULL, discovered INTEGER)');
        await db.execute(
            'CREATE TABLE poi_tiles (id INTEGER PRIMARY KEY, ts INTEGER NOT NULL)');
        await db.execute('CREATE TABLE cities (id TEXT PRIMARY KEY, '
            'name TEXT NOT NULL, geojson TEXT NOT NULL, ts INTEGER NOT NULL)');
        await db.execute(
            'CREATE TABLE badges (id TEXT PRIMARY KEY, ts INTEGER NOT NULL)');
        await db.execute(
            'CREATE TABLE days (day TEXT PRIMARY KEY, cells INTEGER NOT NULL)');
        await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
  }

  /// Exact places you passed through; each clears a circle of fog.
  static Future<void> _createPoints(Database db,
      {required bool fromCells}) async {
    await db.execute('CREATE TABLE points (id INTEGER PRIMARY KEY '
        'AUTOINCREMENT, lat REAL NOT NULL, lon REAL NOT NULL)');
    if (fromCells) {
      final rows = await db.rawQuery('SELECT id FROM cells');
      final batch = db.batch();
      for (final r in rows) {
        final c = Cells.center(r['id'] as int);
        batch.insert('points', {'lat': c.latitude, 'lon': c.longitude});
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<(double, double)>> loadPoints() async {
    final rows = await _db.rawQuery('SELECT lat, lon FROM points');
    return [for (final r in rows) (r['lat'] as double, r['lon'] as double)];
  }

  Future<List<int>> loadCells() async {
    final rows = await _db.rawQuery('SELECT id FROM cells');
    return [for (final r in rows) r['id'] as int];
  }

  Future<List<Poi>> loadPois() async {
    final rows = await _db.query('pois');
    return [for (final r in rows) Poi.fromJson(r)];
  }

  Future<List<int>> loadPoiTiles() async {
    final rows = await _db.query('poi_tiles', columns: ['id']);
    return [for (final r in rows) r['id'] as int];
  }

  Future<List<City>> loadCities() async {
    final rows = await _db.query('cities', orderBy: 'ts');
    final out = <City>[];
    for (final r in rows) {
      try {
        out.add(City(
            id: r['id'] as String,
            name: r['name'] as String,
            geojson: r['geojson'] as String));
      } catch (_) {
        // Skip a boundary that no longer parses rather than failing startup.
      }
    }
    return out;
  }

  Future<Map<String, int>> loadBadges() async {
    final rows = await _db.query('badges');
    return {for (final r in rows) r['id'] as String: r['ts'] as int};
  }

  Future<Map<String, int>> loadDays() async {
    final rows = await _db.query('days');
    return {for (final r in rows) r['day'] as String: r['cells'] as int};
  }

  Future<Map<String, String>> loadMeta() async {
    final rows = await _db.query('meta');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  /// Saves newly explored cells plus the counters that change with them.
  Future<void> saveProgress({
    required Iterable<int> newCells,
    Iterable<(double, double)> newPoints = const [],
    required int ts,
    required String day,
    required Map<String, String> meta,
  }) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      var count = 0;
      for (final c in newCells) {
        batch.rawInsert(
            'INSERT OR IGNORE INTO cells (id, ts) VALUES (?, ?)', [c, ts]);
        count++;
      }
      if (count > 0) {
        batch.rawInsert(
            'INSERT OR IGNORE INTO days (day, cells) VALUES (?, 0)', [day]);
        batch.rawUpdate(
            'UPDATE days SET cells = cells + ? WHERE day = ?', [count, day]);
      }
      for (final (lat, lon) in newPoints) {
        batch.insert('points', {'lat': lat, 'lon': lon});
      }
      meta.forEach((k, v) {
        batch.insert('meta', {'key': k, 'value': v},
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> addPois(List<Poi> pois, int tile, int ts) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final poi in pois) {
        batch.insert('pois', poi.toJson(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      batch.insert('poi_tiles', {'id': tile, 'ts': ts},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }

  Future<void> markDiscovered(String poiId, int ts) => _db.update(
      'pois', {'discovered': ts},
      where: 'id = ? AND discovered IS NULL', whereArgs: [poiId]);

  Future<void> addCity(City city, int ts) => _db.insert(
      'cities',
      {'id': city.id, 'name': city.name, 'geojson': city.geojson, 'ts': ts},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> addBadge(String id, int ts) => _db.insert(
      'badges', {'id': id, 'ts': ts},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  /// Full dump used for the backup file.
  Future<Map<String, dynamic>> exportAll() async {
    final cities = await _db.query('cities');
    final cells = await _db.query('cells');
    return {
      'app': 'bruma',
      'version': 2,
      'points': [
        for (final (lat, lon) in await loadPoints()) [lat, lon]
      ],
      'exported': DateTime.now().toIso8601String(),
      'cells': [
        for (final r in cells) [r['id'], r['ts']]
      ],
      'pois': [for (final p in await loadPois()) p.toJson()],
      'cities': cities,
      'badges': await loadBadges(),
      'days': await loadDays(),
      'meta': await loadMeta(),
    };
  }

  /// Merges a backup into the current data (nothing already here is lost).
  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'bruma') {
      throw const FormatException('No es un respaldo de Bruma');
    }
    final current = await loadMeta();
    final pointCells = {
      for (final (lat, lon) in await loadPoints()) Cells.keyAt(lat, lon)
    };
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final c in data['cells'] as List<dynamic>) {
        final pair = c as List<dynamic>;
        batch.rawInsert('INSERT OR IGNORE INTO cells (id, ts) VALUES (?, ?)',
            [pair[0], pair[1]]);
      }
      // At most one point per cell, the same rule the app uses while
      // exploring, so importing the same backup twice adds nothing.
      void addPoint(double lat, double lon) {
        if (pointCells.add(Cells.keyAt(lat, lon))) {
          batch.insert('points', {'lat': lat, 'lon': lon});
        }
      }

      final points = data['points'] as List<dynamic>?;
      if (points != null) {
        for (final pt in points) {
          final pair = pt as List<dynamic>;
          addPoint((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
        }
      } else {
        // Old backup without points: use the centre of each cell.
        for (final c in data['cells'] as List<dynamic>) {
          final centre = Cells.center((c as List<dynamic>)[0] as int);
          addPoint(centre.latitude, centre.longitude);
        }
      }
      for (final pj in data['pois'] as List<dynamic>) {
        final poi = Poi.fromJson(pj as Map<String, dynamic>);
        batch.insert('pois', poi.toJson(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (poi.discovered != null) {
          batch.update('pois', {'discovered': poi.discovered},
              where: 'id = ? AND discovered IS NULL', whereArgs: [poi.id]);
        }
      }
      for (final cj in data['cities'] as List<dynamic>) {
        batch.insert('cities', Map<String, Object?>.from(cj as Map),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      (data['badges'] as Map<String, dynamic>).forEach((k, v) {
        batch.insert('badges', {'id': k, 'ts': v},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      });
      (data['days'] as Map<String, dynamic>).forEach((k, v) {
        batch.insert('days', {'day': k, 'cells': 0},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        batch.rawUpdate('UPDATE days SET cells = MAX(cells, ?) WHERE day = ?',
            [v, k]);
      });
      // Counters keep the larger value; the last position is only filled in
      // when this phone has none yet.
      (data['meta'] as Map<String, dynamic>).forEach((k, v) {
        final mine = double.tryParse(current[k] ?? '');
        final theirs = double.tryParse('$v');
        final take = mine == null ||
            (!k.startsWith('last_') && theirs != null && theirs > mine);
        if (take) {
          batch.insert('meta', {'key': k, 'value': '$v'},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> wipe() async {
    await _db.transaction((txn) async {
      for (final t in [
        'cells',
        'points',
        'pois',
        'poi_tiles',
        'cities',
        'badges',
        'days',
        'meta'
      ]) {
        await txn.delete(t);
      }
    });
  }
}
