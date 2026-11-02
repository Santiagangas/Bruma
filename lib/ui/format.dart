import 'dart:math' as math;

/// Spanish number and date formatting used across the app
/// ("4,82 %", "3 420", "14 oct 2026").

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Thousands grouped with a space: 3420 -> "3 420".
String fmtInt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Decimal with comma: 2.84 -> "2,84".
String fmtDec(double v, [int digits = 2]) {
  final s = v.toStringAsFixed(digits);
  final parts = s.split('.');
  final whole = fmtInt(int.parse(parts[0]));
  final sign = v < 0 && !whole.startsWith('-') ? '-' : '';
  return parts.length == 1 ? '$sign$whole' : '$sign$whole,${parts[1]}';
}

/// Percentage that keeps tiny values readable:
/// 4.8213 -> "4,82 %", 0.00000056 -> "0,00000056 %".
String fmtPercent(double p) {
  if (p <= 0) return '0,00 %';
  if (p >= 0.01) return '${fmtDec(p, 2)} %';
  final digits = (-math.log(p) / math.ln10).floor() + 2;
  return '${fmtDec(p, digits.clamp(2, 20))} %';
}

/// Short percentage for compact labels: "4,8 %".
String fmtPercent1(double p) => '${fmtDec(p, 1)} %';

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String monthName(int month) => _monthsLong[month - 1];
String monthShort(int month) {
  final m = _months[month - 1];
  return m[0].toUpperCase() + m.substring(1);
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "hoy, 07:42" for today, otherwise "9 oct 2026".
String fmtWhen(DateTime d, {bool capital = false}) {
  final now = DateTime.now();
  if (sameDay(d, now)) return '${capital ? 'Hoy' : 'hoy'}, ${fmtTime(d)}';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) {
    return '${capital ? 'Ayer' : 'ayer'}, ${fmtTime(d)}';
  }
  return fmtDate(d);
}

/// "al amanecer", "por la tarde"… for a time of day.
String partOfDay(DateTime d) {
  final h = d.hour;
  if (h < 5) return 'de madrugada';
  if (h < 8) return 'al amanecer';
  if (h < 12) return 'por la mañana';
  if (h < 19) return 'por la tarde';
  return 'de noche';
}

/// Session clock "00:42:16".
String fmtClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// "41 h 20 min".
String fmtHours(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h ${d.inMinutes % 60} min';
}

/// "~120 m", "1,4 km".
String fmtMeters(double m, {bool approx = false}) {
  if (m < 1000) {
    final r = (m / 10).round() * 10;
    return '${approx ? '~' : ''}$r m';
  }
  return '${fmtDec(m / 1000, 1)} km';
}

/// Compass point for a bearing in degrees.
String compassName(double bearing) {
  const names = [
    'norte', 'noreste', 'este', 'sureste',
    'sur', 'suroeste', 'oeste', 'noroeste',
  ];
  final i = (((bearing % 360) + 22.5) ~/ 45) % 8;
  return names[i];
}

/// "4.6488° N · 74.0636° O".
String fmtCoords(double lat, double lon) =>
    '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'} · '
    '${lon.abs().toStringAsFixed(4)}° ${lon >= 0 ? 'E' : 'O'}';
