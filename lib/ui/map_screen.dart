import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

import '../app_state.dart';
import '../game/progress.dart';
import '../models.dart';
import '../settings.dart';
import 'appearance_screen.dart';
import 'fog_layer.dart';
import 'format.dart';
import 'icons.dart';
import 'moments.dart';
import 'place_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Colour matrices that turn OpenStreetMap tiles into the design's map
/// styles ("Atlas claro" and "Atlas oscuro").
const _atlasLight = <double>[
  0.4951, 0.5523, 0.0558, 0, -31.42,
  0.1650, 0.8877, 0.0560, 0, -30.29,
  0.1608, 0.5411, 0.3789, 0, -29.53,
  0, 0, 0, 1, 0,
];
const _atlasDark = <double>[
  -0.2315, -0.4255, -0.0430, 0, 194.5,
  -0.1265, -0.5305, -0.0430, 0, 201.5,
  -0.1265, -0.4255, -0.1480, 0, 198.5,
  0, 0, 0, 1, 0,
];
const _topoSoft = <double>[
  0.8638, 0.1217, 0.0123, 0, 0,
  0.0362, 0.9512, 0.0123, 0, 0,
  0.0362, 0.1217, 0.8421, 0, 0,
  0, 0, 0, 1, 0,
];

/// The map tiles for a style.
TileLayer styledTiles(MapStyle style, {ErrorTileCallBack? onError}) {
  final topo = style == MapStyle.topo;
  final matrix = switch (style) {
    MapStyle.claro => _atlasLight,
    MapStyle.oscuro => _atlasDark,
    MapStyle.topo => _topoSoft,
  };
  return TileLayer(
    urlTemplate: topo
        ? 'https://tile.opentopomap.org/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.santimartz.bruma',
    maxNativeZoom: topo ? 17 : 19,
    errorTileCallback: onError,
    tileBuilder: (context, tile, _) =>
        ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: tile),
  );
}

Color mapBackground(MapStyle s) =>
    s == MapStyle.oscuro ? const Color(0xFF18221E) : Br.mapBlock;

/// Metres per screen pixel at [lat] and [zoom] (Web Mercator).
double metersPerPixel(double lat, double zoom) =>
    156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.state,
    required this.settings,
    required this.onOpenTab,
    required this.onOpenStats,
  });
  final AppState state;
  final Settings settings;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onOpenStats;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _mapReady = false;
  LatLng? _lastCentered;
  int _tilesKey = 0;
  Timer? _clock;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    s.focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    s.focus.removeListener(_onFocus);
    _clock?.cancel();
    super.dispose();
  }

  void _onState() {
    // Session clock.
    if (s.tracking && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!s.tracking && _clock != null) {
      _clock?.cancel();
      _clock = null;
    }
    final p = s.position;
    if (!_mapReady || p == null || !_follow || p == _lastCentered) return;
    _lastCentered = p;
    final zoom = _map.camera.zoom < 15 ? 17.0 : _map.camera.zoom;
    _map.move(p, zoom);
  }

  void _onFocus() {
    final p = s.focus.value?.$2;
    if (p == null || !_mapReady) return;
    setState(() => _follow = false);
    _map.move(p, math.max(_map.camera.zoom, 17));
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() async {
    HapticFeedback.lightImpact();
    final error = await s.startTracking(background: widget.settings.background);
    if (!mounted) return;
    if (error != null) {
      await Navigator.of(context).push(GpsErrorScreen.route(error));
    } else {
      setState(() => _follow = true);
    }
  }

  Future<void> _stop() async {
    HapticFeedback.heavyImpact();
    await s.stopTracking();
  }

  Future<void> _centerOnMe() async {
    HapticFeedback.selectionClick();
    setState(() => _follow = true);
    if (s.position == null) {
      final error = await s.locateOnce();
      if (error != null && mounted) {
        await Navigator.of(context).push(GpsErrorScreen.route(error));
        return;
      }
    }
    final p = s.position;
    if (p != null) {
      _lastCentered = p;
      _map.move(p, _map.camera.zoom < 15 ? 17 : _map.camera.zoom);
    }
  }

  void _showPlace(Poi poi) {
    if (poi.discovered == null) {
      _toast('Un lugar misterioso… acércate para descubrirlo.');
      return;
    }
    Navigator.of(context).push(PlaceScreen.route(s, poi));
  }

  @override
  Widget build(BuildContext context) {
    final start = s.position ?? s.lastKnown ?? const LatLng(4.6488, -74.0636);
    final top = math.max(MediaQuery.paddingOf(context).top, 24.0) + 16;
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: start,
              initialZoom: 17,
              minZoom: 3,
              maxZoom: 19,
              backgroundColor: mapBackground(widget.settings.mapStyle),
              onMapReady: () => _mapReady = true,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              KeyedSubtree(
                key: ValueKey(_tilesKey),
                child: styledTiles(widget.settings.mapStyle,
                    onError: (_, _, _) => s.tileError.value = DateTime.now()),
              ),
              FogLayer(state: s, settings: widget.settings),
              ListenableBuilder(
                listenable: s,
                builder: (context, _) => _PlacesLayer(
                    pois: s.pois.values, me: s.position, onTap: _showPlace),
              ),
              ListenableBuilder(
                listenable: s,
                builder: (context, _) => _UserLayer(state: s),
              ),
            ],
          ),

          // HUD.
          Positioned(
            left: 16,
            right: 16,
            top: top,
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => _Hud(
                state: s,
                onLevel: () => widget.onOpenTab(2),
                onStats: widget.onOpenStats,
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: top + 68,
            child: _Compass(controller: _map),
          ),
          Positioned(
            left: 12,
            right: 82,
            top: top + 68,
            child: ValueListenableBuilder<DateTime?>(
              valueListenable: s.tileError,
              builder: (context, at, _) {
                final show = at != null &&
                    DateTime.now().difference(at) < const Duration(seconds: 20);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: show
                      ? _OfflineBanner(onRetry: () {
                          s.tileError.value = null;
                          setState(() => _tilesKey++);
                        })
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),

          // Controls and session card.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Credit required by the map tile providers.
                            Text(
                                widget.settings.mapStyle == MapStyle.topo
                                    ? '© OpenStreetMap · OpenTopoMap'
                                    : '© OpenStreetMap',
                                style: BrText.mono(9,
                                    color: widget.settings.mapStyle ==
                                            MapStyle.oscuro
                                        ? Br.textMuted
                                        : Br.mapInk)),
                            const SizedBox(height: 4),
                            _ScaleBar(
                                controller: _map,
                                miles: widget.settings.miles),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(children: [
                          MapButton(
                            label: 'Apariencia de la niebla y del mapa',
                            onTap: () => Navigator.of(context).push(
                                AppearanceScreen.route(widget.settings, s)),
                            child: const BrIcon(BrIcons.layers),
                          ),
                          const SizedBox(height: 10),
                          MapButton(
                            label: 'Centrar en mi ubicación',
                            size: 56,
                            radius: 18,
                            color: Br.green,
                            border: false,
                            shadow: Br.shadow,
                            onTap: _centerOnMe,
                            child: BrIcon(
                                _follow ? BrIcons.locate : BrIcons.locateOff,
                                size: 24,
                                color: Br.bg,
                                stroke: 2),
                          ),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Br.curve,
                    switchOutCurve: Br.curve,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SizeTransition(
                          sizeFactor: a, alignment: Alignment.bottomCenter, child: child),
                    ),
                    child: s.tracking
                        ? _SessionCard(
                            key: const ValueKey('on'),
                            state: s,
                            settings: widget.settings,
                            onStop: _stop)
                        : s.cells.isEmpty
                            ? _EmptyCard(key: const ValueKey('empty'), onStart: _start)
                            : _IdleCard(
                                key: const ValueKey('off'),
                                streak: currentStreak(s.days),
                                onStart: _start),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- HUD

class _Hud extends StatelessWidget {
  const _Hud({required this.state, required this.onLevel, required this.onStats});
  final AppState state;
  final VoidCallback onLevel;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    final xp = state.xp;
    final lvl = levelFor(xp);
    final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
    final frac = (xp - from) / (to - from);
    final city = state.currentCity;
    final pct = city == null ? null : state.cityPercent(city);
    final name = city?.name.toUpperCase() ??
        (state.tracking ? 'BUSCANDO CIUDAD…' : 'SIN CIUDAD');
    return Row(children: [
      Semantics(
        button: true,
        label: 'Nivel $lvl, ${(frac * 100).round()} % hacia el nivel ${lvl + 1}',
        excludeSemantics: true,
        child: GestureDetector(onTap: onLevel, child: LevelRing(level: lvl, progress: frac)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GestureDetector(
          onTap: onLevel,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Br.bg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Br.border),
              boxShadow: Br.shadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, ?current],
                        ),
                        child: Text(name,
                            key: ValueKey(name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BrText.mono(10, tracking: .14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (pct == null)
                      Text('—', style: BrText.display(22))
                    else
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: pct),
                        duration: const Duration(milliseconds: 700),
                        curve: Br.curve,
                        builder: (_, v, _) =>
                            Text(fmtPercent(v), style: BrText.display(22)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                BrBar(
                  value: (pct ?? 0) / 100,
                  height: 3,
                  color: Br.green,
                  minWidth: pct == null ? 0 : 8,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      MapButton(
        label: 'Estadísticas',
        size: 56,
        radius: 28,
        shadow: Br.shadow,
        onTap: onStats,
        child: const BrIcon(BrIcons.stats),
      ),
    ]);
  }
}

/// Level number inside its XP ring.
class LevelRing extends StatelessWidget {
  const LevelRing({super.key, required this.level, required this.progress});
  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Br.bg,
          shape: BoxShape.circle,
          border: Border.all(color: Br.border),
          boxShadow: Br.shadow,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0, 1)),
          duration: const Duration(milliseconds: 500),
          curve: Br.curve,
          builder: (_, v, child) =>
              CustomPaint(painter: _RingPainter(v), child: child),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('NV', style: BrText.mono(8, tracking: .12)),
            Text('$level', style: BrText.display(24)),
          ]),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Br.surfaceHigh;
    canvas.drawCircle(c, r, p);
    if (value <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * value, false,
        p
          ..color = Br.green
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class _Compass extends StatelessWidget {
  const _Compass({required this.controller});
  final MapController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: controller.mapEventStream,
      builder: (context, _) {
        double rot = 0;
        try {
          rot = controller.camera.rotation;
        } catch (_) {}
        return MapButton(
          label: 'Orientar al norte',
          size: 44,
          radius: 22,
          onTap: () {
            HapticFeedback.selectionClick();
            controller.rotate(0);
          },
          child: Transform.rotate(
            angle: rot * math.pi / 180,
            child: CustomPaint(size: const Size(26, 26), painter: _NeedlePainter()),
          ),
        );
      },
    );
  }
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        Path()
          ..moveTo(13, 3)
          ..lineTo(16, 13)
          ..lineTo(10, 13)
          ..close(),
        Paint()..color = Br.green);
    canvas.drawPath(
        Path()
          ..moveTo(13, 23)
          ..lineTo(10, 13)
          ..lineTo(16, 13)
          ..close(),
        Paint()..color = Br.greenDeep);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => false;
}

class _ScaleBar extends StatelessWidget {
  const _ScaleBar({required this.controller, required this.miles});
  final MapController controller;
  final bool miles;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: controller.mapEventStream,
      builder: (context, _) {
        MapCamera camera;
        try {
          camera = controller.camera;
        } catch (_) {
          return const SizedBox.shrink();
        }
        final mpp = metersPerPixel(camera.center.latitude, camera.zoom);
        // Pick the first round distance that is at least 24 px long.
        final steps = miles
            ? <(double, String)>[
                for (final f in [50, 100, 200, 500, 1000, 2000]) (f * 0.3048, '$f ft'),
                for (final m in [1, 2, 5, 10, 20, 50, 100]) (m * 1609.34, '$m mi'),
              ]
            : <(double, String)>[
                for (final m in [10, 20, 30, 50, 100, 200, 300, 500]) (m.toDouble(), '$m m'),
                for (final k in [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000])
                  (k * 1000.0, '$k km'),
              ];
        var pick = steps.last;
        for (final st in steps) {
          if (st.$1 / mpp >= 24) {
            pick = st;
            break;
          }
        }
        final px = (pick.$1 / mpp).clamp(8.0, 120.0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration:
              BoxDecoration(color: Br.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: px,
              height: 5,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Br.text, width: 1.5),
                  right: BorderSide(color: Br.text, width: 1.5),
                  bottom: BorderSide(color: Br.text, width: 1.5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(pick.$2, style: BrText.mono(10.5, color: Br.text)),
          ]),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
            color: Br.bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: Br.shadowSmall),
        child: Row(children: [
          const BrIcon(BrIcons.offline, size: 20, color: Br.goldWarn),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Sin conexión. Sigues despejando niebla.',
                style: BrText.ui(12.5, color: Br.text, height: 1.35)),
          ),
          TextAction('Reintentar', onPressed: onRetry),
        ]),
      );
}

// ------------------------------------------------------------- session cards

BoxDecoration get _cardBox => BoxDecoration(
      color: Br.bg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Br.border),
      boxShadow: const [
        BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10)),
      ],
    );

class _SessionCard extends StatelessWidget {
  const _SessionCard(
      {super.key, required this.state, required this.settings, required this.onStop});
  final AppState state;
  final Settings settings;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final started = state.sessionStart ?? DateTime.now();
    final (dist, unit) = settings.distance(state.sessionMeters / 1000);
    final double km2 = state.sessionCells *
        (state.cells.isEmpty ? 0.0 : state.exploredKm2 / state.cells.length);
    final gained = state.xp - state.sessionXpStart;
    Widget figure(String v, String? u, String label, {Color color = Br.text}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Figure(v, unit: u, size: 24, unitSize: 12, color: color),
          Text(label, style: BrText.ui(11, color: Br.textMuted)),
        ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: _cardBox,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const _LiveDot(),
              const SizedBox(width: 8),
              Text('Explorando', style: BrText.ui(13, weight: FontWeight.w700)),
              const Spacer(),
              Text(fmtClock(DateTime.now().difference(started)),
                  style: BrText.mono(12)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 18, runSpacing: 6, children: [
              figure(fmtDec(dist), unit, 'recorrido'),
              figure(fmtDec(km2, 3), 'km²', 'despejado'),
              figure('+${fmtInt(gained)}', null, 'XP', color: Br.gold),
            ]),
          ]),
        ),
        const SizedBox(width: 14),
        _HoldToStop(onStop: onStop),
      ]),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Br.green,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x33A8C686), spreadRadius: 4)],
        ),
      );
}

/// Stop button that has to be held for 600 ms, to avoid accidental taps.
class _HoldToStop extends StatefulWidget {
  const _HoldToStop({required this.onStop});
  final VoidCallback onStop;

  @override
  State<_HoldToStop> createState() => _HoldToStopState();
}

class _HoldToStopState extends State<_HoldToStop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        widget.onStop();
        _c.reset();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Detener exploración (mantén pulsado)',
      onTap: widget.onStop,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _c.forward();
        },
        onTapUp: (_) {
          if (_c.status != AnimationStatus.completed) {
            _c.reverse();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                  content: Text('Mantén pulsado para detener la exploración.'),
                  duration: Duration(seconds: 2)));
          }
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: Br.surfaceHigh, borderRadius: BorderRadius.circular(18)),
            child: CustomPaint(
              painter: _HoldPainter(_c.value),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Br.text, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoldPainter extends CustomPainter {
  _HoldPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v <= 0) return;
    final r = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1.5), const Radius.circular(16.5));
    final path = Path()..addRRect(r);
    final m = path.computeMetrics().first;
    canvas.drawPath(
        m.extractPath(0, m.length * v),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Br.green);
  }

  @override
  bool shouldRepaint(_HoldPainter old) => old.v != v;
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({super.key, required this.streak, required this.onStart});
  final int streak;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardBox,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Listo para explorar',
                  style: BrText.ui(13, weight: FontWeight.w700)),
              const Spacer(),
              Text(
                  streak == 0
                      ? 'Empieza una racha hoy'
                      : streak == 1
                          ? 'Racha de 1 día'
                          : 'Racha de $streak días',
                  style: BrText.ui(12, color: Br.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton('Iniciar exploración',
              icon: BrIcons.steps, onPressed: onStart),
        ]),
      );
}

/// First day: nothing explored yet.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardBox.copyWith(borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tu mapa está en blanco.',
                style: BrText.display(24, height: 1.1)),
            const SizedBox(height: 10),
            Text('Da tus primeros pasos: cada 30 m de camino aparecen las calles.',
                style: BrText.ui(13, color: Br.textMuted, height: 1.45)),
            const SizedBox(height: 10),
            PrimaryButton('Iniciar exploración',
                height: 48, radius: 16, fontSize: 15, onPressed: onStart),
          ],
        ),
      );
}

// ------------------------------------------------------------------ layers

class _PlacesLayer extends StatelessWidget {
  const _PlacesLayer({required this.pois, required this.me, required this.onTap});
  final Iterable<Poi> pois;
  final LatLng? me;
  final void Function(Poi) onTap;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (camera.zoom < 13) return const SizedBox.shrink();
    final bounds = camera.visibleBounds;
    const dist = Distance();
    final markers = <Marker>[];
    final labels = <Marker>[];
    for (final p in pois) {
      if (!bounds.contains(p.point)) continue;
      if (p.discovered != null) {
        markers.add(Marker(
          point: p.point,
          width: 44,
          height: 44,
          child: Semantics(
            button: true,
            label: '${p.name}, descubierto',
            child: GestureDetector(
                onTap: () => onTap(p), child: Center(child: FoundMarker(p.info.icon))),
          ),
        ));
        continue;
      }
      final d = me == null ? null : dist.as(LengthUnit.Meter, me!, p.point);
      final near = d != null && d < 150;
      final far = d != null && d > 1500;
      markers.add(Marker(
        point: p.point,
        width: near ? 72 : 44,
        height: near ? 72 : 44,
        child: Semantics(
          button: true,
          label: near
              ? 'Lugar misterioso cercano, a ${d.round()} metros'
              : far
                  ? 'Lugar misterioso lejano'
                  : 'Lugar misterioso',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onTap(p),
            child: Center(child: MysteryMarker(near: near, far: far)),
          ),
        ),
      ));
      if (near) {
        labels.add(Marker(
          point: p.point,
          width: 90,
          height: 120,
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(0, 0.85),
              child: MapPill(fmtMeters(d, approx: true), mono: true),
            ),
          ),
        ));
      }
    }
    return MarkerLayer(markers: [...labels, ...markers]);
  }
}

/// You on the map: dot, 30 m dashed radius, direction of travel, GPS halo.
class _UserLayer extends StatefulWidget {
  const _UserLayer({required this.state});
  final AppState state;

  @override
  State<_UserLayer> createState() => _UserLayerState();
}

class _UserLayerState extends State<_UserLayer> {
  int _shownGain = 0;
  int _gainId = 0;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _gainId = widget.state.gain.value.$1;
    widget.state.gain.addListener(_onGain);
  }

  @override
  void dispose() {
    widget.state.gain.removeListener(_onGain);
    _hide?.cancel();
    super.dispose();
  }

  void _onGain() {
    final (id, xp) = widget.state.gain.value;
    if (id == _gainId) return;
    _gainId = id;
    setState(() => _shownGain = xp);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _shownGain = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = s.position;
    if (p == null) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final mpp = metersPerPixel(p.latitude, camera.zoom);
    final reveal = (30 / mpp).clamp(10.0, 400.0);
    final imprecise = (s.accuracy ?? 0) > 30;
    final halo = imprecise ? (s.accuracy! / mpp).clamp(38.0, 400.0) : 0.0;
    final box = math.max(reveal, halo) * 2 + 90;
    return MarkerLayer(markers: [
      Marker(
        point: p,
        width: box,
        height: box,
        child: IgnorePointer(
          child: Semantics(
            label: 'Tu ubicación',
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: Size.square(box),
                painter: _UserPainter(
                  reveal: reveal,
                  halo: halo,
                  tracking: s.tracking,
                  heading: s.tracking && s.moving && s.heading != null
                      ? s.heading! + camera.rotation
                      : null,
                ),
              ),
              Positioned(
                top: box / 2 - 44,
                child: AnimatedOpacity(
                  opacity: _shownGain > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: AnimatedSlide(
                    offset: _shownGain > 0 ? Offset.zero : const Offset(0, .4),
                    duration: const Duration(milliseconds: 350),
                    curve: Br.curve,
                    child: MapPill('+${_shownGain == 0 ? '' : fmtInt(_shownGain)} XP'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _UserPainter extends CustomPainter {
  _UserPainter({
    required this.reveal,
    required this.halo,
    required this.tracking,
    required this.heading,
  });

  final double reveal;
  final double halo;
  final bool tracking;
  final double? heading;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (halo > 0) {
      canvas.drawCircle(c, halo, Paint()..color = Br.green.withValues(alpha: .12));
      canvas.drawCircle(
          c,
          halo,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Br.green.withValues(alpha: .4));
    } else if (tracking) {
      dashedCircle(
          canvas,
          c,
          reveal,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Br.bg.withValues(alpha: .5),
          dash: 3,
          gap: 3);
    }
    if (heading != null && halo == 0) {
      // Field of view in the direction of travel.
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(heading! * math.pi / 180);
      final r = 40.0;
      final cone = Path()
        ..moveTo(0, 0)
        ..lineTo(-15, -39)
        ..arcToPoint(const Offset(15, -39), radius: Radius.circular(r))
        ..close();
      canvas.drawPath(cone, Paint()..color = Br.greenDeep.withValues(alpha: .3));
      canvas.restore();
    }
    final paused = !tracking;
    // Halo + shadow.
    if (!paused) {
      canvas.drawCircle(c, 8 + 5, Paint()..color = const Color(0x59536D50));
    }
    canvas.drawCircle(
        c.translate(0, 2),
        9,
        Paint()
          ..color = const Color(0x66101714)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(c, 8, Paint()..color = paused ? Br.greenDeep : Colors.white);
    canvas.drawCircle(c, 5, Paint()..color = paused ? Br.textMuted : Br.bg);
  }

  @override
  bool shouldRepaint(_UserPainter old) =>
      old.reveal != reveal ||
      old.halo != halo ||
      old.tracking != tracking ||
      old.heading != heading;
}
