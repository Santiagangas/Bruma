import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

import '../app_state.dart';
import '../models.dart';
import 'format.dart';
import 'icons.dart';
import 'place_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Descubrir": hidden places near you and the ones you have found.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.state, required this.onShowMap});
  final AppState state;

  /// Switches to the map tab (after asking it to focus somewhere).
  final VoidCallback onShowMap;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final s = widget.state;
    final all = s.pois.values.toList();
    final found = all.where((p) => p.discovered != null).toList()
      ..sort((a, b) => b.discovered!.compareTo(a.discovered!));
    final total = all.length;
    final city = s.currentCity ?? (s.cities.isEmpty ? null : s.cities.last);
    final me = s.position ?? s.lastKnown;

    // Nearest hidden places.
    const dist = Distance();
    final hidden = <(Poi, double, double)>[];
    if (me != null) {
      for (final p in all) {
        if (p.discovered != null) continue;
        if (_filter != null && p.category != _filter) continue;
        hidden.add((p, dist.as(LengthUnit.Meter, me, p.point), dist.bearing(me, p.point)));
      }
      hidden.sort((a, b) => a.$2.compareTo(b.$2));
    }
    final near = hidden.take(3).toList();
    final shown = _filter == null ? found : found.where((p) => p.category == _filter).toList();

    final counts = <String, int>{};
    for (final p in found) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final segments = total == 0 ? 0 : (found.length / total * 24).round();
    final top = MediaQuery.paddingOf(context).top;

    return Stack(children: [
      ListView(
        padding: EdgeInsets.fromLTRB(0, top + 32, 0, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (city != null) ...[
                      Text(city.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BrText.mono(11, tracking: .16)),
                      const SizedBox(height: 4),
                    ],
                    Text('Descubrir', style: BrText.display(40)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${found.length}'),
                      TextSpan(
                          text: ' / $total',
                          style: BrText.display(18, color: Br.textMuted)),
                    ]),
                    style: BrText.display(30, color: Br.gold),
                  ),
                  Text('lugares hallados', style: BrText.ui(12, color: Br.textMuted)),
                ]),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                for (var i = 0; i < 24; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < segments ? Br.gold : Br.surfaceHigh,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              BrChip('Todos', selected: _filter == null, onTap: () => setState(() => _filter = null)),
              for (final e in poiCategories.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: BrChip(
                    '${e.value.plural} · ${counts[e.key] ?? 0}',
                    selected: _filter == e.key,
                    onTap: () => setState(() => _filter = _filter == e.key ? null : e.key),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (found.isEmpty && near.isEmpty)
                _Empty(onShowMap: widget.onShowMap)
              else ...[
                _Header('Cerca de ti', 'Aún en la niebla'),
                const SizedBox(height: 10),
                if (near.isEmpty)
                  Text(
                      me == null
                          ? 'Inicia una exploración para ver qué esconde la niebla a tu alrededor.'
                          : 'No quedan lugares ocultos cerca. Camina hacia zonas nuevas.',
                      style: BrText.ui(13, color: Br.textMuted, height: 1.5)),
                for (var i = 0; i < near.length; i++) ...[
                  _HiddenRow(
                    poi: near[i].$1,
                    meters: near[i].$2,
                    bearing: near[i].$3,
                    highlight: i == 0 && near[i].$2 < 150,
                    onTap: () {
                      s.focusOn(near[i].$1.point);
                      widget.onShowMap();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                _Header('Tus hallazgos', 'Más recientes'),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  Text('Todavía no has encontrado lugares de este tipo.',
                      style: BrText.ui(13, color: Br.textMuted)),
                for (final p in shown) ...[
                  _FoundRow(
                    poi: p,
                    onTap: () => Navigator.of(context).push(PlaceScreen.route(s, p)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ]),
          ),
        ],
      ),
      const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade(height: 48)),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.note);
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: BrText.ui(17, weight: FontWeight.w700)),
          const Spacer(),
          Text(note, style: BrText.ui(12, color: Br.textMuted)),
        ],
      );
}

class _HiddenRow extends StatelessWidget {
  const _HiddenRow({
    required this.poi,
    required this.meters,
    required this.bearing,
    required this.highlight,
    required this.onTap,
  });
  final Poi poi;
  final double meters;
  final double bearing;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        radius: 18,
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        border: highlight ? Border.all(color: Br.gold.withValues(alpha: .35)) : null,
        child: Row(children: [
          const MysteryTile(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(poi.info.teaser, style: BrText.ui(15, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                Transform.rotate(
                  angle: bearing * math.pi / 180,
                  child: BrIcon(BrIcons.arrowUp,
                      size: 12, color: highlight ? Br.gold : Br.textMuted, stroke: 2.4),
                ),
                const SizedBox(width: 6),
                Text('${fmtMeters(meters, approx: meters < 150)} · ${compassName(bearing)}',
                    style: BrText.ui(12, color: Br.textMuted)),
              ]),
            ]),
          ),
          Text('+${poi.info.xp} XP', style: BrText.ui(12, weight: FontWeight.w800, color: Br.gold)),
        ]),
      );
}

class _FoundRow extends StatelessWidget {
  const _FoundRow({required this.poi, required this.onTap});
  final Poi poi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = DateTime.fromMillisecondsSinceEpoch(poi.discovered!);
    final fresh = DateTime.now().difference(when) < const Duration(hours: 24);
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        FoundTile(poi.info.icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(poi.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrText.ui(15, weight: FontWeight.w700)),
              ),
              if (fresh) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration:
                      BoxDecoration(color: Br.green, borderRadius: BorderRadius.circular(6)),
                  child: Text('NUEVO', style: BrText.ui(10, weight: FontWeight.w800, color: Br.bg)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text('${poi.info.label} · ${fmtWhen(when)}',
                style: BrText.ui(12, color: Br.textMuted)),
          ]),
        ),
        const BrIcon(BrIcons.chevron, size: 18, color: Br.textMuted, stroke: 2),
      ]),
    );
  }
}

/// "Aún no has encontrado nada".
class _Empty extends StatelessWidget {
  const _Empty({required this.onShowMap});
  final VoidCallback onShowMap;

  @override
  Widget build(BuildContext context) {
    Widget q(double size, bool main) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _Ring(main ? Br.gold : Br.goldDim, main ? 2 : 1.5),
            child: Center(
              child: Text('?',
                  style: BrText.display(main ? 36 : 26, color: main ? Br.gold : Br.goldDim)),
            ),
          ),
        );
    return Column(children: [
      const SizedBox(height: 60),
      Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 20), child: q(44, false)),
        const SizedBox(width: 14),
        q(60, true),
        const SizedBox(width: 14),
        Padding(padding: const EdgeInsets.only(top: 20), child: q(44, false)),
      ]),
      const SizedBox(height: 32),
      Text('Aún no has encontrado nada',
          textAlign: TextAlign.center, style: BrText.display(24, height: 1.15)),
      const SizedBox(height: 14),
      Text(
          'Los signos de interrogación del mapa esconden monumentos, miradores y rincones. Camina hasta uno para revelarlo.',
          textAlign: TextAlign.center,
          style: BrText.ui(13, color: Br.textMuted, height: 1.5)),
      const SizedBox(height: 40),
      SecondaryButton('Ver el más cercano', height: 48, onPressed: onShowMap),
    ]);
  }
}

class _Ring extends CustomPainter {
  _Ring(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) => dashedCircle(
      canvas,
      size.center(Offset.zero),
      size.width / 2 - width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
      dash: 3 * width,
      gap: 3 * width);

  @override
  bool shouldRepaint(_Ring old) => false;
}
