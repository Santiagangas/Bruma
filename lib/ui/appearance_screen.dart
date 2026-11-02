import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../app_state.dart';
import '../settings.dart';
import 'fog_layer.dart';
import 'icons.dart';
import 'map_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Personalizar la niebla": fog colour, contour texture and map style,
/// with a live preview. Nothing changes until "Aplicar".
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key, required this.settings, required this.state});
  final Settings settings;
  final AppState state;

  static Route<void> route(Settings settings, AppState state) => MaterialPageRoute(
      builder: (_) => AppearanceScreen(settings: settings, state: state));

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  // Draft copy (not saved) used by the preview.
  late final Settings _draft = Settings()
    ..fogIndex = widget.settings.fogIndex
    ..contours = widget.settings.contours
    ..mapStyle = widget.settings.mapStyle;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _apply() {
    widget.settings
      ..setFog(_draft.fogIndex, withContours: _draft.contours)
      ..setMapStyle(_draft.mapStyle);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final center = s.position ?? s.lastKnown ?? const LatLng(4.6488, -74.0636);
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final fog = _draft.fog;
        final hex = '#${(fog.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        return Scaffold(
          body: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 400 + top,
              child: IgnorePointer(
                child: Semantics(
                  label: 'Vista previa de la niebla con el color elegido',
                  child: FlutterMap(
                    key: ValueKey(_draft.mapStyle),
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 17,
                      backgroundColor: mapBackground(_draft.mapStyle),
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      styledTiles(_draft.mapStyle),
                      FogLayer(state: s, settings: _draft),
                      MarkerLayer(markers: [
                        Marker(
                          point: center,
                          width: 30,
                          height: 30,
                          child: Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Br.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(color: Color(0x59536D50), spreadRadius: 5)],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: top + 16,
              child: MapButton(
                label: 'Cerrar',
                shadow: const [],
                onTap: () => Navigator.of(context).pop(),
                child: const BrIcon(BrIcons.close, size: 20, stroke: 2),
              ),
            ),
            Positioned.fill(
              top: 372 + top,
              child: Container(
                decoration: const BoxDecoration(
                  color: Br.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(22, 14, 22, 28 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Tu niebla', style: BrText.display(32)),
                        const Spacer(),
                        Text('${fog.name} · $hex', style: BrText.mono(12)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      for (var i = 0; i < Br.fogs.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == _draft.fogIndex,
                            button: true,
                            label: Br.fogs[i].name,
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () => _draft.setFog(i),
                              child: Column(children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Br.fogs[i].color,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: i == _draft.fogIndex
                                        ? const [
                                            BoxShadow(color: Br.green, spreadRadius: 4),
                                            BoxShadow(color: Br.bg, spreadRadius: 2),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(Br.fogs[i].name,
                                    style: BrText.ui(11.5,
                                        weight: FontWeight.w700,
                                        color: i == _draft.fogIndex ? Br.text : Br.textMuted)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: const BoxDecoration(
                        border: Border.symmetric(horizontal: BorderSide(color: Br.hairline)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Curvas de nivel', style: BrText.ui(15, weight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Textura de atlas sobre la niebla',
                                style: BrText.ui(12, color: Br.textMuted)),
                          ]),
                        ),
                        BrSwitch(
                          value: _draft.contours,
                          onChanged: (v) => _draft.setFog(_draft.fogIndex, withContours: v),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text('Mapa', style: BrText.ui(15, weight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Segmented<MapStyle>(
                      options: const [
                        (MapStyle.claro, 'Atlas claro'),
                        (MapStyle.oscuro, 'Atlas oscuro'),
                        (MapStyle.topo, 'Topográfico'),
                      ],
                      value: _draft.mapStyle,
                      onChanged: _draft.setMapStyle,
                    ),
                    const SizedBox(height: 10),
                    Text('Con mapa claro, los tonos de niebla oscuros dan el mayor contraste (≈ 9:1).',
                        style: BrText.ui(12, color: Br.textMuted, height: 1.45)),
                    const SizedBox(height: 24),
                    PrimaryButton('Aplicar', height: 52, radius: 16, fontSize: 15, onPressed: _apply),
                  ],
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
