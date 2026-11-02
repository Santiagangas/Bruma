import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line icons from the design: 24 grid, 1.8 stroke, rounded joins.
/// `@` is replaced by the icon colour.
abstract final class BrIcons {
  static const explore =
      '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5 13.4 13.4 8.5 15.5 10.6 10.6Z"/>';
  static const exploreActive =
      '<path d="M15.5 8.5 13.4 13.4 8.5 15.5 10.6 10.6Z" fill="@"/>';
  static const discover =
      '<circle cx="12" cy="12" r="9" stroke-dasharray="3 2.6"/><path d="M9.7 9.6a2.4 2.4 0 1 1 3.3 2.2c-.7.3-1 .8-1 1.5v.4"/><circle cx="12" cy="16.6" r=".5" fill="@"/>';
  static const progress =
      '<path d="M3 19 9 9l4 6 2-3 6 7Z"/><path d="M9 9V4l4 1.6L9 7.2"/>';
  static const badges =
      '<path d="M12 3 19 7v8l-7 4-7-4V7Z"/><path d="m9.3 11.4 1.9 1.9 3.5-3.6"/>';
  static const profile =
      '<circle cx="12" cy="8.5" r="3.5"/><path d="M5 20c1.2-3.6 3.8-5.5 7-5.5s5.8 1.9 7 5.5"/>';
  static const locate =
      '<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="2" fill="@"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>';
  static const locateOff =
      '<circle cx="12" cy="12" r="6.5"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>';
  static const lock =
      '<rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>';
  static const layers = '<path d="m12 3 9 5-9 5-9-5Z"/><path d="m3 13 9 5 9-5"/>';
  static const stats =
      '<path d="M5 20V12"/><path d="M10 20V5"/><path d="M15 20v-9"/><path d="M20 20v-5"/>';
  static const steps =
      '<path d="M9 21c-1.7 0-3-1.6-3-3.6 0-2.4 1.3-3.4 3-3.4s3 1 3 3.4C12 19.4 10.7 21 9 21Z"/><path d="M15 12c-1.7 0-3-1.6-3-3.6C12 6 13.3 5 15 5s3 1 3 3.4C18 10.4 16.7 12 15 12Z"/>';
  static const back = '<path d="M19 12H5m5-5-5 5 5 5"/>';
  static const close = '<path d="M6 6l12 12M18 6 6 18"/>';
  static const chevron = '<path d="m9 6 6 6-6 6"/>';
  static const arrowUp = '<path d="M12 19V5m-6 6 6-6 6 6"/>';
  static const next = '<path d="M5 12h14m-5-5 5 5-5 5"/>';
  static const map =
      '<path d="m3 6 6-2 6 2 6-2v14l-6 2-6-2-6 2Z"/><path d="M9 4v14M15 6v14"/>';
  static const export =
      '<path d="M12 15V3m-4 4 4-4 4 4"/><path d="M4 15v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4"/>';
  static const import =
      '<path d="M12 3v12m-4-4 4 4 4-4"/><path d="M4 15v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4"/>';
  static const database =
      '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v12c0 1.7 3.1 3 7 3s7-1.3 7-3V6"/><path d="M5 12c0 1.7 3.1 3 7 3s7-1.3 7-3"/>';
  static const noAccount =
      '<circle cx="12" cy="8.5" r="3.5"/><path d="M5 20c1.2-3.6 3.8-5.5 7-5.5s5.8 1.9 7 5.5"/><path d="M4 4l16 16"/>';
  static const info = '<path d="M12 11v5M12 8h.01"/>';
  static const plus = '<path d="M12 5v14M5 12h14"/>';
  static const offline =
      '<path d="M2 8.5a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0"/><circle cx="12" cy="19" r=".8" fill="@"/><path d="M3 3l18 18"/>';
  static const spinner = '<path d="M21 12a9 9 0 1 1-6.2-8.6"/>';
  static const flag = '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>';
  static const route =
      '<circle cx="6" cy="6" r="2"/><circle cx="18" cy="18" r="2"/><path d="M8 6h6a3 3 0 0 1 0 6h-4a3 3 0 0 0 0 6h6"/>';
  static const pin =
      '<path d="M12 22s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 15.8 12 22 12 22Z"/><circle cx="12" cy="10.5" r="2.5"/>';
  static const sunrise =
      '<path d="M3 18h18M6 18a6 6 0 0 1 12 0"/><path d="M12 6V3M5 10.5 3.5 9M19 10.5 20.5 9"/>';
  static const moon = '<path d="M19 14.5A7.5 7.5 0 1 1 9.5 5a6 6 0 0 0 9.5 9.5Z"/>';
  static const trail =
      '<path d="M5 19c4 0 3-6 7-6s3-8 7-8"/><circle cx="5" cy="19" r="1.6"/><circle cx="19" cy="5" r="1.6"/>';

  // Place categories.
  static const monument = '<path d="M7 21h10M10 21l1-15 1-2 1 2 1 15"/>';
  static const viewpoint =
      '<circle cx="7" cy="15" r="3.5"/><circle cx="17" cy="15" r="3.5"/><path d="M10.5 15h3M5 12l2-6h2l1 6M19 12l-2-6h-2l-1 6"/>';
  static const museum =
      '<path d="M3 9 12 4l9 5Z"/><path d="M5.5 9v9M10 9v9M14 9v9M18.5 9v9M3 20h18"/>';
  static const art =
      '<path d="M12 3a9 9 0 1 0 0 18c1.2 0 1.7-1 1.2-1.9-.6-1 0-2.1 1.2-2.1H17a4 4 0 0 0 4-4c0-5.5-4-10-9-10Z"/><circle cx="7.5" cy="11" r=".8"/><circle cx="11" cy="7.5" r=".8"/><circle cx="15.5" cy="8.5" r=".8"/>';
  static const park =
      '<path d="M12 21v-6"/><path d="M12 3c3.5 2.5 5 5.4 5 8a5 5 0 0 1-10 0c0-2.6 1.5-5.5 5-8Z"/>';
  static const nature =
      '<path d="M4 18c3-1.5 5-1.5 8 0s5 1.5 8 0"/><path d="M12 14V8"/><path d="M12 10c-3 0-4.5-2-4.5-4.5 3 0 4.5 2 4.5 4.5Z"/><path d="M12 11c3 0 4.5-2 4.5-4.5-3 0-4.5 2-4.5 4.5Z"/>';
  static const historic =
      '<path d="M4 21V9l2-1V5h2v2h2V5h4v2h2V5h2v3l2 1v12Z"/><path d="M10 21v-4a2 2 0 0 1 4 0v4"/>';
}

/// Renders one of [BrIcons] at [size] in [color].
class BrIcon extends StatelessWidget {
  const BrIcon(this.svg,
      {super.key, this.size = 22, this.color = const Color(0xFFF0F1E9), this.stroke = 1.8});

  final String svg;
  final double size;
  final Color color;
  final double stroke;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final hex = _hex(color);
    final opacity = color.a;
    final body = svg.replaceAll('@', hex);
    final src = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="$hex" stroke-opacity="$opacity" '
        'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">'
        '$body</svg>';
    return SvgPicture.string(src, width: size, height: size);
  }
}
