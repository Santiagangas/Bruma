import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../game/progress.dart';
import '../models.dart';
import 'fog_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _mapReady = false;
  LatLng? _lastCentered;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    final p = s.position;
    if (!_mapReady || p == null || !_follow || p == _lastCentered) return;
    _lastCentered = p;
    final zoom = _map.camera.zoom < 15 ? 17.0 : _map.camera.zoom;
    _map.move(p, zoom);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleTracking() async {
    if (s.tracking) {
      await s.stopTracking();
      return;
    }
    final error = await s.startTracking();
    if (error != null) {
      _toast(error);
    } else {
      setState(() => _follow = true);
    }
  }

  Future<void> _centerOnMe() async {
    setState(() => _follow = true);
    if (s.position == null) {
      final error = await s.locateOnce();
      if (error != null) _toast(error);
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
    final date = DateTime.fromMillisecondsSinceEpoch(poi.discovered!);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(poi.info.icon, color: poi.info.color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(poi.name,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${poi.info.label} · descubierto el '
                '${date.day}/${date.month}/${date.year}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = s.position ?? s.lastKnown ?? const LatLng(4.7110, -74.0721);
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: start,
            initialZoom: 16,
            minZoom: 3,
            maxZoom: 19,
            backgroundColor: const Color(0xFF151B2C),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => _mapReady = true,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _follow) setState(() => _follow = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.santimartz.bruma',
              maxNativeZoom: 19,
            ),
            FogLayer(state: s),
            ListenableBuilder(
              listenable: s,
              builder: (context, _) => _PlacesLayer(
                  pois: s.pois.values, onTap: _showPlace),
            ),
            ListenableBuilder(
              listenable: s,
              builder: (context, _) {
                final p = s.position;
                if (p == null) return const SizedBox.shrink();
                return MarkerLayer(markers: [
                  Marker(
                    point: p,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: s.tracking
                            ? const Color(0xFF4FC3F7)
                            : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 8, color: Colors.black54)
                        ],
                      ),
                    ),
                  ),
                ]);
              },
            ),
            // OpenStreetMap asks for credit; this keeps it to a small
            // button that only shows the text when tapped.
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution('Colaboradores de OpenStreetMap'),
              ],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => _Hud(state: s),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'center',
                  onPressed: _centerOnMe,
                  child: Icon(
                      _follow ? Icons.my_location : Icons.location_searching),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'track',
                  onPressed: _toggleTracking,
                  backgroundColor:
                      s.tracking ? Colors.redAccent : const Color(0xFF6EC6CA),
                  foregroundColor: Colors.black,
                  icon: Icon(s.tracking ? Icons.stop : Icons.explore),
                  label: Text(s.tracking ? 'Detener' : 'Explorar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacesLayer extends StatelessWidget {
  const _PlacesLayer({required this.pois, required this.onTap});
  final Iterable<Poi> pois;
  final void Function(Poi) onTap;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (camera.zoom < 13) return const SizedBox.shrink();
    final bounds = camera.visibleBounds;
    final markers = <Marker>[
      for (final p in pois)
        if (bounds.contains(p.point))
          Marker(
            point: p.point,
            width: 34,
            height: 34,
            child: GestureDetector(
              onTap: () => onTap(p),
              child: p.discovered == null
                  ? const CircleAvatar(
                      backgroundColor: Color(0xCC2A2F45),
                      child: Text('?',
                          style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    )
                  : CircleAvatar(
                      backgroundColor: p.info.color,
                      child: Icon(p.info.icon, size: 18, color: Colors.black),
                    ),
            ),
          ),
    ];
    return MarkerLayer(markers: markers);
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final xp = state.xp;
    final lvl = levelFor(xp);
    final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
    final city = state.currentCity;
    final text = Theme.of(context).textTheme;
    return Card(
      color: const Color(0xEE1E2438),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Nivel $lvl', style: text.titleMedium),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titleFor(lvl),
                    style: text.bodyMedium?.copyWith(color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('$xp XP', style: text.bodySmall),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (xp - from) / (to - from),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _PercentBox(
                  icon: Icons.location_city,
                  label: city?.name ??
                      (state.tracking ? 'Buscando ciudad…' : 'Ciudad'),
                  value: city == null
                      ? '—'
                      : formatPercent(state.cityPercent(city)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PercentBox(
                  icon: Icons.public,
                  label: 'Mundo',
                  value: formatPercent(state.worldPercent),
                ),
              ),
            ]),
            if (state.tracking && state.accuracy != null) ...[
              const SizedBox(height: 6),
              Text('GPS ±${state.accuracy!.round()} m',
                  style: text.bodySmall?.copyWith(
                      color: state.accuracy! > 40
                          ? Colors.orangeAccent
                          : Colors.greenAccent)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PercentBox extends StatelessWidget {
  const _PercentBox(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3150),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: Colors.white70)),
            ),
          ]),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
