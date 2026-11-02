import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/theme.dart';

enum MapStyle { claro, oscuro, topo }

/// Choices that belong to this phone, not to the exploration data (they are
/// not part of the backup and survive "Borrar todo").
class Settings extends ChangeNotifier {
  SharedPreferences? _p;

  bool onboarded = false;
  int fogIndex = 0;
  bool contours = true;
  MapStyle mapStyle = MapStyle.claro;
  bool miles = false;
  bool background = true;
  bool notices = true;
  int? lastExport;

  /// Badges already shown in the Insignias tab (for the "new" dot).
  Set<String> seenBadges = {};

  FogTone get fog => Br.fogs[fogIndex.clamp(0, Br.fogs.length - 1)];

  Future<void> load() async {
    try {
      final p = _p = await SharedPreferences.getInstance();
      onboarded = p.getBool('onboarded') ?? false;
      fogIndex = p.getInt('fog') ?? 0;
      contours = p.getBool('contours') ?? true;
      mapStyle = MapStyle.values[
          (p.getInt('map_style') ?? 0).clamp(0, MapStyle.values.length - 1)];
      miles = p.getBool('miles') ?? false;
      background = p.getBool('background') ?? true;
      notices = p.getBool('notices') ?? true;
      lastExport = p.getInt('last_export');
      seenBadges = (p.getStringList('seen_badges') ?? const []).toSet();
    } catch (e) {
      debugPrint('No se pudieron leer los ajustes: $e');
    }
  }

  void _save(void Function(SharedPreferences p) write) {
    notifyListeners();
    final p = _p;
    if (p != null) write(p);
  }

  void finishOnboarding() {
    onboarded = true;
    _save((p) => p.setBool('onboarded', true));
  }

  void setFog(int i, {bool? withContours}) {
    fogIndex = i;
    if (withContours != null) contours = withContours;
    _save((p) {
      p.setInt('fog', i);
      p.setBool('contours', contours);
    });
  }

  void setMapStyle(MapStyle s) {
    mapStyle = s;
    _save((p) => p.setInt('map_style', s.index));
  }

  void setMiles(bool v) {
    miles = v;
    _save((p) => p.setBool('miles', v));
  }

  void setBackground(bool v) {
    background = v;
    _save((p) => p.setBool('background', v));
  }

  void setNotices(bool v) {
    notices = v;
    _save((p) => p.setBool('notices', v));
  }

  void markExported() {
    lastExport = DateTime.now().millisecondsSinceEpoch;
    _save((p) => p.setInt('last_export', lastExport!));
  }

  void markBadgesSeen(Iterable<String> ids) {
    if (seenBadges.containsAll(ids)) return;
    seenBadges = {...seenBadges, ...ids};
    _save((p) => p.setStringList('seen_badges', seenBadges.toList()));
  }

  /// Distance in the chosen unit, plus the unit label.
  (double, String) distance(double km) =>
      miles ? (km * 0.621371, 'mi') : (km, 'km');
}
