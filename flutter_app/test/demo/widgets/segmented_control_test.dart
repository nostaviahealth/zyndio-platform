import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/segmented_control.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  testWidgets('renders every segment and reports taps on the right index', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      wrap(
        SegmentedControl(
          segments: const ['3M', '6M', '1Y', 'All'],
          selectedIndex: 1,
          onChanged: (i) => tapped = i,
        ),
      ),
    );

    for (final label in ['3M', '6M', '1Y', 'All']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('1Y'));
    expect(tapped, 2);
  });

  testWidgets('every segment meets the 44pt minimum hit height', (tester) async {
    await tester.pumpWidget(
      wrap(const SegmentedControl(segments: ['3M', '6M', '1Y', 'All'], selectedIndex: 1)),
    );

    final box = tester.renderObject<RenderBox>(find.byType(SegmentedControl));
    expect(box.size.height, greaterThanOrEqualTo(44));
  });
}
