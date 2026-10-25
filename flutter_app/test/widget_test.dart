import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BrandHealthApp(),
      ),
    );

    // Verify the app loads
    expect(find.byType(BrandHealthApp), findsOneWidget);
  });
}
