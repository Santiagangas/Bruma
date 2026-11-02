import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../game/progress.dart';
import '../settings.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Period { dias, semanas, meses }

/// "Estadísticas": distance walked per day, week or month, and totals.
class StatsScreen extends StatefulWidget {
  const StatsScreen(
      {super.key, required this.state, required this.settings, required this.onBack});
  final AppState state;
  final Settings settings;
  final VoidCallback onBack;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _Bar {
  _Bar(this.label, this.km);
  final String label;
  final double km;
}

class _StatsScreenState extends State<StatsScreen> {
  _Period _p = _Period.dias;

  double _km(DateTime d) => (widget.state.dayMeters[dayKey(d)] ?? 0) / 1000;

  (List<_Bar>, String) _data() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_p) {
      case _Period.dias:
        const letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
        return (
          [
            for (var i = 6; i >= 0; i--)
              () {
                final d = DateTime(today.year, today.month, today.day - i);
                return _Bar(letters[d.weekday - 1], _km(d));
              }()
          ],
          'Últimos 7 días · hoy en curso'
        );
      case _Period.semanas:
        final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
        return (
          [
            for (var w = 11; w >= 0; w--)
              () {
                final start = DateTime(monday.year, monday.month, monday.day - 7 * w);
                var km = 0.0;
                for (var i = 0; i < 7; i++) {
                  km += _km(DateTime(start.year, start.month, start.day + i));
                }
                return _Bar(w == 0 ? 'Esta' : '', km);
              }()
          ],
          'Últimas 12 semanas'
        );
      case _Period.meses:
        final first = widget.state.firstDay ?? today;
        var m = DateTime(first.year, first.month);
        final last = DateTime(today.year, today.month);
        // At most the last 12 months.
        final months = (last.year - m.year) * 12 + last.month - m.month + 1;
        if (months > 12) m = DateTime(last.year, last.month - 11);
        final bars = <_Bar>[];
        while (!m.isAfter(last)) {
          var km = 0.0;
          widget.state.dayMeters.forEach((k, v) {
            final d = DateTime.tryParse(k);
            if (d != null && d.year == m.year && d.month == m.month) km += v / 1000;
          });
          bars.add(_Bar(monthShort(m.month), km));
          m = DateTime(m.year, m.month + 1);
        }
        return (bars, 'Desde que empezaste · ${monthName(first.month)} ${first.year}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, widget.settings]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final s = widget.state;
    final st = s.stats;
    final unit = widget.settings.miles ? 'mi' : 'km';
    double conv(double km) => widget.settings.distance(km).$1;
    final (bars, caption) = _data();
    final total = bars.fold<double>(0, (a, b) => a + b.km);
    final maxKm = bars.fold<double>(0, (a, b) => math.max(a, b.km));
    final top = MediaQuery.paddingOf(context).top;

    Widget tile(String label, Widget value) => SurfaceCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: BrText.ui(11.5, color: Br.textMuted)),
            DefaultTextStyle(style: BrText.display(26, height: 1.1), child: value),
          ]),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 120),
      children: [
        Row(children: [
          Transform.translate(offset: const Offset(-10, 0), child: BackArrow(onTap: widget.onBack)),
          Text('Estadísticas', style: BrText.display(36)),
        ]),
        const SizedBox(height: 16),
        Segmented<_Period>(
          options: const [
            (_Period.dias, 'Días'),
            (_Period.semanas, 'Semanas'),
            (_Period.meses, 'Meses'),
          ],
          value: _p,
          onChanged: (p) => setState(() => _p = p),
        ),
        const SizedBox(height: 16),
        Figure(fmtDec(conv(total), 1), unit: unit, size: 52, unitSize: 16, height: 1),
        const SizedBox(height: 2),
        Text(caption, style: BrText.ui(13, color: Br.textMuted)),
        const SizedBox(height: 16),
        Semantics(
          label: 'Gráfico de distancia por periodo',
          child: Container(
            height: 168,
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Br.surfaceHigh))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (bars[i].km > 0)
                      Text(fmtDec(conv(bars[i].km), 1),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: BrText.mono(9.5)),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                          end: bars[i].km == 0
                              ? 4
                              : math.max(6, bars[i].km / maxKm * 130).toDouble()),
                      duration: const Duration(milliseconds: 500),
                      curve: Br.curve,
                      builder: (_, h, _) => Container(
                        height: h,
                        constraints: const BoxConstraints(maxWidth: 26),
                        decoration: BoxDecoration(
                          color: i == bars.length - 1
                              ? Br.green
                              : bars[i].km == 0
                                  ? Br.surfaceHigh
                                  : Br.greenDeep,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6), bottom: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Text(bars[i].label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: BrText.ui(11, color: Br.textMuted)),
            ),
          ],
        ]),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.55,
          children: [
            tile(widget.settings.miles ? 'Millas' : 'Kilómetros',
                Text(fmtDec(conv(st.distanceKm), 1))),
            tile('Área explorada', Text('${fmtDec(st.km2)} km²')),
            tile('Tiempo caminando',
                Text(fmtHours(Duration(seconds: s.walkSeconds.round())))),
            tile('Días activos', Text('${s.days.length}')),
            tile(
                'Racha actual · mejor',
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${st.currentStreak} '),
                  TextSpan(
                      text: '· ${st.bestStreak} días',
                      style: const TextStyle(color: Br.textMuted)),
                ]))),
            tile(
                'Lugares · ciudades',
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${st.pois}', style: const TextStyle(color: Br.gold)),
                  TextSpan(text: ' · ${st.cities}'),
                ]))),
          ],
        ),
      ],
    );
  }
}
