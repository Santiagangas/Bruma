import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../game/progress.dart';
import '../settings.dart';
import 'appearance_screen.dart';
import 'format.dart';
import 'icons.dart';
import 'permissions_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Perfil y privacidad": your atlas without an account, settings and data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key, required this.state, required this.settings, required this.onOpenBadges});
  final AppState state;
  final Settings settings;
  final VoidCallback onOpenBadges;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  int? _dbBytes;
  int? _cacheBytes;
  String _permission = '…';

  AppState get s => widget.state;
  Settings get settings => widget.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final db = await s.databaseBytes();
    final cache = await _cacheSize();
    final perm = await _permissionText();
    if (!mounted) return;
    setState(() {
      _dbBytes = db;
      _cacheBytes = cache;
      _permission = perm;
    });
  }

  static Future<Directory> _cacheDir() async =>
      Directory(p.join((await getApplicationCacheDirectory()).path, 'fm_cache'));

  static Future<int> _cacheSize() async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final f in dir.list(recursive: true, followLinks: false)) {
        if (f is File) total += await f.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<String> _permissionText() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return 'Sin permiso';
      }
      final acc = await Geolocator.getLocationAccuracy();
      final precise = acc == LocationAccuracyStatus.precise ? 'precisa' : 'aproximada';
      return perm == LocationPermission.always
          ? 'Todo el tiempo · $precise'
          : 'Mientras usas la app · $precise';
    } catch (_) {
      return 'Desconocido';
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _clearCache() async {
    try {
      await BuiltInMapCachingProvider.getOrCreateInstance().destroy(deleteCache: true);
    } catch (_) {
      try {
        final dir = await _cacheDir();
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
    await _refresh();
    if (mounted) _toast('Caché de mapas liberada.');
  }

  Future<void> _export() async {
    try {
      final json = await s.exportJson();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final file = File(p.join(dir.path,
          'bruma-respaldo-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.bruma'));
      await file.writeAsString(json);
      await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path, mimeType: 'application/json')], title: 'Respaldo de Bruma'));
      settings.markExported();
    } catch (e) {
      if (mounted) _toast('No se pudo exportar: $e');
    }
  }

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) return;
      await s.importJson(await File(path).readAsString());
      if (mounted) _toast('Respaldo importado.');
    } catch (e) {
      if (mounted) _toast('No se pudo importar: $e');
    }
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todo?'),
        content: const Text(
            'Se borrarán el mapa explorado, los lugares, las insignias, tus notas y el '
            'nivel. No se puede deshacer. Exporta un respaldo antes si quieres conservarlo.'),
        actions: [
          TextAction('Cancelar', onPressed: () => Navigator.pop(ctx, false)),
          TextAction('Borrar', danger: true, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await s.wipe();
      await _refresh();
      if (mounted) _toast('Datos borrados.');
    }
  }

  static String _mb(int? bytes) {
    if (bytes == null) return '…';
    final mb = bytes / (1024 * 1024);
    return mb >= 100 ? '${fmtInt(mb)} MB' : '${fmtDec(mb, 1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([s, settings]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _row({
    required Widget child,
    VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Br.hairline))),
          child: child,
        ),
      );

  Widget _titled(String title, String subtitle, {Color subColor = Br.textMuted}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: BrText.ui(15, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: BrText.ui(12, color: subColor)),
        ],
      );

  Widget _build(BuildContext context) {
    final xp = s.xp;
    final lvl = levelFor(xp);
    final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
    final st = s.stats;
    final since = s.firstDay;
    final recent = (s.unlocked.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => badgeById(e.key)!)
        .toList();
    final next = s.nextBadge;
    final total = (_dbBytes ?? 0) + (_cacheBytes ?? 0);
    final progressShare = total == 0 ? 0.0 : (_dbBytes ?? 0) / total;
    final top = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, top + 28, 20, 110),
      children: [
        // Identity without an account.
        Row(children: [
          SvgPicture.string(_emblem, width: 76, height: 76),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TU ATLAS · SIN CUENTA', style: BrText.mono(10.5, tracking: .14)),
              const SizedBox(height: 4),
              Text(titleFor(lvl), style: BrText.display(30, height: 1.05)),
              const SizedBox(height: 4),
              Text(since == null ? 'Aún sin explorar' : 'Explorando desde el ${fmtDate(since)}',
                  style: BrText.ui(13, color: Br.textMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Text('Nivel $lvl', style: BrText.ui(12, weight: FontWeight.w700)),
          const Spacer(),
          Text('${fmtInt(xp - from)} / ${fmtInt(to - from)} XP', style: BrText.mono(12)),
        ]),
        const SizedBox(height: 8),
        BrBar(value: (xp - from) / (to - from), height: 6),
        const SizedBox(height: 22),

        // Badges.
        SurfaceCard(
          onTap: widget.onOpenBadges,
          child: Row(children: [
            SizedBox(
              width: recent.isEmpty ? 40 : 40 + 28.0 * (recent.length - 1),
              height: 40,
              child: Stack(children: [
                if (recent.isEmpty)
                  BadgeArt(badges.first, earned: false, size: 40),
                for (var i = 0; i < recent.length; i++)
                  Positioned(
                    left: 28.0 * i,
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Br.surface),
                      child: BadgeArt(recent[i], earned: true, size: 40, inner: false),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.unlocked.length} de ${badges.length} insignias',
                    style: BrText.ui(15, weight: FontWeight.w700)),
                if (next != null)
                  Text('Próxima: ${next.name} (${next.label(st)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BrText.ui(12, color: Br.textMuted)),
              ]),
            ),
            const BrIcon(BrIcons.chevron, size: 18, color: Br.textMuted, stroke: 2),
          ]),
        ),
        const SizedBox(height: 22),

        // Privacy.
        SurfaceCard(
          radius: 24,
          color: settings.fog.color,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Br.bg, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: BrIcon(BrIcons.lock, size: 20, color: Br.green, stroke: 2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Tu mapa no sale de este teléfono',
                    style: BrText.display(25, height: 1.1)),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              for (final (i, label) in const [(0, 'cuentas'), (1, 'servidores'), (2, 'datos compartidos')]) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x73F0F1E9), width: 1.5)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('0', style: BrText.display(30)),
                      Text(label, style: BrText.ui(12, color: Br.textOnFog)),
                    ]),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 14),
            Text(
                'Solo se conecta para descargar teselas y lugares de OpenStreetMap. Tu ruta, tus hallazgos y tus notas se guardan en una base de datos local.',
                style: BrText.ui(13, color: Br.textSoft, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 22),

        // Exploration settings.
        const MonoLabel('Exploración'),
        const SizedBox(height: 10),
        _row(
          onTap: () => settings.setBackground(!settings.background),
          child: Row(children: [
            Expanded(child: _titled('Seguimiento en segundo plano', 'Solo durante una sesión iniciada por ti')),
            BrSwitch(value: settings.background, onChanged: settings.setBackground),
          ]),
        ),
        _row(
          onTap: () async {
            await Navigator.of(context).push(PermissionsScreen.route(settings, fromProfile: true));
            await _refresh();
          },
          child: Row(children: [
            Expanded(
              child: _titled('Permisos de ubicación', _permission,
                  subColor: _permission == 'Sin permiso' ? Br.danger : Br.green),
            ),
            const BrIcon(BrIcons.chevron, size: 18, color: Br.textMuted, stroke: 2),
          ]),
        ),
        _row(
          onTap: () => settings.setNotices(!settings.notices),
          child: Row(children: [
            Expanded(child: _titled('Avisos de descubrimientos', 'Lugar cercano, insignias y niveles')),
            BrSwitch(value: settings.notices, onChanged: settings.setNotices),
          ]),
        ),
        _row(
          child: Row(children: [
            Expanded(child: Text('Unidades de distancia', style: BrText.ui(15, weight: FontWeight.w600))),
            SizedBox(
              width: 128,
              child: Segmented<bool>(
                options: const [(false, 'km'), (true, 'mi')],
                value: settings.miles,
                onChanged: settings.setMiles,
                height: 36,
                padding: 3,
                radius: 12,
              ),
            ),
          ]),
        ),
        _row(
          onTap: () => Navigator.of(context).push(AppearanceScreen.route(settings, s)),
          child: Row(children: [
            Expanded(
              child: _titled('Color de la niebla',
                  '${settings.fog.name} · ${settings.contours ? 'con curvas de nivel' : 'sin textura'}'),
            ),
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Br.fogs[(settings.fogIndex + i) % Br.fogs.length].color,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: i == 0
                      ? const [
                          BoxShadow(color: Br.green, spreadRadius: 4),
                          BoxShadow(color: Br.bg, spreadRadius: 2),
                        ]
                      : null,
                ),
              ),
            ],
            const SizedBox(width: 12),
            const BrIcon(BrIcons.chevron, size: 18, color: Br.textMuted, stroke: 2),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Apariencia del mapa', style: BrText.ui(15, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          for (final (i, style, label) in const [
            (0, MapStyle.claro, 'Atlas claro'),
            (1, MapStyle.oscuro, 'Atlas oscuro'),
            (2, MapStyle.topo, 'Topográfico'),
          ]) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _MapStyleOption(
                style: style,
                label: label,
                selected: settings.mapStyle == style,
                fog: settings.fog.color,
                onTap: () => settings.setMapStyle(style),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 28),

        // Data.
        const MonoLabel('Tus datos'),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Almacenamiento', style: BrText.ui(15, weight: FontWeight.w700)),
                const Spacer(),
                Text(_mb(_dbBytes == null ? null : total), style: BrText.display(22)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Expanded(flex: (progressShare * 1000).round().clamp(1, 1000), child: Container(color: Br.green)),
                  Expanded(
                      flex: ((1 - progressShare) * 1000).round().clamp(1, 1000),
                      child: Container(color: Br.greenDeep)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 16, runSpacing: 6, children: [
              _Legend(Br.green, 'Progreso ${_mb(_dbBytes)}'),
              _Legend(Br.greenDeep, 'Mapas en caché ${_mb(_cacheBytes)}'),
            ]),
            const SizedBox(height: 4),
            Transform.translate(
              offset: const Offset(-14, 0),
              child: TextAction('Liberar caché de mapas', onPressed: _clearCache),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _DataButton(
              icon: BrIcons.export,
              title: 'Exportar respaldo',
              subtitle: settings.lastExport == null
                  ? 'Nunca exportado'
                  : 'Último: ${fmtDate(DateTime.fromMillisecondsSinceEpoch(settings.lastExport!))}',
              onTap: _export,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DataButton(
              icon: BrIcons.import,
              title: 'Importar respaldo',
              subtitle: 'Archivo .bruma',
              onTap: _import,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text('El respaldo es un único archivo que tú guardas donde quieras. Bruma no lo sube a ningún sitio.',
            style: BrText.ui(12, color: Br.textMuted, height: 1.5)),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-14, 0),
            child: TextAction('Borrar todo el progreso…', danger: true, onPressed: _wipe),
          ),
        ),
        const SizedBox(height: 22),
        Text('Bruma 1.0 · Datos del mapa © colaboradores de OpenStreetMap',
            textAlign: TextAlign.center, style: BrText.ui(11, color: Br.textMuted, height: 1.6)),
      ],
    );
  }
}

const _emblem = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 76 76">
<circle cx="38" cy="38" r="37" fill="#1A2420"/>
<g fill="none" stroke="#536D50" stroke-width="1.2"><path d="M14 40 C14 22 30 14 42 16 C58 19 64 32 61 44 C58 58 44 64 32 61 C21 58 14 50 14 40Z"/><path d="M22 40 C22 28 32 22 41 24 C52 26 55 35 53 43 C51 52 42 56 34 54 C26 52 22 47 22 40Z"/></g>
<path d="M30 40 C30 34 35 31 40 32 C46 33 47 38 46 42 C45 47 40 49 36 48 C32 47 30 44 30 40Z" fill="#A8C686"/>
<circle cx="38" cy="38" r="36" fill="none" stroke="#D6B36A" stroke-width="1.5"/>
</svg>''';

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(text, style: BrText.ui(12, color: Br.textMuted)),
      ]);
}

class _DataButton extends StatelessWidget {
  const _DataButton(
      {required this.icon, required this.title, required this.subtitle, required this.onTap});
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BrIcon(icon, size: 22, color: Br.green),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BrText.ui(14, weight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrText.ui(11.5, color: Br.textMuted)),
              ]),
            ],
          ),
        ),
      );
}

class _MapStyleOption extends StatelessWidget {
  const _MapStyleOption({
    required this.style,
    required this.label,
    required this.selected,
    required this.fog,
    required this.onTap,
  });
  final MapStyle style;
  final String label;
  final bool selected;
  final Color fog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, road, blob) = switch (style) {
      MapStyle.claro => (Br.mapBlock, Colors.white, fog),
      MapStyle.oscuro => (const Color(0xFF18221E), const Color(0xFF34443C), const Color(0xFF4A504D)),
      MapStyle.topo => (const Color(0xFF1B2621), Colors.transparent, Colors.transparent),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? Br.green : Br.outline, width: selected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              if (style == MapStyle.topo)
                Positioned.fill(
                  child: SvgPicture.string(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 110 64" preserveAspectRatio="none"><g fill="none" stroke="#536D50"><path d="M-5 20 C30 8 60 30 115 14"/><path d="M-5 34 C30 22 60 44 115 28"/><path d="M-5 48 C30 36 60 58 115 42"/></g></svg>',
                    fit: BoxFit.fill,
                  ),
                )
              else ...[
                Positioned(left: 28, top: 0, bottom: 0, child: Container(width: 6, color: road)),
                Positioned(left: 0, right: 0, top: 30, child: Container(height: 5, color: road)),
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: blob, shape: BoxShape.circle)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: BrText.ui(12,
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Br.text : Br.textMuted)),
        ]),
      ),
    );
  }
}
