import 'package:flutter/material.dart';

import '../app_state.dart';
import '../game/progress.dart';
import '../settings.dart';
import 'format.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Progreso": level, explored share of your city and of the world, and
/// figures per city.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen(
      {super.key, required this.state, required this.settings, required this.onOpenStats});
  final AppState state;
  final Settings settings;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state, settings]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final s = state;
    final xp = s.xp;
    final lvl = levelFor(xp);
    final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
    final st = s.stats;
    final cities = [...s.cities]..sort((a, b) => s.cityPercent(b).compareTo(s.cityPercent(a)));
    final main = s.currentCity ?? (cities.isEmpty ? null : cities.first);
    final (dist, unit) = settings.distance(st.distanceKm);
    final top = MediaQuery.paddingOf(context).top;

    Widget cell(String v, String label, {Color color = Br.text}) => Container(
          color: Br.bg,
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BrText.display(26, height: 1.05, color: color)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, style: BrText.ui(11.5, color: Br.textMuted)),
            ),
          ]),
        );

    return Stack(children: [
      ListView(
        padding: EdgeInsets.fromLTRB(20, top + 28, 20, 120),
        children: [
          Row(children: [
            Text('Progreso', style: BrText.display(40)),
            const Spacer(),
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Br.outline)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpenStats,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    const BrIcon(BrIcons.stats, size: 16, color: Br.green, stroke: 2),
                    const SizedBox(width: 6),
                    Text('Estadísticas',
                        style: BrText.ui(13, weight: FontWeight.w700, color: Br.green)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Level.
          SurfaceCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(children: [
              Column(children: [
                Text('NIVEL', style: BrText.mono(10, tracking: .14)),
                Text('$lvl', style: BrText.display(64)),
              ]),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titleFor(lvl), style: BrText.ui(15, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  BrBar(value: (xp - from) / (to - from)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('${fmtInt(xp - from)} / ${fmtInt(to - from)} XP',
                        style: BrText.mono(12, color: Br.textSoft)),
                    const Spacer(),
                    Text('${fmtInt(to - xp)} para el ${lvl + 1}',
                        style: BrText.ui(12, color: Br.textMuted)),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Shares.
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: SurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(main == null ? 'Municipio' : 'Municipio · ${main.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BrText.ui(12, color: Br.textMuted)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(main == null ? '—' : fmtPercent(s.cityPercent(main)),
                          style: BrText.display(40, color: Br.green)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        main == null
                            ? 'Explora para identificarlo'
                            : '${fmtDec(s.cityKm2(main))} km² explorados',
                        style: BrText.ui(11.5, color: Br.textMuted)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SurfaceCard(
                  color: settingsFog(settings),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('El mundo', style: BrText.ui(12, color: Br.textOnFog)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(fmtPercent(s.worldPercent),
                          style: BrText.display(25, height: 1.25)),
                    ),
                    const SizedBox(height: 4),
                    Text('Queda mucha niebla.',
                        style: BrText.ui(11.5, color: Br.textOnFog, style: FontStyle.italic)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Figures.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: const Color(0x12F0F1E9),
              child: Column(children: [
                Row(children: [
                  Expanded(child: cell(fmtDec(st.km2), 'km² descubiertos')),
                  const SizedBox(width: 1),
                  Expanded(child: cell(fmtDec(dist, 1), '$unit recorridos')),
                  const SizedBox(width: 1),
                  Expanded(child: cell('${st.pois}', 'lugares', color: Br.gold)),
                ]),
                const SizedBox(height: 1),
                Row(children: [
                  Expanded(child: cell('${s.days.length}', 'días explorados')),
                  const SizedBox(width: 1),
                  Expanded(child: cell('${st.bestStreak}', 'mejor racha')),
                  const SizedBox(width: 1),
                  Expanded(child: cell('${st.currentStreak}', 'racha actual')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 18),

          // Cities.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Por ciudad', style: BrText.ui(17, weight: FontWeight.w700)),
              const Spacer(),
              Text(cities.length == 1 ? '1 municipio' : '${cities.length} municipios',
                  style: BrText.ui(12, color: Br.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          if (cities.isEmpty)
            Text('Explora para identificar tu primera ciudad.',
                style: BrText.ui(13, color: Br.textMuted)),
          for (final c in cities)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Opacity(
                opacity: s.cityPercent(c) < 0.05 ? .6 : 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BrText.ui(15, weight: FontWeight.w700)),
                      ),
                      Text(fmtPercent(s.cityPercent(c)), style: BrText.display(20)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BrBar(value: s.cityPercent(c) / 100, height: 4, color: Br.green, minWidth: 8),
                  if (s.cityPercent(c) >= 0.05) ...[
                    const SizedBox(height: 6),
                    Text(
                        '${fmtDec(s.cityKm2(c))} km² explorados de ~${fmtInt(c.area / 1e6)} km²',
                        style: BrText.ui(12, color: Br.textMuted)),
                  ],
                ]),
              ),
            ),
        ],
      ),
      const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade()),
    ]);
  }
}

Color settingsFog(Settings s) => s.fog.color;
