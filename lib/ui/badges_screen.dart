import 'package:flutter/material.dart';

import '../app_state.dart';
import '../game/progress.dart';
import 'format.dart';
import 'moments.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Insignias": the 28 badges, by family. Locked ones show their goal and
/// progress, never a mute padlock.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  BadgeFamily? _family;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final s = widget.state;
    final st = s.stats;
    final got = s.unlocked.length;
    final list = badges.where((b) => _family == null || b.family == _family).toList()
      ..sort((a, b) {
        final ua = s.unlocked[a.id], ub = s.unlocked[b.id];
        if (ua != null && ub != null) return ub.compareTo(ua);
        if (ua != null) return -1;
        if (ub != null) return 1;
        return b.progress(st).compareTo(a.progress(st));
      });
    final top = MediaQuery.paddingOf(context).top;

    return Stack(children: [
      CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, top + 28, 20, 0),
          sliver: SliverList.list(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Insignias', style: BrText.display(40)),
              const Spacer(),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$got'),
                  TextSpan(text: ' / ${badges.length}', style: BrText.display(18, color: Br.textMuted)),
                ]),
                style: BrText.display(30, color: Br.gold),
              ),
            ]),
            const SizedBox(height: 14),
            BrBar(value: got / badges.length, height: 6),
            const SizedBox(height: 14),
          ]),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              BrChip('Todas', selected: _family == null, onTap: () => setState(() => _family = null)),
              for (final f in BadgeFamily.values)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: BrChip(
                    f.label,
                    selected: _family == f,
                    leading: FamilyGlyph(f,
                        size: 11, color: _family == f ? Br.bg : Br.textSoft),
                    onTap: () => setState(() => _family = _family == f ? null : f),
                  ),
                ),
            ]),
          ),
        ),
        if (_family != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                  '${_family!.subtitle} · ${list.where((b) => s.unlocked.containsKey(b.id)).length} / ${list.length}',
                  style: BrText.ui(12, color: Br.textMuted)),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              mainAxisExtent: 150,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _BadgeCell(
                badge: list[i],
                unlockedAt: s.unlocked[list[i].id],
                stats: st,
                onTap: () => BadgeSheet.show(context, s, list[i]),
              ),
              childCount: list.length,
            ),
          ),
        ),
      ]),
      const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade()),
    ]);
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({
    required this.badge,
    required this.unlockedAt,
    required this.stats,
    required this.onTap,
  });
  final Achievement badge;
  final int? unlockedAt;
  final Stats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = unlockedAt != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(children: [
        BadgeArt(badge, earned: on),
        const SizedBox(height: 6),
        Text(badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BrText.ui(12.5,
                weight: FontWeight.w700, height: 1.25, color: on ? Br.text : Br.textSoft)),
        const SizedBox(height: 6),
        if (on)
          Text(fmtDate(DateTime.fromMillisecondsSinceEpoch(unlockedAt!)),
              style: BrText.ui(11, color: Br.textMuted))
        else ...[
          SizedBox(
            width: 64,
            child: BrBar(value: badge.progress(stats), height: 3, color: Br.green),
          ),
          const SizedBox(height: 6),
          Text(badge.label(stats),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrText.ui(11, color: Br.textMuted)),
        ],
      ]),
    );
  }
}
