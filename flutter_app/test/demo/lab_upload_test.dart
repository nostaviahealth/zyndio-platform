import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/screens/lab_upload/lab_upload_state.dart';
import 'package:zyndio_patient/demo/screens/lab_upload/lab_upload_view.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
    home: child,
  );
}

void main() {
  group('LabUploadView', () {
    testWidgets('default: shows the reading, on-hold and saved history rows', (tester) async {
      await tester.pumpWidget(_wrap(LabUploadView(state: LabUploadState.defaultState())));

      expect(find.text("Add a lab report and we'll pull out the values for you and your care team."), findsOneWidget);
      expect(find.text("Reading values. We'll let you know when they're ready."), findsOneWidget);
      expect(find.text("Name doesn't match your account"), findsOneWidget);
      expect(find.text('On hold'), findsOneWidget);
      expect(find.text('14 values saved'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('empty: shows the empty-state card instead of the uploads list', (tester) async {
      await tester.pumpWidget(_wrap(LabUploadView(state: LabUploadState.empty())));

      expect(find.text('No reports yet'), findsOneWidget);
      expect(
        find.text('Reports you add will appear here, and your care team will see them too.'),
        findsOneWidget,
      );
      expect(find.text('14 values saved'), findsNothing);
    });

    testWidgets('uploading: shows the determinate progress row', (tester) async {
      await tester.pumpWidget(_wrap(LabUploadView(state: LabUploadState.uploading())));

      expect(find.text('New report'), findsOneWidget);
      expect(find.text('Uploading page 2 of 3'), findsOneWidget);
    });

    testWidgets(
      'T-LAB-03 duplicate: shows the warning banner with both "Upload anyway" and "Cancel", and never blocks',
      (tester) async {
        var uploadedAnyway = false;
        var cancelled = false;
        await tester.pumpWidget(
          _wrap(
            LabUploadView(
              state: LabUploadState.duplicate(),
              onUploadAnyway: () => uploadedAnyway = true,
              onCancelDuplicate: () => cancelled = true,
            ),
          ),
        );

        expect(
          find.text('This looks like the report you uploaded on Aug 6, 2026. Upload it anyway?'),
          findsOneWidget,
        );
        final uploadAnywayButton = find.widgetWithText(FilledButton, 'Upload anyway');
        final cancelButton = find.widgetWithText(OutlinedButton, 'Cancel');
        expect(uploadAnywayButton, findsOneWidget);
        expect(cancelButton, findsOneWidget);

        await tester.tap(uploadAnywayButton);
        expect(uploadedAnyway, isTrue);
        await tester.tap(cancelButton);
        expect(cancelled, isTrue);
      },
    );

    testWidgets('offline: row text is exactly "Waiting for connection" and the item is Queued', (tester) async {
      await tester.pumpWidget(_wrap(LabUploadView(state: LabUploadState.offline())));

      expect(
        find.text("You're offline. Your report is saved on this phone and will upload when you're back online."),
        findsOneWidget,
      );
      expect(find.text('Waiting for connection'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('error: keeps the "photos are still on this phone" copy and offers Retry', (tester) async {
      await tester.pumpWidget(_wrap(LabUploadView(state: LabUploadState.error())));

      expect(
        find.text("Your upload didn't finish. Your photos are still on this phone, so you can try again."),
        findsOneWidget,
      );
      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('every state builds in dark mode too', (tester) async {
      final states = [
        LabUploadState.defaultState(),
        LabUploadState.empty(),
        LabUploadState.uploading(),
        LabUploadState.duplicate(),
        LabUploadState.offline(),
        LabUploadState.error(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(LabUploadView(state: state), brightness: Brightness.dark));
        expect(find.byType(LabUploadView), findsOneWidget);
      }
    });
  });
}
