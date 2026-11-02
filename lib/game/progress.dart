import 'dart:math' as math;

import '../ui/format.dart';
import '../ui/icons.dart';

/// XP: 1 per explored cell, 60–150 per place (by category), 200 per city
/// and 100 per badge.
const xpPerCity = 200;
const xpPerBadge = 100;

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
    required this.km2,
    required this.distanceKm,
    required this.pois,
    required this.poisByCategory,
    required this.cities,
    required this.maxCityPercent,
    required this.maxCityName,
    required this.completedCities,
    required this.bestStreak,
    required this.currentStreak,
    required this.activeDays,
    required this.sessions,
    required this.nightCells,
    required this.earlyCells,
  });

  final int cells;
  final double km2;
  final double distanceKm;
  final int pois;
  final Map<String, int> poisByCategory;
  final int cities;
  final double maxCityPercent;
  final String? maxCityName;
  final int completedCities;
  final int bestStreak;
  final int currentStreak;
  final int activeDays;
  final int sessions;
  final int nightCells;
  final int earlyCells;

  int cat(String c) => poisByCategory[c] ?? 0;
}

/// A city counts as completed once this much of it is free of fog.
const completedCityPercent = 90.0;

/// Badge families: the shape tells the family, the glyph the achievement.
enum BadgeFamily {
  habitos('Hábitos', 'Círculo · constancia y horarios'),
  distancia('Distancia', 'Hexágono · kilómetros caminados'),
  territorio('Territorio', 'Rombo · niebla despejada y ciudades'),
  hallazgos('Hallazgos', 'Octágono · lugares misteriosos');

  const BadgeFamily(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

class Achievement {
  const Achievement(
    this.id,
    this.family,
    this.name,
    this.description, {
    this.text,
    this.unit,
    this.icon,
    required this.target,
    required this.value,
    required this.label,
  });

  final String id;
  final BadgeFamily family;
  final String name;
  final String description;

  /// Glyph drawn inside the badge: a number/text (with an optional small
  /// [unit] under it) or one of [BrIcons].
  final String? text;
  final String? unit;
  final String? icon;

  final double target;
  final double Function(Stats s) value;

  /// Progress shown under a locked badge, e.g. "23 / 25 lugares".
  final String Function(Stats s) label;

  bool test(Stats s) => value(s) >= target;
  double progress(Stats s) => (value(s) / target).clamp(0, 1).toDouble();
}

String _of(num v, num t, String unit) =>
    '${fmtInt(v.floor())} / ${fmtInt(t)}${unit.isEmpty ? '' : ' $unit'}';

String _cityPct(Stats s) => s.maxCityName == null
    ? 'Sin ciudades aún'
    : '${s.maxCityName} ${fmtPercent1(s.maxCityPercent)}';

final badges = <Achievement>[
  // Hábitos
  Achievement('h_first', BadgeFamily.habitos, 'Primeros pasos',
      'Completa tu primera sesión.',
      icon: BrIcons.steps,
      target: 1,
      value: (s) => s.sessions.toDouble(),
      label: (s) => _of(s.sessions, 1, 'sesión')),
  Achievement('h_days3', BadgeFamily.habitos, 'Explorador principiante',
      'Explora 3 días distintos.',
      icon: BrIcons.explore,
      target: 3,
      value: (s) => s.activeDays.toDouble(),
      label: (s) => _of(s.activeDays, 3, 'días')),
  Achievement('h_days20', BadgeFamily.habitos, 'Explorador constante',
      'Explora 20 días distintos.',
      icon: BrIcons.trail,
      target: 20,
      value: (s) => s.activeDays.toDouble(),
      label: (s) => _of(s.activeDays, 20, 'días')),
  Achievement('h_early', BadgeFamily.habitos, 'Madrugador',
      'Explora antes de las 8:00.',
      icon: BrIcons.sunrise,
      target: 20,
      value: (s) => s.earlyCells.toDouble(),
      label: (s) => 'Antes de las 8:00'),
  Achievement('h_night', BadgeFamily.habitos, 'Noctámbulo',
      'Explora después de las 22:00.',
      icon: BrIcons.moon,
      target: 20,
      value: (s) => s.nightCells.toDouble(),
      label: (s) => 'Después de las 22:00'),
  Achievement('h_streak7', BadgeFamily.habitos, 'Una semana explorando',
      '7 días seguidos.',
      text: '7',
      target: 7,
      value: (s) => s.bestStreak.toDouble(),
      label: (s) => _of(s.currentStreak, 7, 'días')),
  Achievement('h_streak30', BadgeFamily.habitos, 'Racha de 30 días',
      '30 días seguidos.',
      text: '30',
      target: 30,
      value: (s) => s.bestStreak.toDouble(),
      label: (s) => _of(s.currentStreak, 30, 'días')),
  Achievement('h_streak100', BadgeFamily.habitos, 'Racha de 100 días',
      '100 días seguidos.',
      text: '100',
      target: 100,
      value: (s) => s.bestStreak.toDouble(),
      label: (s) => _of(s.currentStreak, 100, 'días')),

  // Distancia
  for (final (km, name) in [
    (10, 'Primeros 10 km'),
    (50, '50 kilómetros'),
    (100, '100 kilómetros recorridos'),
    (500, '500 kilómetros'),
  ])
    Achievement('d_$km', BadgeFamily.distancia, name,
        'Camina $km km en total.',
        text: '$km',
        unit: 'KM',
        target: km.toDouble(),
        value: (s) => s.distanceKm,
        label: (s) => _of(s.distanceKm, km, 'km')),

  // Territorio
  Achievement('t_km1', BadgeFamily.territorio, 'Primer km²',
      'Despeja 1 km² de niebla.',
      text: '1',
      unit: 'KM²',
      target: 1,
      value: (s) => s.km2,
      label: (s) => '${fmtDec(s.km2)} / 1 km²'),
  Achievement('t_city2', BadgeFamily.territorio, 'Nueva ciudad',
      'Explora un segundo municipio.',
      icon: BrIcons.pin,
      target: 2,
      value: (s) => s.cities.toDouble(),
      label: (s) => _of(s.cities, 2, 'municipios')),
  Achievement('t_km10', BadgeFamily.territorio, '10 km² despejados',
      'Despeja 10 km² en total.',
      text: '10',
      unit: 'KM²',
      target: 10,
      value: (s) => s.km2,
      label: (s) => '${fmtDec(s.km2)} / 10 km²'),
  Achievement('t_city5', BadgeFamily.territorio, 'Viajero',
      'Explora 5 municipios.',
      icon: BrIcons.route,
      target: 5,
      value: (s) => s.cities.toDouble(),
      label: (s) => _of(s.cities, 5, 'municipios')),
  Achievement('t_pct10', BadgeFamily.territorio, '10 % de una ciudad',
      'Explora el 10 % de una zona.',
      text: '10%',
      target: 10,
      value: (s) => s.maxCityPercent,
      label: _cityPct),
  Achievement('t_pct25', BadgeFamily.territorio, '25 % de una ciudad',
      'Un cuarto de su territorio.',
      text: '25%',
      target: 25,
      value: (s) => s.maxCityPercent,
      label: _cityPct),
  Achievement('t_pct50', BadgeFamily.territorio, '50 % de una ciudad',
      'La mitad, sin niebla.',
      text: '50%',
      target: 50,
      value: (s) => s.maxCityPercent,
      label: _cityPct),
  Achievement('t_done1', BadgeFamily.territorio, 'Primera ciudad completada',
      'Recorre todas las calles de una ciudad.',
      icon: BrIcons.flag,
      target: completedCityPercent,
      value: (s) => s.maxCityPercent,
      label: (s) => 'Bloqueada'),
  Achievement('t_done3', BadgeFamily.territorio, 'Cartógrafo',
      'Completa 3 ciudades.',
      icon: BrIcons.map,
      target: 3,
      value: (s) => s.completedCities.toDouble(),
      label: (s) => _of(s.completedCities, 3, 'ciudades')),

  // Hallazgos
  Achievement('f_1', BadgeFamily.hallazgos, 'Primer hallazgo',
      'Descubre tu primer lugar.',
      text: '?',
      target: 1,
      value: (s) => s.pois.toDouble(),
      label: (s) => _of(s.pois, 1, 'lugar')),
  Achievement('f_parks', BadgeFamily.hallazgos, 'Amante de los parques',
      'Descubre 5 parques.',
      icon: BrIcons.park,
      target: 5,
      value: (s) => s.cat('parque').toDouble(),
      label: (s) => _of(s.cat('parque'), 5, 'parques')),
  Achievement('f_25', BadgeFamily.hallazgos, 'Coleccionista',
      'Descubre 25 lugares.',
      text: '25',
      target: 25,
      value: (s) => s.pois.toDouble(),
      label: (s) => _of(s.pois, 25, 'lugares')),
  Achievement('f_view', BadgeFamily.hallazgos, 'Vigía',
      'Descubre 5 miradores.',
      icon: BrIcons.viewpoint,
      target: 5,
      value: (s) => s.cat('mirador').toDouble(),
      label: (s) => _of(s.cat('mirador'), 5, 'miradores')),
  Achievement('f_art', BadgeFamily.hallazgos, 'Ojo para el arte',
      'Descubre 10 obras de arte.',
      icon: BrIcons.art,
      target: 10,
      value: (s) => s.cat('arte').toDouble(),
      label: (s) => _of(s.cat('arte'), 10, 'obras')),
  Achievement('f_hist', BadgeFamily.hallazgos, 'Historiador',
      'Descubre 10 sitios históricos.',
      icon: BrIcons.historic,
      target: 10,
      value: (s) => (s.cat('historico') + s.cat('monumento')).toDouble(),
      label: (s) =>
          _of(s.cat('historico') + s.cat('monumento'), 10, 'sitios')),
  Achievement('f_nat', BadgeFamily.hallazgos, 'Naturalista',
      'Descubre 5 lugares naturales.',
      icon: BrIcons.nature,
      target: 5,
      value: (s) => s.cat('naturaleza').toDouble(),
      label: (s) => _of(s.cat('naturaleza'), 5, 'lugares')),
];

Achievement? badgeById(String id) {
  for (final b in badges) {
    if (b.id == id) return b;
  }
  return null;
}

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

/// Consecutive active days ending today (or yesterday, if today has not
/// counted yet).
int currentStreak(Map<String, int> days, [DateTime? now]) {
  final today = now ?? DateTime.now();
  bool active(DateTime d) => (days[dayKey(d)] ?? 0) >= streakMinCells;
  var d = DateTime(today.year, today.month, today.day);
  if (!active(d)) d = d.subtract(const Duration(days: 1));
  var run = 0;
  while (active(d)) {
    run++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return run;
}

String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
