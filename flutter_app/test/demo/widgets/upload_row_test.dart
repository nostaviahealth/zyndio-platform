import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/badge.dart';
import 'package:zyndio_patient/demo/widgets/progress_bar.dart';
import 'package:zyndio_patient/demo/widgets/upload_row.dart';

void main() {
  testWidgets('UploadRow shows title, status and a badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(
          body: UploadRow(
            title: 'Report from Aug 6, 2026',
            status: '14 values saved',
            leading: const Icon(Icons.insert_drive_file_outlined),
            badgeLabel: 'Saved',
            badgeVariant: BadgeVariant.ok,
          ),
        ),
      ),
    );

    expect(find.text('Report from Aug 6, 2026'), findsOneWidget);
    expect(find.text('14 values saved'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('UploadRow shows a progress bar only when given one', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(
          body: UploadRow(
            title: 'New report',
            status: 'Uploading page 2 of 3',
            leading: const Icon(Icons.hourglass_top),
            progress: 0.6,
          ),
        ),
      ),
    );

    expect(find.byType(ProgressBar), findsOneWidget);
  });

  testWidgets('UploadRow shows Retry when onRetry is set', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(
          body: UploadRow(
            title: 'New report',
            status: 'Upload failed',
            leading: const Icon(Icons.warning_amber_rounded),
            onRetry: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(tapped, isTrue);
  });
}
