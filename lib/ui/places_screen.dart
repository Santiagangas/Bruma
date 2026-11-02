import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final found = state.pois.values
            .where((p) => p.discovered != null)
            .toList()
          ..sort((a, b) => b.discovered!.compareTo(a.discovered!));
        final total = state.pois.length;
        return Scaffold(
          appBar: AppBar(title: const Text('Lugares')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${found.length} descubiertos de $total lugares misteriosos '
                'cerca de donde has estado.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in poiCategories.entries)
                    Chip(
                      avatar: Icon(e.value.icon, color: e.value.color, size: 18),
                      label: Text('${e.value.label}: '
                          '${found.where((p) => p.category == e.key).length}'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (found.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Text(
                    'Aún no has descubierto ningún lugar. Busca los «?» en el '
                    'mapa y camina hasta ellos.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final p in found)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.info.color,
                    child: Icon(p.info.icon, color: Colors.black),
                  ),
                  title: Text(p.name),
                  subtitle: Text('${p.info.label} · ${_date(p.discovered!)}'),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }
}
