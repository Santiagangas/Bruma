import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'settings.dart';
import 'ui/badges_screen.dart';
import 'ui/discover_screen.dart';
import 'ui/icons.dart';
import 'ui/map_screen.dart';
import 'ui/moments.dart';
import 'ui/onboarding.dart';
import 'ui/place_screen.dart';
import 'ui/profile_screen.dart';
import 'ui/progress_screen.dart';
import 'ui/stats_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Br.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final state = AppState();
  final settings = Settings();
  unawaited(settings.load().then((_) => state.init()));
  runApp(BrumaApp(state: state, settings: settings));
}

class BrumaApp extends StatelessWidget {
  const BrumaApp({super.key, required this.state, required this.settings});
  final AppState state;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bruma',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: Listenable.merge([state, settings]),
        builder: (context, _) {
          if (!state.ready) return const _Splash();
          if (!settings.onboarded) return Onboarding(settings: settings);
          return HomeShell(state: state, settings: settings);
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Br.bg,
        body: Center(child: Text('Bruma', style: BrText.display(56))),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state, required this.settings});
  final AppState state;
  final Settings settings;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _stats = false;
  StreamSubscription<GameEvent>? _events;
  final _queue = Queue<GameEvent>();
  bool _showing = false;
  bool _foreground = true;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = s.events.listen((e) {
      _queue.add(e);
      _pump();
    });
    s.focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    s.focus.removeListener(_onFocus);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _pump();
  }

  void _onFocus() {
    if (s.focus.value != null && _tab != 0) setState(() => _tab = 0);
  }

  void _openTab(int i) {
    setState(() {
      if (i == 2 && _tab == 2) _stats = false;
      _tab = i;
    });
    if (i == 3) widget.settings.markBadgesSeen(s.unlocked.keys);
  }

  void _openStats() => setState(() {
        _tab = 2;
        _stats = true;
      });

  /// Shows queued moments one after another, only while the app is open.
  Future<void> _pump() async {
    if (_showing || !_foreground || !mounted) return;
    _showing = true;
    try {
      while (_queue.isNotEmpty && mounted && _foreground) {
        final e = _queue.removeFirst();
        if (!widget.settings.notices) {
          _toast(e);
          continue;
        }
        if (!mounted) return;
        final nav = Navigator.of(context);
        switch (e.kind) {
          case EventKind.place:
            await nav.push(DiscoveryMoment.route(s, e.poi!, e.xp));
          case EventKind.level:
            await nav.push(LevelMoment.route(s, e.level!));
          case EventKind.city:
            await nav.push(CityMoment.route(s, e.city!));
          case EventKind.badge:
            if (!mounted) return;
            await BadgeSheet.show(context, s, e.badge!,
                fresh: true, onCollection: () => _openTab(3));
        }
      }
    } finally {
      _showing = false;
    }
  }

  /// Compact notice used when "Avisos de descubrimientos" is off.
  void _toast(GameEvent e) {
    final (icon, text) = switch (e.kind) {
      EventKind.place => (e.poi!.info.icon, e.poi!.name),
      EventKind.badge => (BrIcons.badges, 'Insignia: ${e.badge!.name}'),
      EventKind.level => (BrIcons.progress, 'Nivel ${e.level}'),
      EventKind.city => (BrIcons.pin, 'Nuevo territorio: ${e.city!.name}'),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      content: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: Br.gold, shape: BoxShape.circle),
          child: Center(child: BrIcon(icon, size: 14, color: Br.bg, stroke: 2.4)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: BrText.ui(13, weight: FontWeight.w600))),
        if (e.xp > 0)
          Text('+${e.xp} XP', style: BrText.ui(13, weight: FontWeight.w800, color: Br.gold)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    PlaceScreen.style = settings.mapStyle;
    return ListenableBuilder(
      listenable: Listenable.merge([s, settings]),
      builder: (context, _) {
        final unseen = !settings.seenBadges.containsAll(s.unlocked.keys);
        if (_tab == 3 && unseen) {
          WidgetsBinding.instance.addPostFrameCallback((_) => settings.markBadgesSeen(s.unlocked.keys));
        }
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              MapScreen(
                state: s,
                settings: settings,
                onOpenTab: _openTab,
                onOpenStats: _openStats,
              ),
              DiscoverScreen(state: s, onShowMap: () => _openTab(0)),
              _stats
                  ? StatsScreen(
                      state: s, settings: settings, onBack: () => setState(() => _stats = false))
                  : ProgressScreen(state: s, settings: settings, onOpenStats: _openStats),
              BadgesScreen(state: s),
              ProfileScreen(state: s, settings: settings, onOpenBadges: () => _openTab(3)),
            ],
          ),
          bottomNavigationBar: BrNavBar(
            index: _tab,
            onTap: _openTab,
            dots: {if (unseen && _tab != 3) 3},
          ),
        );
      },
    );
  }
}
