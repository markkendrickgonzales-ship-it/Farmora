import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One complete UI color set. Instances are immutable; switching themes
/// swaps the globally-visible [FarmoraColors.current] palette.
class Palette {
  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color brand;
  final Color brandSoft;
  final Color good;
  final Color goodSoft;
  final Color warn;
  final Color warnSoft;
  final Color crit;
  final Color critSoft;
  final Color info;
  final Color infoSoft;

  /// Foreground (text/icon) to place on top of [brand].
  final Color onBrand;

  /// Login hero gradient stops and their foreground colors.
  final Color heroTop;
  final Color heroBottom;
  final Color onHero;
  final Color onHeroSoft;

  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.brand,
    required this.brandSoft,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.crit,
    required this.critSoft,
    required this.info,
    required this.infoSoft,
    required this.onBrand,
    required this.heroTop,
    required this.heroBottom,
    required this.onHero,
    required this.onHeroSoft,
  });
}

/// Original green-on-paper light palette.
const lightPalette = Palette(
  bg: Color(0xFFEEF1EC),
  surface: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFF5F7F2),
  ink: Color(0xFF1C2620),
  inkSoft: Color(0xFF5B685E),
  inkFaint: Color(0xFF8A9589),
  line: Color(0xFFDFE4D9),
  brand: Color(0xFF2F5D50),
  brandSoft: Color(0xFFE4EDE8),
  good: Color(0xFF3B7A57),
  goodSoft: Color(0xFFE6F1EA),
  warn: Color(0xFFB4791F),
  warnSoft: Color(0xFFFBEDD9),
  crit: Color(0xFFB23A32),
  critSoft: Color(0xFFF8E4E1),
  info: Color(0xFF3E6C8C),
  infoSoft: Color(0xFFE4EDF3),
  onBrand: Color(0xFFFFFFFF),
  heroTop: Color(0xFF2F5D50),
  heroBottom: Color(0xFF24483E),
  onHero: Color(0xFFFFFFFF),
  onHeroSoft: Color(0xFFCFE0D6),
);

/// Dark counterpart: deep barn-green backgrounds, light ink, muted accents.
const darkPalette = Palette(
  bg: Color(0xFF121714),
  surface: Color(0xFF1B221D),
  surfaceSunken: Color(0xFF161C18),
  ink: Color(0xFFE7ECE6),
  inkSoft: Color(0xFFAFB9AF),
  inkFaint: Color(0xFF7E8A7F),
  line: Color(0xFF2C3630),
  brand: Color(0xFF6FB39B),
  brandSoft: Color(0xFF253A32),
  good: Color(0xFF6FBE8B),
  goodSoft: Color(0xFF1E3226),
  warn: Color(0xFFD9A441),
  warnSoft: Color(0xFF332A17),
  crit: Color(0xFFE07A6F),
  critSoft: Color(0xFF3A201D),
  info: Color(0xFF7BA6C4),
  infoSoft: Color(0xFF1D2C36),
  onBrand: Color(0xFF0F1512),
  heroTop: Color(0xFF1B3B32),
  heroBottom: Color(0xFF101F1B),
  onHero: Color(0xFFE7ECE6),
  onHeroSoft: Color(0xFF9FC4B6),
);

/// Global color accessors used across the app.
///
/// These are runtime getters into [current], so every widget that reads them
/// repaints as soon as [FarmoraThemeController.setDark] swaps the palette.
/// Nothing referencing them may be `const`.
class FarmoraColors {
  FarmoraColors._();

  /// The palette every getter below reads from.
  static Palette current = lightPalette;

  static Color get bg => current.bg;
  static Color get surface => current.surface;
  static Color get surfaceSunken => current.surfaceSunken;
  static Color get ink => current.ink;
  static Color get inkSoft => current.inkSoft;
  static Color get inkFaint => current.inkFaint;
  static Color get line => current.line;
  static Color get brand => current.brand;
  static Color get brandSoft => current.brandSoft;
  static Color get good => current.good;
  static Color get goodSoft => current.goodSoft;
  static Color get warn => current.warn;
  static Color get warnSoft => current.warnSoft;
  static Color get crit => current.crit;
  static Color get critSoft => current.critSoft;
  static Color get info => current.info;
  static Color get infoSoft => current.infoSoft;
  static Color get onBrand => current.onBrand;
  static Color get heroTop => current.heroTop;
  static Color get heroBottom => current.heroBottom;
  static Color get onHero => current.onHero;
  static Color get onHeroSoft => current.onHeroSoft;
}

/// Listenable holding the light/dark choice, persisted with
/// `SharedPreferences`. [FarmoraApp] watches it so the whole widget tree
/// rebuilds whenever the palette swaps.
class FarmoraThemeController extends ValueNotifier<bool> {
  FarmoraThemeController() : super(false);

  /// true = dark mode.
  bool get isDark => value;

  static const String _prefsKey = 'farmora_dark_mode';

  /// Loads the persisted preference (call before [runApp]).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_prefsKey) ?? false;
    FarmoraColors.current = value ? darkPalette : lightPalette;
  }

  /// Switches the global palette; assigning [value] notifies [FarmoraApp],
  /// which rebuilds the tree. Persisted so the choice survives restarts on
  /// mobile and web.
  Future<void> setDark(bool isDark) async {
    FarmoraColors.current = isDark ? darkPalette : lightPalette;
    value = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, isDark);
  }
}

/// App-wide theme state. Read/watch this from any screen.
final farmoraTheme = FarmoraThemeController();

class FarmoraTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightPalette.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightPalette.brand,
        primary: lightPalette.brand,
        surface: lightPalette.surface,
      ),
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: lightPalette.ink),
      ),
    );
  }

  static ThemeData get darkThemeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkPalette.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPalette.brand,
        brightness: Brightness.dark,
        primary: darkPalette.brand,
        surface: darkPalette.surface,
      ),
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: darkPalette.ink),
      ),
    );
  }
}
