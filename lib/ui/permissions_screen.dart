import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../settings.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Sigue explorando con el teléfono en el bolsillo": asks for location,
/// first while using the app and then all the time.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.settings, this.fromProfile = false});
  final Settings settings;
  final bool fromProfile;

  static Route<void> route(Settings settings, {bool fromProfile = false}) => MaterialPageRoute(
      builder: (_) => PermissionsScreen(settings: settings, fromProfile: fromProfile));

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  LocationPermission? _perm;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Geolocator.checkPermission().then((p) {
      if (mounted) setState(() => _perm = p);
    }).catchError((Object _) {});
  }

  void _done() {
    if (widget.fromProfile) {
      Navigator.of(context).pop();
    } else {
      // Leaving onboarding: the app shell replaces it.
      widget.settings.finishOnboarding();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _request({required bool always}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else if (always && p == LocationPermission.whileInUse) {
        // Android shows "Allow all the time" in Settings on this second ask.
        p = await Geolocator.requestPermission();
      }
      widget.settings.setBackground(always);
      if (mounted) setState(() => _perm = p);
    } catch (_) {
      // Ignore: the app keeps working and asks again when exploring.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final step1 = _perm == LocationPermission.whileInUse || _perm == LocationPermission.always;
    final step2 = _perm == LocationPermission.always;
    Widget step(int n, String title, String body, bool done, bool current) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: current || done ? Br.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: current || done ? null : Border.all(color: Br.outline),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: current || done ? Br.green : Colors.transparent,
                shape: BoxShape.circle,
                border: current || done ? null : Border.all(color: Br.greenDeep, width: 1.5),
              ),
              alignment: Alignment.center,
              child: done
                  ? const BrIcon('<path d="m6 12 4 4 8-8"/>', size: 16, color: Br.bg, stroke: 2.4)
                  : Text('$n',
                      style: BrText.ui(13,
                          weight: FontWeight.w800, color: current ? Br.bg : Br.green)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BrText.ui(14, weight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(body, style: BrText.ui(12, color: Br.textMuted)),
              ]),
            ),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(offset: const Offset(-10, 0), child: const BackArrow()),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 168,
                    child: Stack(children: [
                      Positioned.fill(child: CustomPaint(painter: _PocketArt())),
                      Positioned(
                        right: 16,
                        top: 16,
                        bottom: 16,
                        width: 92,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0F0D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Br.outline, width: 1.5),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const BrIcon(BrIcons.lock, size: 22, color: Br.textMuted),
                            const SizedBox(height: 8),
                            Text('PANTALLA\nAPAGADA',
                                textAlign: TextAlign.center,
                                style: BrText.mono(10).copyWith(height: 1.4)),
                            const SizedBox(height: 8),
                            Text('+0,004 km²',
                                style: BrText.ui(10, weight: FontWeight.w700, color: Br.green)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 26),
                Text('Sigue explorando con el teléfono en el bolsillo',
                    style: BrText.display(36, height: 1.05)),
                const SizedBox(height: 12),
                Text(
                    'Para despejar la niebla mientras caminas con la pantalla apagada, Bruma necesita tu ubicación también en segundo plano. Solo se usa durante una sesión de exploración que tú inicias.',
                    style: BrText.ui(15, color: Br.textCalm, height: 1.5)),
                const SizedBox(height: 22),
                step(1, 'Mientras usas la app', 'Ventana de Android · ubicación precisa', step1, !step1),
                const SizedBox(height: 12),
                step(2, 'Permitir todo el tiempo', 'Android te llevará a Ajustes para elegirlo', step2,
                    step1 && !step2),
                const SizedBox(height: 12),
                Row(children: [
                  const BrIcon(BrIcons.info, size: 16, color: Br.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Verás una notificación fija “Bruma está explorando” mientras dure la sesión.',
                        style: BrText.ui(12, color: Br.textMuted, height: 1.4)),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(children: [
              PrimaryButton(step2 ? 'Continuar' : 'Permitir ubicación',
                  onPressed: _busy ? null : () => step2 ? _done() : _request(always: true)),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: Center(
                  child: TextAction('Solo con la app abierta',
                      onPressed: _busy ? null : () => _request(always: false)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A path that keeps clearing fog with the screen off.
class _PocketArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Br.mapBlock);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    for (final y in [108.0, 70.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
    for (final x in [60.0, 140.0, 220.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Br.fog);
    final holes = Path();
    for (final (x, y) in const [(40.0, 120.0), (62.0, 112.0), (84.0, 104.0), (106.0, 98.0), (128.0, 92.0), (150.0, 88.0)]) {
      holes.addOval(Rect.fromCircle(center: Offset(x, y), radius: 20));
    }
    canvas.drawPath(holes, Paint()..blendMode = BlendMode.dstOut);
    canvas.restore();
    final trail = Paint()
      ..color = Br.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(150, 88)
      ..cubicTo(170, 84, 186, 80, 204, 76);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3, m.length)), trail);
      }
    }
    canvas.drawCircle(const Offset(150, 88), 6.25, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(150, 88), 3.75, Paint()..color = Br.bg);
  }

  @override
  bool shouldRepaint(_PocketArt old) => false;
}
