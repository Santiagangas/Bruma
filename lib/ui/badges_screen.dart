import 'package:flutter/material.dart';

import '../app_state.dart';
import '../game/progress.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final xp = state.xp;
        final lvl = levelFor(xp);
        final from = xpForLevel(lvl), to = xpForLevel(lvl + 1);
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Logros')),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nivel $lvl', style: text.headlineMedium),
                        Text(titleFor(lvl), style: text.titleMedium),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (xp - from) / (to - from),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text('$xp XP · faltan ${to - xp} para el nivel '
                            '${lvl + 1}'),
                        const SizedBox(height: 8),
                        Text(
                          'XP: 1 por celda despejada, 50 por lugar, 200 por '
                          'ciudad nueva y 100 por insignia.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                      'Insignias ${state.unlocked.length}/${badges.length}',
                      style: text.titleMedium),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                  children: [
                    for (final b in badges)
                      _BadgeTile(badge: b, unlockedAt: state.unlocked[b.id]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlockedAt});
  final Achievement badge;
  final int? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final on = unlockedAt != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final d = on ? DateTime.fromMillisecondsSinceEpoch(unlockedAt!) : null;
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(badge.icon, size: 40),
            title: Text(badge.name),
            content: Text(on
                ? '${badge.description}\n\nConseguida el '
                    '${d!.day}/${d.month}/${d.year}.'
                : badge.description),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor:
                on ? const Color(0xFFFFD54F) : const Color(0xFF2A2F45),
            child: Icon(on ? badge.icon : Icons.lock,
                color: on ? Colors.black : Colors.white38, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(color: on ? null : Colors.white54),
          ),
        ],
      ),
    );
  }
}
