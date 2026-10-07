import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════
/// OMNIPLAYER — COLOR SYSTEM
/// Holographic Cyberpunk Palette
/// ═══════════════════════════════════════════════
abstract class OmniPlayerColors {
  // Core void
  static const Color voidBlack    = Color(0xFF030508);
  static const Color deepVoid     = Color(0xFF050A12);
  static const Color panelSurface = Color(0xFF0A0F1E);

  // Primary tricolor spectrum
  static const Color cyan         = Color(0xFF00F5FF);
  static const Color violet       = Color(0xFFB400FF);
  static const Color magenta      = Color(0xFFFF00C8);

  // Secondary / status
  static const Color activeGreen  = Color(0xFF00FF88);
  static const Color warningAmber = Color(0xFFFFAA00);
  static const Color errorRed     = Color(0xFFFF003C);

  // Text hierarchy
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0C4CC);
  static const Color textMuted     = Color(0xFF4A6670);

  // Glass panel surfaces
  static Color get panelGlass      => cyan.withOpacity(0.04);
  static Color get panelBorder     => cyan.withOpacity(0.18);
  static Color get panelGlow       => cyan.withOpacity(0.08);

  // Gradient presets
  static const LinearGradient spectrumGradient = LinearGradient(
    colors: [violet, cyan, magenta],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient progressGradient = LinearGradient(
    colors: [violet, cyan],
  );

  static const RadialGradient voidBackground = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.5,
    colors: [Color(0xFF060B15), Color(0xFF030508)],
  );
}

/// ═══════════════════════════════════════════════
/// OMNIPLAYER — TEXT STYLES
/// ═══════════════════════════════════════════════
abstract class OmniPlayerTextStyles {
  static const TextStyle orbitronTitle = TextStyle(
    fontFamily: 'Orbitron',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: OmniPlayerColors.textPrimary,
    letterSpacing: 1.5,
  );

  static const TextStyle orbitronLabel = TextStyle(
    fontFamily: 'Orbitron',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: OmniPlayerColors.cyan,
    letterSpacing: 3.0,
  );

  static const TextStyle orbitronMono = TextStyle(
    fontFamily: 'Orbitron',
    fontSize: 9,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.0,
  );

  static const TextStyle rajdhaniBody = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: OmniPlayerColors.textSecondary,
  );

  static const TextStyle rajdhaniSemi = TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: OmniPlayerColors.textPrimary,
    letterSpacing: 0.5,
  );
}

/// ═══════════════════════════════════════════════
/// OMNIPLAYER — THEME
/// ═══════════════════════════════════════════════
class OmniPlayerTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OmniPlayerColors.voidBlack,
      colorScheme: const ColorScheme.dark(
        primary: OmniPlayerColors.cyan,
        secondary: OmniPlayerColors.violet,
        tertiary: OmniPlayerColors.magenta,
        surface: OmniPlayerColors.panelSurface,
        background: OmniPlayerColors.voidBlack,
        onPrimary: OmniPlayerColors.voidBlack,
        onSecondary: OmniPlayerColors.textPrimary,
        onSurface: OmniPlayerColors.textPrimary,
      ),
      fontFamily: 'Rajdhani',

      // Slider (volume, seek bar)
      sliderTheme: SliderThemeData(
        activeTrackColor: OmniPlayerColors.cyan,
        inactiveTrackColor: OmniPlayerColors.cyan.withOpacity(0.12),
        thumbColor: OmniPlayerColors.cyan,
        overlayColor: OmniPlayerColors.cyan.withOpacity(0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      // Icon
      iconTheme: const IconThemeData(color: OmniPlayerColors.cyan, size: 22),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: OmniPlayerColors.voidBlack,
        selectedItemColor: OmniPlayerColors.cyan,
        unselectedItemColor: OmniPlayerColors.cyan.withOpacity(0.25),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: OmniPlayerColors.cyan.withOpacity(0.1),
        thickness: 1,
      ),

      // Ripple
      splashColor: OmniPlayerColors.cyan.withOpacity(0.08),
      highlightColor: OmniPlayerColors.cyan.withOpacity(0.04),
    );
  }
}

/// ═══════════════════════════════════════════════
/// OMNIPLAYER — SPACING CONSTANTS
/// ═══════════════════════════════════════════════
abstract class OmniPlayerSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const EdgeInsets panelPadding  = EdgeInsets.all(20);
  static const BorderRadius panelRadius = BorderRadius.all(Radius.circular(14));
}
