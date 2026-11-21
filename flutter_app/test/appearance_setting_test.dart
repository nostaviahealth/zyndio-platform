// Client walkthrough (19 Nov 2026): the patient can pick light or dark,
// on top of following the phone (the default, TC-025 C4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/app.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/theme_mode_provider.dart';
import 'package:zyndio_patient/screens/settings/settings_screen.dart';

Future<ThemeData> _pumpApp(WidgetTester tester, Brightness phone) async {
  tester.platformDispatcher.platformBrightnessTestValue = phone;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(const ProviderScope(child: BrandHealthApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return Theme.of(tester.element(find.byType(Navigator).first));
}

double _luminanceContrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Saved appearance choice', () {
    testWidgets('dark is kept even when the phone is in light mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({themeModePrefsKey: 'dark'});
      final theme = await _pumpApp(tester, Brightness.light);
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('light is kept even when the phone is in dark mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({themeModePrefsKey: 'light'});
      final theme = await _pumpApp(tester, Brightness.dark);
      expect(theme.brightness, Brightness.light);
    });

    testWidgets('an unknown stored value falls back to the phone',
        (tester) async {
      SharedPreferences.setMockInitialValues({themeModePrefsKey: 'sepia'});
      final theme = await _pumpApp(tester, Brightness.dark);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(theme.brightness, Brightness.dark);
    });
  });

  testWidgets('Settings → Appearance switches the theme and saves it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: AppearanceCard()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("Matches your phone's light or dark setting."),
        findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(find.text('Always dark, whatever your phone uses.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeModePrefsKey), 'dark');

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(prefs.getString(themeModePrefsKey), 'system');
  });

  test('dark cards (ambassador look) keep every text token readable', () {
    const d = ZyndioColors.dark;
    for (final stop in ZyndioNight.card) {
      expect(_luminanceContrast(d.textPrimary, stop), greaterThan(12));
      expect(_luminanceContrast(d.textSecondary, stop), greaterThan(7));
      expect(_luminanceContrast(d.textTertiary, stop), greaterThanOrEqualTo(4.5));
    }
  });
}
