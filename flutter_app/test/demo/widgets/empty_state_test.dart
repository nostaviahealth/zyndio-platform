import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows the title, message and icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.insert_drive_file_outlined,
            title: 'No reports yet',
            message: 'Reports you add will appear here.',
          ),
        ),
      ),
    );

    expect(find.text('No reports yet'), findsOneWidget);
    expect(find.text('Reports you add will appear here.'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
  });
}
