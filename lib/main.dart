import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/badges_screen.dart';
import 'ui/map_screen.dart';
import 'ui/places_screen.dart';
import 'ui/progress_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  unawaited(state.init());
  runApp(BrumaApp(state: state));
}

class BrumaApp extends StatelessWidget {
  const BrumaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bruma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6EC6CA),
        scaffoldBackgroundColor: const Color(0xFF12172A),
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.ready
            ? HomeShell(state: state)
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription<GameEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = widget.state.events.listen(_showEvent);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _showEvent(GameEvent e) {
    final icon = switch (e.kind) {
      EventKind.badge => Icons.military_tech,
      EventKind.place => Icons.help_center,
      EventKind.level => Icons.trending_up,
      EventKind.city => Icons.location_city,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      content: Row(children: [
        Icon(icon, color: const Color(0xFFFFD54F)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(e.subtitle),
            ],
          ),
        ),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          MapScreen(state: s),
          PlacesScreen(state: s),
          BadgesScreen(state: s),
          ProgressScreen(state: s),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.place), label: 'Lugares'),
          NavigationDestination(
              icon: Icon(Icons.military_tech), label: 'Logros'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Progreso'),
        ],
      ),
    );
  }
}
