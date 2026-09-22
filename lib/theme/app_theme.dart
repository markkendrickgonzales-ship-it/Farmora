import 'package:flutter/material.dart';

class FarmoraColors {
  static const Color bg = Color(0xFFEEF1EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSunken = Color(0xFFF5F7F2);
  static const Color ink = Color(0xFF1C2620);
  static const Color inkSoft = Color(0xFF5B685E);
  static const Color inkFaint = Color(0xFF8A9589);
  static const Color line = Color(0xFFDFE4D9);
  static const Color brand = Color(0xFF2F5D50);
  static const Color brandSoft = Color(0xFFE4EDE8);
  static const Color good = Color(0xFF3B7A57);
  static const Color goodSoft = Color(0xFFE6F1EA);
  static const Color warn = Color(0xFFB4791F);
  static const Color warnSoft = Color(0xFFFBEDD9);
  static const Color crit = Color(0xFFB23A32);
  static const Color critSoft = Color(0xFFF8E4E1);
  static const Color info = Color(0xFF3E6C8C);
  static const Color infoSoft = Color(0xFFE4EDF3);
}

class FarmoraTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: FarmoraColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FarmoraColors.brand,
        primary: FarmoraColors.brand,
        surface: FarmoraColors.surface,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: FarmoraColors.ink),
      ),
    );
  }
}
