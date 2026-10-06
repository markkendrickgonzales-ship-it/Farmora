import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farmora/theme/app_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => farmoraTheme.setDark(false));

  group('FarmoraThemeController', () {
    test('defaults to the light palette', () {
      expect(farmoraTheme.isDark, isFalse);
      expect(FarmoraColors.current, same(lightPalette));
    });

    test('setDark swaps the global palette and notifies listeners', () async {
      var notifications = 0;
      farmoraTheme.addListener(() => notifications++);

      await farmoraTheme.setDark(true);

      expect(farmoraTheme.isDark, isTrue);
      expect(FarmoraColors.current, same(darkPalette));

      expect(FarmoraColors.bg, darkPalette.bg);
      expect(FarmoraColors.ink, darkPalette.ink);
      expect(notifications, 1);

      await farmoraTheme.setDark(false);

      expect(FarmoraColors.current, same(lightPalette));
      expect(notifications, 2);
    });

    test('the choice is persisted and restored on next launch', () async {
      await farmoraTheme.setDark(true);

      final restarted = FarmoraThemeController();
      await restarted.load();

      expect(restarted.isDark, isTrue);
      expect(FarmoraColors.current, same(darkPalette));
    });

    test('brand foreground stays readable in both palettes', () {
      expect(lightPalette.onBrand, const Color(0xFFFFFFFF));
      expect(darkPalette.onBrand, isNot(const Color(0xFFFFFFFF)));
      expect(darkPalette.brand.computeLuminance(),
          greaterThan(darkPalette.onBrand.computeLuminance()));
    });
  });

  group('FarmoraTheme', () {
    test('exposes a matching dark ThemeData', () {
      expect(FarmoraTheme.themeData.brightness, Brightness.light);
      expect(FarmoraTheme.darkThemeData.brightness, Brightness.dark);
      expect(
          FarmoraTheme.darkThemeData.scaffoldBackgroundColor, darkPalette.bg);
    });
  });
}
