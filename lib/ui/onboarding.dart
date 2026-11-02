import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../settings.dart';
import 'icons.dart';
import 'permissions_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// First run: three pages, then the location permission.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.settings});
  final Settings settings;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _pages = PageController();
  int _page = 0;

  void _go(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 400), curve: Br.curve);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page == 0 ? Br.fog : Br.bg,
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _Page1(onNext: () => _go(1), onSkip: () => _go(2)),
          _Page2(onNext: () => _go(2), onSkip: () => _go(2)),
          _Page3(
              onStart: () =>
                  Navigator.of(context).push(PermissionsScreen.route(widget.settings))),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onSkip, this.step});
  final VoidCallback? onSkip;
  final String? step;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, math.max(MediaQuery.paddingOf(context).top, 24) + 20, 24, 0),
        child: Row(children: [
          Text('Bruma', style: BrText.display(30)),
          const Spacer(),
          if (onSkip != null)
            InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Text('Omitir', style: BrText.ui(14, weight: FontWeight.w700)),
              ),
            ),
          if (step != null) MonoLabel(step!),
        ]),
      );
}

class _Dots extends StatelessWidget {
  const _Dots(this.index, {this.inactive = Br.greenDeep});
  final int index;
  final Color inactive;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Paso ${index + 1} de 3',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == index ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? Br.green : inactive,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ]),
      );
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.step,
    required this.title,
    required this.body,
    required this.index,
    required this.onNext,
    this.stepColor = Br.textMuted,
    this.bodyColor = Br.textCalm,
    this.dotColor = Br.greenDeep,
  });
  final String step;
  final String title;
  final String body;
  final int index;
  final VoidCallback onNext;
  final Color stepColor;
  final Color bodyColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(28, 0, 28, 40 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MonoLabel(step, color: stepColor),
            const SizedBox(height: 18),
            Text(title, style: BrText.display(46, height: 1.02, spacing: -0.46)),
            const SizedBox(height: 18),
            Text(body, style: BrText.ui(16, color: bodyColor, height: 1.5)),
            const SizedBox(height: 28),
            Row(children: [
              _Dots(index, inactive: dotColor),
              const Spacer(),
              PrimaryButton('Siguiente',
                  expand: false, trailing: BrIcons.next, onPressed: onNext),
            ]),
          ],
        ),
      );
}

// Page 1 — "Tu mundo está cubierto de niebla."
class _Page1 extends StatelessWidget {
  const _Page1({required this.onNext, required this.onSkip});
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Br.fog,
      child: Stack(children: [
        Positioned.fill(
          child: SvgPicture.string(_fogArt, fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            // The "you are here" mark sits in the middle of the contours.
            final k = c.maxWidth / 390;
            return Stack(children: [
              Positioned(
                left: 172 * k,
                top: 372 * k,
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CustomPaint(
                    painter: _Dashed(const Color(0xFF8A918D)),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Br.text,
                          shape: BoxShape.circle,
                          border: Border.all(color: Br.green, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 150 * k,
                top: 444 * k,
                width: 104,
                child: Text('ESTÁS AQUÍ',
                    textAlign: TextAlign.center,
                    style: BrText.mono(11, color: Br.textOnFog, tracking: .12)),
              ),
            ]);
          }),
        ),
        _TopBar(onSkip: onSkip),
        Align(
          alignment: Alignment.bottomCenter,
          child: _Bottom(
            step: '01 / 03',
            title: 'Tu mundo está cubierto de niebla.',
            body: 'Todo lo que aún no has pisado permanece oculto. Incluso la calle de al lado.',
            index: 0,
            onNext: onNext,
            stepColor: Br.textOnFog,
            bodyColor: Br.textSoft,
            dotColor: const Color(0xFF6A706D),
          ),
        ),
      ]),
    );
  }
}

const _fogArt = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 390 844">
<g fill="none" stroke="#4A504D" stroke-width="1">
<path d="M-20 120 C60 90 120 150 200 120 C280 90 330 130 410 104"/>
<path d="M-20 150 C60 122 124 180 204 150 C284 120 334 162 410 136"/>
<path d="M-20 184 C64 158 130 214 210 184 C290 154 336 196 410 172"/>
<path d="M95 400 C95 320 160 280 220 290 C290 300 320 360 310 420 C300 490 230 520 170 505 C120 492 95 455 95 400Z"/>
<path d="M125 400 C125 342 170 314 215 322 C266 330 286 372 279 415 C272 466 222 486 178 476 C142 467 125 440 125 400Z"/>
<path d="M155 400 C155 365 180 346 210 352 C242 358 254 383 249 410 C244 440 216 452 188 446 C166 441 155 424 155 400Z"/>
<path d="M183 400 C183 386 194 378 206 380 C219 383 224 394 222 405 C220 418 208 423 197 420 C189 418 183 410 183 400Z"/>
<path d="M-20 640 C70 610 140 668 230 636 C300 610 350 640 410 620"/>
<path d="M-20 672 C74 644 144 702 234 670 C304 644 352 674 410 654"/>
</g>
<path fill="none" stroke="#464C49" stroke-width="0.75" stroke-dasharray="2 5" d="M130 0 V844"/><path fill="none" stroke="#464C49" stroke-width="0.75" stroke-dasharray="2 5" d="M260 0 V844"/><path fill="none" stroke="#464C49" stroke-width="0.75" stroke-dasharray="2 5" d="M0 281 H390"/><path fill="none" stroke="#464C49" stroke-width="0.75" stroke-dasharray="2 5" d="M0 562 H390"/>
<path fill="none" stroke="#5A605D" stroke-width="1" d="M126 281 h8 M130 277 v8 M256 281 h8 M260 277 v8 M126 562 h8 M130 558 v8 M256 562 h8 M260 558 v8"/>
</svg>''';

class _Dashed extends CustomPainter {
  _Dashed(this.color, {this.width = 1});
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) => dashedCircle(
      canvas,
      size.center(Offset.zero),
      size.width / 2 - width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
      dash: 3,
      gap: 3);

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}

// Page 2 — "Cada paso revela un nuevo territorio."
class _Page2 extends StatelessWidget {
  const _Page2({required this.onNext, required this.onSkip});
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final k = c.maxWidth / 390;
      return Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 540 * k,
          child: Semantics(
            label: 'Un círculo de 30 metros despejado en la niebla deja ver calles y cuadras',
            child: CustomPaint(painter: _RevealArt()),
          ),
        ),
        Positioned(
          left: 222 * k,
          top: 278 * k,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Br.bg, borderRadius: BorderRadius.circular(8)),
            child: Text('30 m', style: BrText.mono(12, color: Br.text)),
          ),
        ),
        Positioned(
          left: 248 * k,
          top: 92 * k,
          child: SizedBox(
            width: 84 * k,
            height: 84 * k,
            child: CustomPaint(painter: _Dashed(const Color(0xFF8A918D), width: 1.5)),
          ),
        ),
        Positioned(
          left: 238 * k,
          top: 186 * k,
          width: 104 * k,
          child: Text('TU PRÓXIMO PASO',
              textAlign: TextAlign.center,
              style: BrText.mono(10, color: Br.textOnFog, tracking: .12)),
        ),
        _TopBar(onSkip: onSkip),
        Positioned.fill(
          top: 500 * k,
          child: Container(
            decoration: const BoxDecoration(
              color: Br.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _Bottom(
            step: '02 / 03',
            title: 'Cada paso revela un nuevo territorio.',
            body: 'Al caminar despejas un círculo perfecto de 30 metros. Calle a calle, tu mapa se vuelve real.',
            index: 1,
            onNext: onNext,
          ),
        ),
      ]);
    });
  }
}

class _RevealArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 390;
    canvas.scale(k);
    const rect = Rect.fromLTWH(0, 0, 390, 540);
    canvas.clipRect(rect);
    const c = Offset(195, 300);

    // Light map, rotated like the design.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-12 * math.pi / 180);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawRect(const Rect.fromLTWH(-200, -200, 800, 900), Paint()..color = const Color(0xFFFBFBF7));
    final block = Paint()..color = Br.mapBlock;
    final inner = Paint()..color = const Color(0xFFDCDFD3);
    for (var x = -200.0; x < 600; x += 92) {
      for (var y = -200.0; y < 700; y += 68) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 6, y + 6, 80, 56), const Radius.circular(4)), block);
        for (final r in const [
          Rect.fromLTWH(12, 12, 28, 20),
          Rect.fromLTWH(46, 12, 34, 16),
          Rect.fromLTWH(12, 38, 20, 18),
          Rect.fromLTWH(38, 34, 42, 22),
        ]) {
          canvas.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(x, y)), const Radius.circular(2)), inner);
        }
      }
    }
    final road = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(175, -200, 18, 900), road);
    canvas.drawRect(const Rect.fromLTWH(-200, 264, 800, 16), road);
    final tp = TextPainter(
      text: TextSpan(
          text: 'CALLE 53',
          style: BrText.ui(10, weight: FontWeight.w700, color: Br.mapInk).copyWith(letterSpacing: 1.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(120 - tp.width / 2, 272 - tp.height / 2));
    canvas.restore();

    // Fog with one opening, green edge and soft shadow.
    final hole = Path()..addOval(Rect.fromCircle(center: c, radius: 104));
    final edge = Path()..addOval(Rect.fromCircle(center: c, radius: 106));
    final cut = Paint()..blendMode = BlendMode.dstOut;
    canvas.saveLayer(rect, Paint()..imageFilter = _blur);
    canvas.translate(0, 3);
    canvas.drawRect(rect.inflate(10), Paint()..color = const Color(0x80000000));
    canvas.drawPath(hole, cut);
    canvas.restore();
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Br.green);
    canvas.drawPath(hole, cut);
    canvas.restore();
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Br.fog);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Br.fogLine;
    for (final pts in const [
      [-20.0, 90.0, 60.0, 60.0, 140.0, 120.0, 220.0, 90.0, 300.0, 60.0, 340.0, 100.0, 410.0, 80.0],
      [-20.0, 124.0, 64.0, 96.0, 144.0, 154.0, 224.0, 124.0, 304.0, 94.0, 344.0, 134.0, 410.0, 114.0],
      [-20.0, 470.0, 70.0, 440.0, 150.0, 500.0, 230.0, 470.0, 310.0, 440.0, 350.0, 480.0, 410.0, 460.0],
      [-20.0, 504.0, 74.0, 476.0, 154.0, 534.0, 234.0, 504.0, 314.0, 474.0, 354.0, 514.0, 410.0, 494.0],
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(pts[0], pts[1])
            ..cubicTo(pts[2], pts[3], pts[4], pts[5], pts[6], pts[7])
            ..cubicTo(pts[8], pts[9], pts[10], pts[11], pts[12], pts[13]),
          line);
    }
    canvas.drawPath(edge, cut);
    canvas.restore();

    // Radius and you.
    final dash = Paint()
      ..color = Br.bg
      ..strokeWidth = 1.5;
    for (var x = 195.0; x < 299; x += 7) {
      canvas.drawLine(Offset(x, 300), Offset(math.min(x + 3, 299), 300), dash);
    }
    canvas.drawCircle(c, 8.5, Paint()..color = Colors.white);
    canvas.drawCircle(c, 5.5, Paint()..color = Br.bg);
  }

  static final _blur = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5);

  @override
  bool shouldRepaint(_RevealArt old) => false;
}

// Page 3 — "Tu aventura empieza aquí."
class _Page3 extends StatelessWidget {
  const _Page3({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    Widget point(String icon, String title, String body) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Br.surface, borderRadius: BorderRadius.circular(12)),
              child: Center(child: BrIcon(icon, size: 20, color: Br.green)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BrText.ui(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: BrText.ui(13, color: Br.textMuted, height: 1.45)),
              ]),
            ),
          ],
        );
    return Column(children: [
      const _TopBar(step: '03 / 03'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 20),
          children: [
            Center(
              child: SvgPicture.string(_phoneArt, width: 200, height: 150),
            ),
            const SizedBox(height: 36),
            Text('Tu aventura empieza aquí.', style: BrText.display(46, height: 1.02, spacing: -0.46)),
            const SizedBox(height: 14),
            Text('Bruma es solo tuya. Nadie más ve tu mapa.',
                style: BrText.ui(16, color: Br.textCalm, height: 1.5)),
            const SizedBox(height: 26),
            point(BrIcons.database, 'Todo se guarda en tu teléfono',
                'Tu recorrido vive en una base de datos local. Tú decides cuándo exportarlo.'),
            const SizedBox(height: 18),
            point(BrIcons.noAccount, 'Sin cuentas, sin seguidores',
                'No hay registro, ni clasificaciones, ni servidores propios.'),
            const SizedBox(height: 18),
            point(BrIcons.map, 'Mapas de OpenStreetMap',
                'Se descargan teselas para dibujar el mapa; tu ruta nunca sale del dispositivo.'),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(28, 0, 28, 40 + MediaQuery.paddingOf(context).bottom),
        child: Column(children: [
          const _Dots(2),
          const SizedBox(height: 14),
          PrimaryButton('Comenzar a explorar', onPressed: onStart),
        ]),
      ),
    ]);
  }
}

const _phoneArt = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 150">
<rect x="62" y="6" width="76" height="138" rx="16" fill="#1A2420" stroke="#3A4A42" stroke-width="1.5"/>
<rect x="70" y="20" width="60" height="96" rx="6" fill="#3B403E"/>
<circle cx="94" cy="58" r="16" fill="#E7E9E0"/><circle cx="110" cy="74" r="16" fill="#E7E9E0"/><circle cx="100" cy="92" r="14" fill="#E7E9E0"/>
<path d="M94 42 V108 M78 70 H124" stroke="#FFFFFF" stroke-width="3"/>
<rect x="86" y="124" width="28" height="4" rx="2" fill="#3A4A42"/>
<g transform="translate(130 92)"><circle cx="18" cy="18" r="20" fill="#101714"/><circle cx="18" cy="18" r="17" fill="#A8C686"/><rect x="11" y="17" width="14" height="11" rx="2" fill="#101714"/><path d="M13.5 17v-3a4.5 4.5 0 0 1 9 0v3" fill="none" stroke="#101714" stroke-width="2"/></g>
</svg>''';
