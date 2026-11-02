import 'package:flutter/material.dart';

/// Colour tokens from the Bruma design system ("Fundamentos").
abstract final class Br {
  // Base surfaces.
  static const bg = Color(0xFF101714);
  static const surface = Color(0xFF1A2420);
  static const surfaceHigh = Color(0xFF26332D);
  static const deep = Color(0xFF0B110E);
  static const lockedFill = Color(0xFF161F1B);

  // Accents.
  static const green = Color(0xFFA8C686); // exploration, main action
  static const greenLight = Color(0xFFC3DCA6);
  static const greenDeep = Color(0xFF536D50); // non-text only
  static const gold = Color(0xFFD6B36A); // discoveries and XP only
  static const goldDim = Color(0xFF9C8350);
  static const goldWarn = Color(0xFFE3C27A);
  static const danger = Color(0xFFE39A86);

  // Text.
  static const text = Color(0xFFF0F1E9);
  static const textSoft = Color(0xFFD7DAD1);
  static const textMuted = Color(0xFF929D91);
  static const textOnFog = Color(0xFFB9BFBB);
  static const textCalm = Color(0xFFB9C2B4);

  // Lines.
  static const outline = Color(0xFF3A4A42);
  static const hairline = Color(0x0FF0F1E9); // rgba(240,241,233,.06)
  static const border = Color(0x1AF0F1E9); // rgba(240,241,233,.1)
  static const divider = Color(0x14F0F1E9); // rgba(240,241,233,.08)

  // Map ("Atlas claro").
  static const mapBlock = Color(0xFFE7E9E0);
  static const mapPaper = Color(0xFFEEF0E8);
  static const mapInk = Color(0xFF56615A);

  /// Fog colours the user can choose from.
  static const fogs = <FogTone>[
    FogTone('Grafito', Color(0xFF3B403E)),
    FogTone('Pizarra', Color(0xFF3A4350)),
    FogTone('Musgo', Color(0xFF3D4A40)),
    FogTone('Sepia', Color(0xFF4A4239)),
    FogTone('Noche', Color(0xFF22262A)),
  ];
  static const fog = Color(0xFF3B403E);
  static const fogLine = Color(0xFF4A504D);

  /// The fog colour lightened 9 % toward white, used for contour lines.
  static Color fogLineFor(Color c) => Color.lerp(c, Colors.white, 0.09)!;

  static const shadow = [
    BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const shadowSmall = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Standard motion curve: cubic-bezier(.2, 0, 0, 1).
  static const curve = Cubic(0.2, 0, 0, 1);
}

class FogTone {
  const FogTone(this.name, this.color);
  final String name;
  final Color color;
}

/// Typography: Instrument Serif for figures and headlines, Manrope for the
/// interface, IBM Plex Mono for map data and labels.
abstract final class BrText {
  static const serif = 'InstrumentSerif';
  static const sans = 'Manrope';
  static const monoFont = 'IBMPlexMono';

  static TextStyle display(double size,
          {Color color = Br.text, double height = 1, double? spacing}) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        height: height,
        color: color,
        fontWeight: FontWeight.w400,
        letterSpacing: spacing,
      );

  static TextStyle ui(double size,
          {FontWeight weight = FontWeight.w500,
          Color color = Br.text,
          double? height,
          FontStyle? style}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontStyle: style,
      );

  /// Monospace label. [tracking] is in em, as in the design (e.g. .16em).
  static TextStyle mono(double size,
          {Color color = Br.textMuted,
          double tracking = 0,
          FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: monoFont,
        fontSize: size,
        color: color,
        letterSpacing: size * tracking,
        fontWeight: weight,
        height: 1.2,
      );
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: Br.green,
    onPrimary: Br.bg,
    secondary: Br.gold,
    onSecondary: Br.bg,
    surface: Br.bg,
    onSurface: Br.text,
    error: Br.danger,
    outline: Br.outline,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Br.bg,
    fontFamily: BrText.sans,
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Br.green,
      selectionColor: Color(0x55A8C686),
      selectionHandleColor: Br.green,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Br.bg,
      contentTextStyle: BrText.ui(13, weight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Br.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Br.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: BrText.display(28),
      contentTextStyle: BrText.ui(14, color: Br.textSoft, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Br.bg,
      modalBackgroundColor: Br.bg,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
