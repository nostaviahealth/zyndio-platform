import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/screens/auth/screenshot/patient_auth_screenshot_frames.dart';

/// Captures TC-012 patient-auth frames (Ava state names) in light + dark
/// at 390×844 with real Inter + MaterialIcons (not Ahem).
///
/// Run:
///   flutter test test/auth/capture_patient_auth_screenshots_test.dart --update-goldens
Future<void> _loadAppFonts() async {
  // App-bundled Inter (variable).
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-VariableFont_opsz,wght.ttf'));
  await inter.load();

  // Material Icons from the Flutter SDK artifact (same as a real device).
  final iconsPath =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/home/box/sdk/flutter'}'
      '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final iconsBytes = File(iconsPath).readAsBytesSync();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(iconsBytes.buffer)));
  await icons.load();

  // Also register as Roboto so Material defaults aren't Ahem if theme misses.
  final robotoPath =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/home/box/sdk/flutter'}'
      '/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  if (File(robotoPath).existsSync()) {
    final robotoBytes = File(robotoPath).readAsBytesSync();
    final roboto = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.view(robotoBytes.buffer)));
    await roboto.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAppFonts();
  });

  final frames = <(String screen, String state, String mode, FrameBuilder builder)>[];
  for (final mode in ['light', 'dark']) {
    for (final screenEntry in PatientAuthScreenshotFrames.all.entries) {
      for (final stateEntry in screenEntry.value.entries) {
        frames.add((screenEntry.key, stateEntry.key, mode, stateEntry.value));
      }
    }
  }

  for (final frame in frames) {
    final (screen, state, mode, builder) = frame;
    final goldenRel = 'goldens/$screen/$state--$mode.png';

    testWidgets('$screen/$state--$mode', (tester) async {
      const logical = Size(390, 844);
      tester.view.physicalSize = logical;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final theme =
          mode == 'dark' ? BrandTheme.darkTheme : BrandTheme.lightTheme;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
            primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Inter'),
          ),
          home: SizedBox(
            width: logical.width,
            height: logical.height,
            child: MediaQuery(
              data: const MediaQueryData(size: logical, devicePixelRatio: 1),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  decoration: TextDecoration.none,
                  color: Colors.black,
                ),
                child: Builder(
                  builder: (context) => RepaintBoundary(
                    key: ValueKey('$screen-$state-$mode'),
                    child: builder(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      await expectLater(
        find.byKey(ValueKey('$screen-$state-$mode')),
        matchesGoldenFile(goldenRel),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  }

  tearDownAll(() {
    if (!autoUpdateGoldenFiles) return;
    final repo = Directory.current.path.endsWith('flutter_app')
        ? Directory.current.parent.path
        : Directory.current.path;
    final goldenRoot = Directory('${Directory.current.path}/test/auth/goldens');
    final outs = [
      Directory('$repo/docs/screenshots/tc-012'),
      Directory('/workspace/techteam/team3/projects/zyndio/work/screenshots/tc-012'),
    ];
    var copied = 0;
    for (final screenDir in goldenRoot.listSync().whereType<Directory>()) {
      final screen = screenDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      for (final f in screenDir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.png')) continue;
        final name = f.uri.pathSegments.last;
        for (final out in outs) {
          final destDir = Directory('${out.path}/$screen')..createSync(recursive: true);
          f.copySync('${destDir.path}/$name');
        }
        copied++;
      }
    }
    // ignore: avoid_print
    print('COPIED_SCREENSHOTS=$copied');
  });
}
