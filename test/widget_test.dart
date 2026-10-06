import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farmora/main.dart';
import 'package:farmora/services/auth_service.dart';
import 'package:farmora/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.restore();
  });

  tearDown(() => farmoraTheme.setDark(false));

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FarmoraApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('theme switch flips MaterialApp to dark mode immediately',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FarmoraApp());
    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app().themeMode, ThemeMode.light);

    await farmoraTheme.setDark(true);
    await tester.pump();

    expect(app().themeMode, ThemeMode.dark);
    expect(app().darkTheme, isNotNull);
    expect(FarmoraColors.current, same(darkPalette));
  });
}
