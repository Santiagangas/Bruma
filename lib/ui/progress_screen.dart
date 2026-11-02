import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../game/progress.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.state});
  final AppState state;

  void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context) async {
    try {
      final json = await state.exportJson();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final file = File(p.join(dir.path,
          'bruma-respaldo-${now.year}-${now.month}-${now.day}.json'));
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)], title: 'Respaldo de Bruma'));
    } catch (e) {
      if (context.mounted) _toast(context, 'No se pudo exportar: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) return;
      await state.importJson(await File(path).readAsString());
      if (context.mounted) _toast(context, 'Respaldo importado.');
    } catch (e) {
      if (context.mounted) _toast(context, 'No se pudo importar: $e');
    }
  }

  Future<void> _wipe(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todo?'),
        content: const Text(
            'Se borrarán el mapa explorado, los lugares, las insignias y el '
            'nivel. No se puede deshacer. Exporta un respaldo antes si '
            'quieres conservarlo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) {
      await state.wipe();
      if (context.mounted) _toast(context, 'Datos borrados.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.stats;
        final km2 = state.exploredKm2;
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Progreso')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Stat('Área explorada', '${km2.toStringAsFixed(3)} km²'),
                  _Stat('Celdas despejadas', '${s.cells}'),
                  _Stat('Distancia', '${s.distanceKm.toStringAsFixed(1)} km'),
                  _Stat('Lugares', '${s.pois}'),
                  _Stat('Mejor racha', '${s.bestStreak} días'),
                  _Stat('Días explorando', '${state.days.length}'),
                  _Stat('Del mundo', formatPercent(state.worldPercent)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Ciudades', style: text.titleLarge),
              const SizedBox(height: 8),
              if (state.cities.isEmpty)
                const Text('Explora para identificar tu primera ciudad.'),
              for (final c in state.cities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(c.name, style: text.titleMedium)),
                        Text(formatPercent(state.cityPercent(c))),
                      ]),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: state.cityPercent(c) / 100,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          '${(c.area / 1e6).toStringAsFixed(1)} km² en total',
                          style: text.bodySmall),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text('Tus datos', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Todo se guarda solo en este teléfono. Exporta un respaldo de '
                'vez en cuando para no perder tu progreso si cambias de '
                'teléfono o desinstalas la app.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.tonalIcon(
                  onPressed: () => _export(context),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Exportar respaldo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Importar respaldo'),
                ),
                TextButton.icon(
                  onPressed: () => _wipe(context),
                  icon: const Icon(Icons.delete_forever,
                      color: Colors.redAccent),
                  label: const Text('Borrar todo',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: text.titleLarge),
              const SizedBox(height: 4),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
