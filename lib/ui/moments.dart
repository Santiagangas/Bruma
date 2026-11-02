import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

import '../app_state.dart';
import '../game/progress.dart';
import '../models.dart';
import 'format.dart';
import 'icons.dart';
import 'place_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Fades in over whatever is behind (the map), as the design's "moments".
PageRoute<T> _overlayRoute<T>(WidgetBuilder builder, {bool opaque = false}) =>
    PageRouteBuilder<T>(
      opaque: opaque,
      barrierColor: null,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (context, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Br.curve), child: child),
    );

bool _reduceMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

// ------------------------------------------------------------ place found

class DiscoveryMoment extends StatefulWidget {
  const DiscoveryMoment({super.key, required this.state, required this.poi, required this.xp});
  final AppState state;
  final Poi poi;
  final int xp;

  static Route<void> route(AppState state, Poi poi, int xp) =>
      _overlayRoute((_) => DiscoveryMoment(state: state, poi: poi, xp: xp));

  @override
  State<DiscoveryMoment> createState() => _DiscoveryMomentState();
}

class _DiscoveryMomentState extends State<DiscoveryMoment>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _c.addListener(_haptics);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  bool _pulsed = false;
  void _haptics() {
    if (!_pulsed && _c.value >= .3) {
      _pulsed = true;
      HapticFeedback.mediumImpact();
      Future<void>.delayed(const Duration(milliseconds: 120), HapticFeedback.mediumImpact);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final poi = widget.poi;
    final city = s.cityAt(poi.lat, poi.lon);
    final (found, total) = city == null ? (s.discoveredCount, s.pois.length) : s.placesIn(city);
    final xp = s.xp;
    final lvl = levelFor(xp);
    final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
    final before = ((xp - widget.xp - from) / (to - from)).clamp(0.0, 1.0);
    final now = ((xp - from) / (to - from)).clamp(0.0, 1.0);
    final when = DateTime.fromMillisecondsSinceEpoch(poi.discovered ?? 0);
    return Scaffold(
      backgroundColor: Br.bg.withValues(alpha: .72),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final shake = t < .3 ? math.sin(t / .3 * 6 * math.pi) * 4 : 0.0;
          final seal = Curves.elasticOut.transform(((t - .3) / .23).clamp(0.0, 1.0));
          final card = Br.curve.transform(((t - .53) / .33).clamp(0.0, 1.0));
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: 70,
              height: 390,
              child: Opacity(
                opacity: seal.clamp(0, 1),
                child: CustomPaint(painter: _SealRings()),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 205,
              child: Center(
                child: t < .3
                    ? Transform.rotate(
                        angle: shake * math.pi / 180,
                        child: const MysteryMarker(near: true),
                      )
                    : Transform.scale(
                        scale: .6 + .4 * seal,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Br.gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0x40D6B36A), spreadRadius: 8),
                              BoxShadow(
                                  color: Color(0x80000000),
                                  blurRadius: 40,
                                  offset: Offset(0, 18)),
                            ],
                          ),
                          child: Center(
                              child: BrIcon(poi.info.icon, size: 56, color: Br.bg, stroke: 1.6)),
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              top: 420,
              child: Opacity(
                opacity: seal.clamp(0, 1),
                child: Column(children: [
                  Text('LUGAR DESCUBIERTO · Nº ${s.discoveryNumber(poi)}',
                      style: BrText.mono(11, color: Br.gold, tracking: .18)),
                  const SizedBox(height: 10),
                  Text(poi.name,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: BrText.display(42, height: 1.02)),
                  const SizedBox(height: 6),
                  Text(
                      city == null ? poi.info.label : '${poi.info.label} · ${city.name}',
                      style: BrText.ui(14, color: Br.textCalm)),
                ]),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 28 + MediaQuery.paddingOf(context).bottom,
              child: Transform.translate(
                offset: Offset(0, 60 * (1 - card)),
                child: Opacity(
                  opacity: card,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Br.bg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Br.gold.withValues(alpha: .25)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Text('+${fmtInt(widget.xp)} XP',
                            style: BrText.display(44, color: Br.gold)),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(fmtWhen(when, capital: true),
                              style: BrText.ui(12, color: Br.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                              city == null
                                  ? '$found de $total lugares'
                                  : '$found de $total en ${city.name}',
                              style: BrText.ui(12, color: Br.textMuted)),
                        ]),
                      ]),
                      const SizedBox(height: 16),
                      BrBar(value: before, extra: now - before, color: Br.gold),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('Nivel $lvl', style: BrText.mono(11)),
                        const Spacer(),
                        Text('${fmtInt(xp - from)} / ${fmtInt(to - from)}',
                            style: BrText.mono(11)),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: PrimaryButton('Ver ficha',
                              height: 52,
                              radius: 16,
                              fontSize: 15,
                              color: Br.gold,
                              onPressed: () => Navigator.of(context)
                                  .pushReplacement(PlaceScreen.route(s, poi))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SecondaryButton('Seguir explorando',
                              onPressed: () => Navigator.of(context).pop()),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _SealRings extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, 195);
    final p = Paint()..style = PaintingStyle.stroke;
    canvas.drawCircle(c, 92, p..color = Br.gold.withValues(alpha: .55)..strokeWidth = 1.5);
    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = Br.gold.withValues(alpha: .3);
    dashedCircle(canvas, c, 128, dashed, dash: 2, gap: 6);
    canvas.drawCircle(c, 168, p..color = Br.gold.withValues(alpha: .16)..strokeWidth = 1);
    final rays = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Br.gold.withValues(alpha: .8);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.sin(a), -math.cos(a));
      final inner = i.isEven ? 113.0 : 113.0 * 1.0;
      canvas.drawLine(c + d * inner, c + d * (inner + 16), rays);
    }
    void q(Offset o, double size, double opacity, double angle) {
      final tp = TextPainter(
        text: TextSpan(
            text: '?',
            style: BrText.display(size, color: Br.gold.withValues(alpha: opacity))),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx + o.dx, c.dy + o.dy);
      canvas.rotate(angle * math.pi / 180);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    q(const Offset(-107, -97), 22, .55, -24);
    q(const Offset(105, 99), 16, .4, 30);
    q(const Offset(113, -86), 12, .35, 0);
  }

  @override
  bool shouldRepaint(_SealRings old) => false;
}

// --------------------------------------------------------------- level up

class LevelMoment extends StatefulWidget {
  const LevelMoment({super.key, required this.state, required this.level});
  final AppState state;
  final int level;

  static Route<void> route(AppState state, int level) =>
      _overlayRoute((_) => LevelMoment(state: state, level: level), opaque: true);

  @override
  State<LevelMoment> createState() => _LevelMomentState();
}

class _LevelMomentState extends State<LevelMoment> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final b = s.xpBreakdown;
    final lvl = widget.level;
    final xp = s.xp;
    final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
    Widget row(String label, int v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Text(label, style: BrText.ui(14)),
            const Spacer(),
            Text('+${fmtInt(v)}', style: BrText.ui(14, weight: FontWeight.w700, color: Br.gold)),
          ]),
        );
    return Scaffold(
      backgroundColor: Br.bg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ring = Br.curve.transform((_c.value / .55).clamp(0.0, 1.0));
          final roll = Br.curve.transform(((_c.value - .55) / .4).clamp(0.0, 1.0));
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              height: 520,
              child: CustomPaint(painter: _LevelRings(ring)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 160,
              child: Column(children: [
                Text('NIVEL', style: BrText.mono(12, color: Br.gold, tracking: .2)),
                SizedBox(
                  height: 140,
                  child: ClipRect(
                    child: Stack(alignment: Alignment.center, children: [
                      Transform.translate(
                        offset: Offset(0, -110 * roll),
                        child: Opacity(
                          opacity: 1 - roll,
                          child: Text('${lvl - 1}',
                              style: BrText.display(132, spacing: -2.6)),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, 110 * (1 - roll)),
                        child: Text('$lvl', style: BrText.display(132, spacing: -2.6)),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: 438,
              child: Column(children: [
                Text(titleFor(lvl),
                    textAlign: TextAlign.center, style: BrText.display(36, height: 1.05)),
                const SizedBox(height: 8),
                Text('Tu nuevo título. La ciudad empieza a tener tu forma.',
                    textAlign: TextAlign.center,
                    style: BrText.ui(15, color: Br.textCalm, height: 1.5)),
              ]),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 28 + MediaQuery.paddingOf(context).bottom,
              child: Column(children: [
                SurfaceCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const MonoLabel('Cómo llegaste aquí', tracking: .14),
                    const SizedBox(height: 10),
                    row('Zonas despejadas', b.cells),
                    row('Lugares descubiertos', b.places),
                    row('Ciudades e insignias', b.extras),
                    Container(height: 1, color: Br.divider),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Nivel ${lvl + 1}', style: BrText.ui(12, color: Br.textMuted)),
                      const Spacer(),
                      Text('${fmtInt(xp - from)} / ${fmtInt(to - from)} XP',
                          style: BrText.mono(12)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                PrimaryButton('Seguir explorando', onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _LevelRings extends CustomPainter {
  _LevelRings(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate((size.width - 390) / 2, 0);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = Br.greenDeep;
    Path loop(List<double> pts) {
      final path = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i + 5 < pts.length; i += 6) {
        path.cubicTo(pts[i], pts[i + 1], pts[i + 2], pts[i + 3], pts[i + 4], pts[i + 5]);
      }
      return path..close();
    }

    canvas.drawPath(
        loop([195, 70, 280, 72, 330, 140, 326, 220, 322, 310, 260, 370, 190, 366, 110, 362, 60, 300, 64, 216, 68, 130, 120, 68, 195, 70]),
        p..color = Br.greenDeep.withValues(alpha: .35));
    canvas.drawPath(
        loop([195, 30, 306, 32, 372, 120, 366, 222, 360, 334, 278, 410, 188, 404, 88, 398, 22, 318, 26, 214, 30, 104, 100, 28, 195, 30]),
        p..color = Br.greenDeep.withValues(alpha: .22));
    canvas.drawPath(
        loop([195, -10, 330, -8, 412, 100, 406, 224, 400, 360, 300, 452, 186, 444, 66, 436, -18, 336, -14, 212, -10, 80, 80, -12, 195, -10]),
        p..color = Br.greenDeep.withValues(alpha: .12));
    const c = Offset(195, 218);
    canvas.drawCircle(c, 104, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Br.surfaceHigh);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: 104),
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = Br.gold);
  }

  @override
  bool shouldRepaint(_LevelRings old) => old.v != v;
}

// ------------------------------------------------------------------ badges

/// Bottom sheet for a badge: just unlocked ([fresh]) or opened from the
/// collection.
class BadgeSheet extends StatefulWidget {
  const BadgeSheet({
    super.key,
    required this.state,
    required this.badge,
    this.fresh = false,
    this.onCollection,
  });
  final AppState state;
  final Achievement badge;
  final bool fresh;
  final VoidCallback? onCollection;

  static Future<void> show(BuildContext context, AppState state, Achievement badge,
      {bool fresh = false, VoidCallback? onCollection}) {
    if (fresh) HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Br.bg.withValues(alpha: .6),
      backgroundColor: Br.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => BadgeSheet(
          state: state, badge: badge, fresh: fresh, onCollection: onCollection),
    );
  }

  @override
  State<BadgeSheet> createState() => _BadgeSheetState();
}

class _BadgeSheetState extends State<BadgeSheet> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.fresh || _reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward().then((_) {
          HapticFeedback.selectionClick();
          Future<void>.delayed(const Duration(milliseconds: 90), HapticFeedback.selectionClick);
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final b = widget.badge;
    final stats = s.stats;
    final at = s.unlocked[b.id];
    final earned = at != null;
    final family = badges.where((x) => x.family == b.family).toList();
    final got = family.where((x) => s.unlocked.containsKey(x.id)).length;
    Achievement? next;
    var bestP = -1.0;
    for (final x in family) {
      if (s.unlocked.containsKey(x.id) || x == b) continue;
      final p = x.progress(stats);
      if (p > bestP) {
        bestP = p;
        next = x;
      }
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          SizedBox(
            width: 200,
            height: 170,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                // Coin flip: dashed silhouette turns into the minted badge.
                final spin = Br.curve.transform((_c.value / .7).clamp(0.0, 1.0));
                final glow = ((_c.value - .7) / .3).clamp(0.0, 1.0);
                final angle = (1 - spin) * math.pi;
                final showGold = earned && angle < math.pi / 2;
                return Stack(alignment: Alignment.center, children: [
                  if (earned)
                    Opacity(
                      opacity: .7 * (widget.fresh ? glow : 1),
                      child: CustomPaint(size: const Size(200, 170), painter: _Rays()),
                    ),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateY(widget.fresh ? angle : 0),
                    child: BadgeArt(b, earned: widget.fresh ? showGold : earned, size: 132),
                  ),
                ]);
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
              widget.fresh
                  ? 'INSIGNIA DESBLOQUEADA'
                  : earned
                      ? 'OBTENIDA EL ${fmtDate(DateTime.fromMillisecondsSinceEpoch(at)).toUpperCase()}'
                      : 'INSIGNIA BLOQUEADA',
              style: BrText.mono(11, color: earned ? Br.gold : Br.textMuted, tracking: .18)),
          const SizedBox(height: 10),
          Text(b.name, textAlign: TextAlign.center, style: BrText.display(44)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(b.description,
                textAlign: TextAlign.center,
                style: BrText.ui(15, color: Br.textCalm, height: 1.5)),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Br.gold.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
              child: Text(earned ? '+$xpPerBadge XP' : b.label(stats),
                  style: BrText.ui(13, weight: FontWeight.w800, color: Br.gold)),
            ),
            const SizedBox(width: 10),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Br.surface, borderRadius: BorderRadius.circular(10)),
              child: Text('${b.family.label} · $got de ${family.length}',
                  style: BrText.ui(13, weight: FontWeight.w600, color: Br.textSoft)),
            ),
          ]),
          if (next != null) ...[
            const SizedBox(height: 14),
            SurfaceCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                BadgeArt(next, earned: false, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Siguiente en ${b.family.label}: ${next.name}',
                        style: BrText.ui(13, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(next.label(stats), style: BrText.ui(12, color: Br.textMuted)),
                  ]),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            if (widget.onCollection != null) ...[
              Expanded(
                child: SecondaryButton('Ver colección', onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCollection!();
                }),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: PrimaryButton(widget.fresh ? 'Seguir' : 'Cerrar',
                  height: 52,
                  radius: 16,
                  fontSize: 15,
                  onPressed: () => Navigator.of(context).pop()),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Rays extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Br.gold
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const lines = [
      [100.0, 6.0, 100.0, 18.0], [100.0, 152.0, 100.0, 164.0],
      [18.0, 85.0, 30.0, 85.0], [170.0, 85.0, 182.0, 85.0],
      [42.0, 27.0, 50.0, 35.0], [150.0, 135.0, 158.0, 143.0],
      [158.0, 27.0, 150.0, 35.0], [50.0, 135.0, 42.0, 143.0],
    ];
    for (final l in lines) {
      canvas.drawLine(Offset(l[0], l[1]), Offset(l[2], l[3]), p);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => false;
}

// ---------------------------------------------------------------- new city

class CityMoment extends StatefulWidget {
  const CityMoment({super.key, required this.state, required this.city});
  final AppState state;
  final City city;

  static Route<void> route(AppState state, City city) =>
      _overlayRoute((_) => CityMoment(state: state, city: city));

  @override
  State<CityMoment> createState() => _CityMomentState();
}

class _CityMomentState extends State<CityMoment> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future<void>.delayed(const Duration(milliseconds: 140), HapticFeedback.mediumImpact);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
    _auto = Timer(const Duration(seconds: 6), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = widget.city;
    final n = s.cities.indexOf(c) + 1;
    final (found, total) = s.placesIn(c);
    double? nearest;
    final me = s.position;
    if (me != null) {
      const d = Distance();
      for (final p in s.pois.values) {
        if (p.discovered != null || !c.shape.contains(p.lat, p.lon)) continue;
        final m = d.as(LengthUnit.Meter, me, p.point);
        if (nearest == null || m < nearest) nearest = m;
      }
    }
    final left = total - found;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Br.curve.transform(_c.value);
          return Stack(children: [
            Positioned(
              left: 24,
              right: 24,
              top: 236,
              child: Opacity(
                opacity: t,
                child: Column(children: [
                  Text('NUEVO TERRITORIO',
                      style: BrText.mono(12, color: Br.textOnFog, tracking: .32)),
                  const SizedBox(height: 6),
                  Text(c.name,
                      textAlign: TextAlign.center,
                      style: BrText.display(72, height: .95, spacing: 72 * (.01 + .3 * (1 - t)))),
                  const SizedBox(height: 6),
                  Text(n <= 1 ? 'Tu primer municipio' : 'Tu $n.º municipio',
                      style: BrText.ui(14, color: Br.textSoft)),
                  const SizedBox(height: 14),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Br.bg, borderRadius: BorderRadius.circular(10)),
                    child: Text('+$xpPerCity XP · Nueva ciudad',
                        style: BrText.ui(12.5, weight: FontWeight.w700, color: Br.gold)),
                  ),
                ]),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 28 + MediaQuery.paddingOf(context).bottom,
              child: Opacity(
                opacity: t,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(color: Br.bg, borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CustomPaint(
                        painter: _DashedCircle(),
                        child: Center(child: Text('?', style: BrText.display(26, color: Br.gold))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                            left == 0
                                ? 'Buscando lugares por descubrir…'
                                : left == 1
                                    ? '1 lugar por descubrir'
                                    : '$left lugares por descubrir',
                            style: BrText.ui(15, weight: FontWeight.w700)),
                        if (nearest != null) ...[
                          const SizedBox(height: 2),
                          Text('El más cercano, a ${fmtMeters(nearest)}',
                              style: BrText.ui(12, color: Br.textMuted)),
                        ],
                      ]),
                    ),
                    SecondaryButton('Explorar',
                        height: 44,
                        radius: 14,
                        fontSize: 14,
                        expand: false,
                        onPressed: () => Navigator.of(context).pop()),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => dashedCircle(
      canvas,
      size.center(Offset.zero),
      size.width / 2 - .75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Br.gold,
      dash: 4.5,
      gap: 4.5);

  @override
  bool shouldRepaint(_DashedCircle old) => false;
}

// --------------------------------------------------------------- GPS error

/// "La niebla no puede moverse sin ti": location off or permission removed.
class GpsErrorScreen extends StatelessWidget {
  const GpsErrorScreen({super.key, required this.message});
  final String message;

  static Route<void> route(String message) =>
      MaterialPageRoute(builder: (_) => GpsErrorScreen(message: message));

  @override
  Widget build(BuildContext context) {
    final serviceOff = message.contains('GPS');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft, child: BackArrow()),
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: Br.surface, shape: BoxShape.circle),
              child: Center(
                child: Stack(alignment: Alignment.center, children: [
                  const BrIcon(BrIcons.locateOff, size: 40, color: Br.textMuted, stroke: 1.6),
                  BrIcon('<path d="M4 4l16 16"/>', size: 40, color: Br.danger, stroke: 1.6),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text('La niebla no puede moverse sin ti',
                textAlign: TextAlign.center, style: BrText.display(26, height: 1.1)),
            const SizedBox(height: 14),
            Text(
                serviceOff
                    ? 'La ubicación del teléfono está desactivada. Tu mapa sigue a salvo.'
                    : 'El permiso de ubicación fue retirado o no se ha concedido. Tu mapa sigue a salvo.',
                textAlign: TextAlign.center,
                style: BrText.ui(13, color: Br.textMuted, height: 1.5)),
            const Spacer(),
            PrimaryButton('Activar ubicación',
                height: 48,
                radius: 16,
                fontSize: 15,
                onPressed: () async {
                  if (serviceOff) {
                    await Geolocator.openLocationSettings();
                  } else {
                    final p = await Geolocator.requestPermission();
                    if (p == LocationPermission.deniedForever ||
                        p == LocationPermission.denied) {
                      await Geolocator.openAppSettings();
                    }
                  }
                  if (context.mounted) Navigator.of(context).maybePop();
                }),
            const SizedBox(height: 14),
            Text('Abre Ajustes de Android', style: BrText.ui(12, color: Br.textMuted)),
          ]),
        ),
      ),
    );
  }
}
