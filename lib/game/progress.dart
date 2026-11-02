import 'dart:math' as math;

import 'package:flutter/material.dart';

/// XP: 1 per explored cell, 50 per place, 200 per city, 100 per badge.
int levelFor(int xp) => math.sqrt(xp / 100).floor() + 1;
int xpForLevel(int level) => 100 * (level - 1) * (level - 1);

String titleFor(int level) {
  if (level < 3) return 'Aprendiz de la bruma';
  if (level < 6) return 'Caminante';
  if (level < 10) return 'Explorador';
  if (level < 15) return 'Rastreador';
  if (level < 20) return 'Cartógrafo';
  if (level < 30) return 'Pionero';
  return 'Leyenda de la niebla';
}

class Stats {
  Stats({
    required this.cells,
    required this.distanceKm,
    required this.pois,
    required this.poisByCategory,
    required this.cities,
    required this.maxCityPercent,
    required this.bestStreak,
    required this.bestDay,
    required this.nightCells,
    required this.earlyCells,
  });

  final int cells;
  final double distanceKm;
  final int pois;
  final Map<String, int> poisByCategory;
  final int cities;
  final double maxCityPercent;
  final int bestStreak;
  final int bestDay;
  final int nightCells;
  final int earlyCells;

  int cat(String c) => poisByCategory[c] ?? 0;
}

class Achievement {
  const Achievement(this.id, this.name, this.description, this.icon, this.test);
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool Function(Stats s) test;
}

final badges = <Achievement>[
  Achievement('cells_100', 'Primeros pasos', 'Despeja 100 celdas de niebla.',
      Icons.directions_walk, (s) => s.cells >= 100),
  Achievement('cells_1000', 'Abriendo camino', 'Despeja 1.000 celdas.',
      Icons.hiking, (s) => s.cells >= 1000),
  Achievement('cells_10000', 'Disipador', 'Despeja 10.000 celdas.',
      Icons.cloud_off, (s) => s.cells >= 10000),
  Achievement('cells_50000', 'Sol que todo lo ve', 'Despeja 50.000 celdas.',
      Icons.wb_sunny, (s) => s.cells >= 50000),
  Achievement('km_5', 'Piernas inquietas', 'Recorre 5 km explorando.',
      Icons.straighten, (s) => s.distanceKm >= 5),
  Achievement('km_50', 'Fondista', 'Recorre 50 km explorando.',
      Icons.route, (s) => s.distanceKm >= 50),
  Achievement('km_250', 'Peregrino', 'Recorre 250 km explorando.',
      Icons.signpost, (s) => s.distanceKm >= 250),
  Achievement('poi_1', 'Primer misterio', 'Descubre tu primer lugar.',
      Icons.help_center, (s) => s.pois >= 1),
  Achievement('poi_10', 'Coleccionista', 'Descubre 10 lugares.',
      Icons.collections_bookmark, (s) => s.pois >= 10),
  Achievement('poi_50', 'Guardián de secretos', 'Descubre 50 lugares.',
      Icons.auto_stories, (s) => s.pois >= 50),
  Achievement('cat_mirador', 'Ojo de águila', 'Descubre un mirador.',
      Icons.landscape, (s) => s.cat('mirador') >= 1),
  Achievement('cat_museo', 'Mente curiosa', 'Descubre un museo o galería.',
      Icons.museum, (s) => s.cat('museo') >= 1),
  Achievement('cat_monumento', 'Historiador', 'Descubre 5 sitios históricos.',
      Icons.account_balance, (s) => s.cat('monumento') >= 5),
  Achievement('cat_arte', 'Ojo artístico', 'Descubre 3 obras de arte.',
      Icons.palette, (s) => s.cat('arte') >= 3),
  Achievement('cat_parque', 'Pulmón verde', 'Descubre 5 parques.',
      Icons.park, (s) => s.cat('parque') >= 5),
  Achievement('cat_naturaleza', 'Alma salvaje', 'Descubre un lugar natural.',
      Icons.terrain, (s) => s.cat('naturaleza') >= 1),
  Achievement('city_1', 'Ciudadano', 'Explora tu primera ciudad.',
      Icons.location_city, (s) => s.cities >= 1),
  Achievement('city_3', 'Viajero', 'Explora 3 ciudades o municipios.',
      Icons.luggage, (s) => s.cities >= 3),
  Achievement('city_10', 'Trotamundos', 'Explora 10 ciudades o municipios.',
      Icons.public, (s) => s.cities >= 10),
  Achievement('pct_1', 'Conocedor', 'Explora el 1 % de una ciudad.',
      Icons.map, (s) => s.maxCityPercent >= 1),
  Achievement('pct_10', 'Vecino ilustre', 'Explora el 10 % de una ciudad.',
      Icons.explore, (s) => s.maxCityPercent >= 10),
  Achievement('pct_25', 'Cronista urbano', 'Explora el 25 % de una ciudad.',
      Icons.travel_explore, (s) => s.maxCityPercent >= 25),
  Achievement('streak_3', 'Constancia', 'Explora 3 días seguidos.',
      Icons.local_fire_department, (s) => s.bestStreak >= 3),
  Achievement('streak_7', 'Semana de bruma', 'Explora 7 días seguidos.',
      Icons.whatshot, (s) => s.bestStreak >= 7),
  Achievement('streak_30', 'Hábito de explorador', 'Explora 30 días seguidos.',
      Icons.emoji_events, (s) => s.bestStreak >= 30),
  Achievement('day_500', 'Gran jornada', 'Despeja 500 celdas en un solo día.',
      Icons.bolt, (s) => s.bestDay >= 500),
  Achievement('night', 'Noctámbulo', 'Explora entre la medianoche y las 5 a. m.',
      Icons.nightlight, (s) => s.nightCells >= 20),
  Achievement('early', 'Madrugador', 'Explora entre las 5 y las 7 a. m.',
      Icons.wb_twilight, (s) => s.earlyCells >= 20),
];

/// Days with at least this many new cells count towards a streak.
const streakMinCells = 10;

int bestStreak(Map<String, int> days) {
  final active = days.entries
      .where((e) => e.value >= streakMinCells)
      .map((e) => DateTime.parse('${e.key}T00:00:00Z'))
      .toList()
    ..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in active) {
    run = (prev != null && d.difference(prev).inDays == 1)
        ? run + 1
        : 1;
    best = math.max(best, run);
    prev = d;
  }
  return best;
}

String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// Formats a percentage so even tiny values stay readable:
/// 12.5 -> "12.50 %", 0.0000213 -> "0.000021 %".
String formatPercent(double p) {
  if (p <= 0) return '0 %';
  if (p >= 0.01) return '${p.toStringAsFixed(2)} %';
  final digits = (-math.log(p) / math.ln10).floor() + 2;
  return '${p.toStringAsFixed(digits.clamp(2, 20))} %';
}
