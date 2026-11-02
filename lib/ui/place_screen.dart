import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../app_state.dart';
import '../models.dart';
import '../settings.dart';
import 'format.dart';
import 'icons.dart';
import 'map_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Ficha del lugar": a discovered place, with your private note.
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key, required this.state, required this.poi});
  final AppState state;
  final Poi poi;

  /// Map style for the header; set once at start-up from [Settings].
  static MapStyle style = MapStyle.claro;

  static Route<void> route(AppState state, Poi poi) =>
      MaterialPageRoute(builder: (_) => PlaceScreen(state: state, poi: poi));

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  late final _note = TextEditingController(text: widget.state.notes[widget.poi.id] ?? '');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _save();
    _note.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final old = widget.state.notes[widget.poi.id] ?? '';
    if (_note.text.trim() != old) widget.state.setNote(widget.poi, _note.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final poi = widget.poi;
    final info = poi.info;
    final when = DateTime.fromMillisecondsSinceEpoch(poi.discovered ?? 0);
    final city = s.cityAt(poi.lat, poi.lon);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // Map of the spot.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 320 + top,
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: poi.point,
                initialZoom: 17,
                backgroundColor: mapBackground(PlaceScreen.style),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                styledTiles(PlaceScreen.style),
                MarkerLayer(markers: [
                  Marker(
                    point: poi.point,
                    width: 80,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Br.gold.withValues(alpha: .16),
                        border: Border.all(color: Br.gold.withValues(alpha: .5)),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Br.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Br.bg, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x73000000), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: Center(child: BrIcon(info.icon, size: 22, color: Br.bg, stroke: 1.9)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: top + 20,
          child: const BackArrow(boxed: true),
        ),

        // Sheet.
        Positioned.fill(
          top: 288 + top,
          child: Container(
            decoration: const BoxDecoration(
              color: Br.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 14, 24, 28 + MediaQuery.paddingOf(context).bottom),
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Br.gold.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      BrIcon(info.icon, size: 14, color: Br.gold, stroke: 2),
                      const SizedBox(width: 6),
                      Text(info.label, style: BrText.ui(12, weight: FontWeight.w700, color: Br.gold)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('HALLAZGO Nº ${s.discoveryNumber(poi)}', style: BrText.mono(11, tracking: .08)),
                ]),
                const SizedBox(height: 16),
                Text(poi.name, style: BrText.display(40)),
                const SizedBox(height: 4),
                Text(city?.name ?? 'Fuera de tus ciudades',
                    style: BrText.ui(14, color: Br.textMuted)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: SurfaceCard(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Descubierto', style: BrText.ui(12, color: Br.textMuted)),
                        const SizedBox(height: 2),
                        Text(fmtDate(when), style: BrText.ui(15, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${fmtTime(when)} · ${partOfDay(when)}', style: BrText.mono(11)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SurfaceCard(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Recompensa', style: BrText.ui(12, color: Br.textMuted)),
                        const SizedBox(height: 2),
                        Text('+${info.xp} XP', style: BrText.display(28, height: 1.05, color: Br.gold)),
                        const SizedBox(height: 4),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(fmtCoords(poi.lat, poi.lon),
                          style: BrText.mono(12, color: Br.green, tracking: .1)),
                    ),
                    Text('Datos: OpenStreetMap', style: BrText.ui(11, color: Br.textMuted)),
                  ]),
                ),
                const SizedBox(height: 18),
                Text('Tu nota (solo en este teléfono)', style: BrText.ui(12, color: Br.textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _note,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  style: BrText.ui(14),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    hintText: '¿Qué encontraste aquí?',
                    hintStyle: BrText.ui(14, color: Br.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Br.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Br.green),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SecondaryButton('Ver en el mapa', icon: BrIcons.map, onPressed: () {
                  s.focusOn(poi.point);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
