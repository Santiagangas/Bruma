import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/progress.dart';
import 'icons.dart';
import 'theme.dart';

// ------------------------------------------------------------------ buttons

/// Green main action: 56 high, radius 18, Manrope 800.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label,
      {super.key,
      required this.onPressed,
      this.icon,
      this.trailing,
      this.height = 56,
      this.radius = 18,
      this.fontSize = 16,
      this.color = Br.green,
      this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final String? trailing;
  final double height;
  final double radius;
  final double fontSize;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _ButtonBase(
      onPressed: onPressed,
      height: height,
      radius: radius,
      background: color,
      expand: expand,
      padding: EdgeInsets.symmetric(horizontal: expand ? 8 : 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            BrIcon(icon!, size: 20, color: Br.bg, stroke: 2),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: BrText.ui(fontSize, weight: FontWeight.w800, color: Br.bg)),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            BrIcon(trailing!, size: 18, color: Br.bg, stroke: 2.2),
          ],
        ],
      ),
    );
  }
}

/// Tonal button on #26332D.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label,
      {super.key,
      required this.onPressed,
      this.icon,
      this.height = 52,
      this.radius = 16,
      this.fontSize = 15,
      this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final double height;
  final double radius;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _ButtonBase(
      onPressed: onPressed,
      height: height,
      radius: radius,
      background: Br.surfaceHigh,
      expand: expand,
      padding: EdgeInsets.symmetric(horizontal: expand ? 8 : 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            BrIcon(icon!, size: 18, color: Br.text),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: BrText.ui(fontSize, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined button: deep green border, green text.
class OutlineButton extends StatelessWidget {
  const OutlineButton(this.label,
      {super.key, required this.onPressed, this.height = 48, this.radius = 16});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _ButtonBase(
      onPressed: onPressed,
      height: height,
      radius: radius,
      background: Colors.transparent,
      border: Border.all(color: Br.greenDeep),
      expand: true,
      child: Text(label,
          style: BrText.ui(14, weight: FontWeight.w700, color: Br.green)),
    );
  }
}

/// Text-only button (green, or salmon for destructive actions).
class TextAction extends StatelessWidget {
  const TextAction(this.label,
      {super.key, required this.onPressed, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return _ButtonBase(
      onPressed: onPressed,
      height: 44,
      radius: 14,
      background: Colors.transparent,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(label,
          style: BrText.ui(14,
              weight: FontWeight.w700, color: danger ? Br.danger : Br.green)),
    );
  }
}

class _ButtonBase extends StatelessWidget {
  const _ButtonBase({
    required this.onPressed,
    required this.height,
    required this.radius,
    required this.background,
    required this.child,
    required this.expand,
    this.border,
    this.padding = EdgeInsets.zero,
  });

  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final Color background;
  final Widget child;
  final bool expand;
  final BoxBorder? border;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: Container(
            height: height,
            width: expand ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(borderRadius: r, border: border),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Round or rounded-square icon button floating over the map.
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.label,
    this.size = 48,
    this.radius = 16,
    this.color = Br.bg,
    this.border = true,
    this.shadow = Br.shadowSmall,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final double radius;
  final Color color;
  final bool border;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Semantics(
      button: true,
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: shadow,
        ),
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: r,
            side: border ? const BorderSide(color: Br.border) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Plain back arrow (44 × 44).
class BackArrow extends StatelessWidget {
  const BackArrow({super.key, this.onTap, this.boxed = false});
  final VoidCallback? onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final tap = onTap ?? () => Navigator.of(context).maybePop();
    if (boxed) {
      return MapButton(
        label: 'Volver',
        onTap: tap,
        shadow: const [],
        border: false,
        child: const BrIcon(BrIcons.back, size: 22, stroke: 2),
      );
    }
    return Semantics(
      button: true,
      label: 'Volver',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(child: BrIcon(BrIcons.back, size: 22, stroke: 2)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ controls

/// Filter chip: 36 high, radius 10.
class BrChip extends StatelessWidget {
  const BrChip(this.label,
      {super.key, required this.selected, required this.onTap, this.leading});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(10);
    return Material(
      color: selected ? Br.green : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: selected ? BorderSide.none : const BorderSide(color: Br.outline),
      ),
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: leading == null ? 14 : 12),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(label,
                style: BrText.ui(13,
                    weight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Br.bg : Br.textSoft)),
          ]),
        ),
      ),
    );
  }
}

/// Switch from the design: 52 × 32, green when on, outlined when off.
class BrSwitch extends StatelessWidget {
  const BrSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Br.curve,
          width: 52,
          height: 32,
          decoration: BoxDecoration(
            color: value ? Br.green : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: value ? null : Border.all(color: Br.greenDeep, width: 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Br.curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: value ? 4 : 5),
              width: value ? 24 : 16,
              height: value ? 24 : 16,
              decoration: BoxDecoration(
                color: value ? Br.bg : Br.greenDeep,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control ("Días / Semanas / Meses", "km / mi").
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.background = Br.surface,
    this.height = 40,
    this.padding = 4,
    this.radius = 14,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color background;
  final double height;
  final double padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(radius)),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Br.curve,
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == value ? Br.surfaceHigh : Colors.transparent,
                  borderRadius: BorderRadius.circular(radius - padding),
                ),
                child: Text(label,
                    style: BrText.ui(13,
                        weight: v == value ? FontWeight.w700 : FontWeight.w600,
                        color: v == value ? Br.text : Br.textMuted)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Progress bar; [minWidth] keeps tiny values (1 %) visible.
class BrBar extends StatelessWidget {
  const BrBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = Br.gold,
    this.track = Br.surfaceHigh,
    this.minWidth = 0,
    this.extra,
    this.extraColor = Br.text,
  });

  final double value;
  final double height;
  final Color color;
  final Color track;
  final double minWidth;

  /// Optional second segment right after [value] (XP just earned).
  final double? extra;
  final Color extraColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final v = value.clamp(0.0, 1.0);
      final fill = v <= 0 && minWidth == 0 ? 0.0 : (w * v).clamp(minWidth, w);
      final ex = extra == null ? 0.0 : (w * extra!).clamp(0.0, w - fill);
      return Container(
        height: height,
        decoration: BoxDecoration(
            color: track, borderRadius: BorderRadius.circular(height / 2)),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        child: Row(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: fill),
            duration: const Duration(milliseconds: 700),
            curve: Br.curve,
            builder: (_, f, _) => Container(
              width: f,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: extra == null
                    ? BorderRadius.circular(height / 2)
                    : null,
              ),
            ),
          ),
          if (ex > 0) Container(width: ex, height: height, color: extraColor),
        ]),
      );
    });
  }
}

/// Grab handle at the top of sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: Br.outline, borderRadius: BorderRadius.circular(2)),
        ),
      );
}

/// Section label in IBM Plex Mono caps ("TUS DATOS").
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text,
      {super.key, this.size = 11, this.color = Br.textMuted, this.tracking = .16});
  final String text;
  final double size;
  final Color color;
  final double tracking;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: BrText.mono(size, color: color, tracking: tracking));
}

/// Card on the surface colour.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = Br.surface,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(borderRadius: r, border: border),
      child: child,
    );
    return Material(
      color: color,
      borderRadius: r,
      child: onTap == null
          ? content
          : InkWell(borderRadius: r, onTap: onTap, child: content),
    );
  }
}

/// Big serif figure with a small sans unit: "2,84 km²".
class Figure extends StatelessWidget {
  const Figure(this.value,
      {super.key,
      this.unit,
      this.size = 26,
      this.unitSize = 13,
      this.color = Br.text,
      this.height = 1.05});

  final String value;
  final String? unit;
  final double size;
  final double unitSize;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: value),
          if (unit != null)
            TextSpan(
                text: ' $unit',
                style: BrText.ui(unitSize, color: Br.textMuted)),
        ]),
        style: BrText.display(size, color: color, height: height),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

// ------------------------------------------------------------------- badges

String _shapePath(BadgeFamily f) => switch (f) {
      BadgeFamily.habitos => '<circle cx="32" cy="32" r="28"/>',
      BadgeFamily.distancia => '<path d="M32 4 56 18v28L32 60 8 46V18Z"/>',
      BadgeFamily.territorio =>
        '<rect x="13" y="13" width="38" height="38" rx="8" transform="rotate(45 32 32)"/>',
      BadgeFamily.hallazgos =>
        '<path d="M21 5h22l16 16v22L43 59H21L5 43V21Z"/>',
    };

String _innerPath(BadgeFamily f) => switch (f) {
      BadgeFamily.habitos => '<circle cx="32" cy="32" r="23"/>',
      BadgeFamily.distancia => '<path d="M32 10 51 21v22L32 54 13 43V21Z"/>',
      BadgeFamily.hallazgos =>
        '<path d="M23 11h18l12 12v18L41 53H23L11 41V23Z"/>',
      BadgeFamily.territorio => '',
    };

/// Outline of a family shape, used in filter chips and section headers.
class FamilyGlyph extends StatelessWidget {
  const FamilyGlyph(this.family,
      {super.key, this.size = 11, this.color = Br.textSoft, this.stroke = 1.5});
  final BadgeFamily family;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    // Stroke is given in output pixels; the shape is drawn on a 64 grid.
    final sw = stroke * 64 / size;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" '
      'stroke="$hex" stroke-width="$sw">${_shapePath(family)}</svg>',
      width: size,
      height: size,
    );
  }
}

/// A badge: gold when earned, dashed silhouette when locked.
class BadgeArt extends StatelessWidget {
  const BadgeArt(this.badge,
      {super.key, required this.earned, this.size = 68, this.inner = true});

  final Achievement badge;
  final bool earned;
  final double size;

  /// Draw the thin inner outline on earned badges with a text glyph.
  final bool inner;

  @override
  Widget build(BuildContext context) {
    final glyph = earned ? Br.bg : Br.greenDeep;
    final shape = earned
        ? '<g fill="#D6B36A">${_shapePath(badge.family)}</g>'
            '${inner && badge.text != null ? '<g fill="none" stroke="#101714" stroke-opacity=".25">${_innerPath(badge.family)}</g>' : ''}'
        : '<g fill="#161F1B" stroke="#536D50" stroke-width="1.5" stroke-dasharray="4 3">${_shapePath(badge.family)}</g>';
    final k = size / 64;
    Widget? content;
    if (badge.icon != null) {
      final iconSize = (badge.family == BadgeFamily.territorio ? 24 : 28) * k;
      content = BrIcon(badge.icon!, size: iconSize, color: glyph);
    } else if (badge.text != null) {
      final t = badge.text!;
      final fs = t == '?'
          ? 30.0
          : t.contains('%')
              ? 18.0
              : t.length == 1
                  ? (badge.unit == null ? 27.0 : 22.0)
                  : t.length == 2
                      ? (badge.unit == null &&
                              badge.family == BadgeFamily.habitos
                          ? 26.0
                          : 22.0)
                      : (badge.family == BadgeFamily.habitos ? 21.0 : 20.0);
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t,
            style: BrText.display(fs * k, color: glyph, height: 1),
            textAlign: TextAlign.center),
        if (badge.unit != null)
          Padding(
            padding: EdgeInsets.only(top: 1 * k),
            child: Text(badge.unit!,
                style: BrText.ui(
                    (badge.unit == 'KM²' ? 6.5 : 7) * k,
                    weight: FontWeight.w800,
                    color: glyph,
                    height: 1)),
          ),
      ]);
    }
    return Semantics(
      label: '${badge.name}, ${earned ? 'obtenida' : 'bloqueada'}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SvgPicture.string(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">$shape</svg>',
            width: size,
            height: size,
          ),
          if (content != null)
            Padding(
              padding: EdgeInsets.only(top: badge.unit != null ? 2 * k : 2 * k),
              child: content,
            ),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------------- map markers

/// A place still hidden by the fog. [near] when within 150 m, [far] when
/// well beyond reach.
class MysteryMarker extends StatelessWidget {
  const MysteryMarker({super.key, this.near = false, this.far = false});
  final bool near;
  final bool far;

  @override
  Widget build(BuildContext context) {
    final size = near ? 44.0 : far ? 30.0 : 36.0;
    final marker = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Br.bg,
        shape: BoxShape.circle,
        boxShadow: far
            ? null
            : [
                BoxShadow(
                    color: const Color(0x66101714),
                    blurRadius: near ? 12 : 8,
                    offset: Offset(0, near ? 4 : 3)),
              ],
      ),
      child: CustomPaint(
        painter: _DashedRing(
          color: far ? Br.goldDim : Br.gold,
          width: near ? 2 : 1.5,
          dashed: !near,
        ),
        child: Center(
          child: Text('?',
              style: BrText.display(near ? 28 : far ? 19 : 23,
                  color: Br.gold, height: 1)),
        ),
      ),
    );
    if (!near) return Opacity(opacity: far ? 0.8 : 1, child: marker);
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Br.gold.withValues(alpha: .16),
        border: Border.all(color: Br.gold.withValues(alpha: .6)),
      ),
      child: marker,
    );
  }
}

class _DashedRing extends CustomPainter {
  _DashedRing({required this.color, required this.width, required this.dashed});
  final Color color;
  final double width;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final r = size.width / 2 - width / 2;
    final c = size.center(Offset.zero);
    if (!dashed) {
      canvas.drawCircle(c, r, paint);
      return;
    }
    dashedCircle(canvas, c, r, paint, dash: 3 * width, gap: 3 * width);
  }

  @override
  bool shouldRepaint(_DashedRing old) =>
      old.color != color || old.width != width || old.dashed != dashed;
}

/// Draws a dashed circle outline.
void dashedCircle(Canvas canvas, Offset c, double r, Paint paint,
    {double dash = 4, double gap = 4}) {
  final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, d + dash), paint);
      d += dash + gap;
    }
  }
}

/// A discovered place: gold seal with its category icon.
class FoundMarker extends StatelessWidget {
  const FoundMarker(this.icon, {super.key, this.size = 28});
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Br.gold,
          shape: BoxShape.circle,
          border: Border.all(color: Br.bg, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x59101714), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
            child: BrIcon(icon, size: size / 2, color: Br.bg, stroke: 2.2)),
      );
}

/// Small dark pill used for labels over the map ("~120 m", "+4 XP").
class MapPill extends StatelessWidget {
  const MapPill(this.text, {super.key, this.mono = false, this.color = Br.gold});
  final String text;
  final bool mono;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Br.bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: mono
                ? BrText.mono(11, color: color, tracking: .02)
                : BrText.ui(11, weight: FontWeight.w700, color: color)),
      );
}

/// Rounded square tile with a "?" (a hidden place in a list).
class MysteryTile extends StatelessWidget {
  const MysteryTile({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Br.fog, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Text('?', style: BrText.display(size * 0.58, color: Br.gold)),
      );
}

/// Rounded square gold tile with a category icon (a discovered place).
class FoundTile extends StatelessWidget {
  const FoundTile(this.icon, {super.key, this.size = 52});
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Br.gold, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: BrIcon(icon, size: size * 0.46, color: Br.bg),
      );
}

// ------------------------------------------------------------- navigation

class NavItem {
  const NavItem(this.label, this.icon, {this.activeIcon});
  final String label;
  final String icon;
  final String? activeIcon;
}

const navItems = [
  NavItem('Explorar', BrIcons.explore, activeIcon: BrIcons.exploreActive),
  NavItem('Descubrir', BrIcons.discover),
  NavItem('Progreso', BrIcons.progress),
  NavItem('Insignias', BrIcons.badges),
  NavItem('Perfil', BrIcons.profile),
];

/// Bottom navigation, 80 dp, deep green pill on the active tab and a gold
/// dot for unseen news.
class BrNavBar extends StatelessWidget {
  const BrNavBar(
      {super.key, required this.index, required this.onTap, this.dots = const {}});
  final int index;
  final ValueChanged<int> onTap;
  final Set<int> dots;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 80 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Br.bg,
        border: Border(top: BorderSide(color: Br.hairline)),
      ),
      child: Row(children: [
        for (var i = 0; i < navItems.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              label: navItems[i].label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                child: _NavCell(
                    item: navItems[i], active: i == index, dot: dots.contains(i)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.active, required this.dot});
  final NavItem item;
  final bool active;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final color = active ? Br.text : Br.textMuted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Br.curve,
          width: 56,
          height: 30,
          decoration: BoxDecoration(
            color: active ? Br.greenDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            BrIcon(active ? (item.activeIcon ?? item.icon) : item.icon,
                size: 22, color: color),
            if (dot)
              const Positioned(
                right: 13,
                top: 4,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: Br.gold, shape: BoxShape.circle),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        Text(item.label,
            style: BrText.ui(11.5,
                weight: active ? FontWeight.w700 : FontWeight.w600,
                color: color)),
      ],
    );
  }
}

/// Fades content into the background just above the navigation bar.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, this.height = 56});
  final double height;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00101714), Br.bg],
            ),
          ),
        ),
      );
}
