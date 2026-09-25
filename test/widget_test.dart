import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:farmora/main.dart';
import 'package:farmora/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    // MainShell listens to Supabase auth on init, so the client must exist.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_testing_only',
    );
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
