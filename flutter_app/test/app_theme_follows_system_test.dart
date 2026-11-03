// TC-025 C4 (Q16): the patient app follows the phone's light/dark setting by
// default (ThemeMode.system). The manual switch is PR B1; the Settings
// dark-mode switch stays as it is on main.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/app.dart';

Future<ThemeData> _pumpAppWithPlatform(
    WidgetTester tester, Brightness platform) async {
  tester.platformDispatcher.platformBrightnessTestValue = platform;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(const ProviderScope(child: BrandHealthApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.themeMode, ThemeMode.system,
      reason: 'the app must follow the system setting by default');
  return Theme.of(tester.element(find.byType(Navigator).first));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('phone in dark mode -> app renders the dark theme',
      (tester) async {
    final theme = await _pumpAppWithPlatform(tester, Brightness.dark);
    expect(theme.brightness, Brightness.dark);
  });

  testWidgets('phone in light mode -> app renders the light theme',
      (tester) async {
    final theme = await _pumpAppWithPlatform(tester, Brightness.light);
    expect(theme.brightness, Brightness.light);
  });
}
