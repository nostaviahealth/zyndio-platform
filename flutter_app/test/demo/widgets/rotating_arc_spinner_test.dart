import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/widgets/rotating_arc_spinner.dart';

void main() {
  testWidgets('animates: two pumps render the arc at different rotations', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RotatingArcSpinner(size: 20, color: Colors.white)),
      ),
    );

    final spinnerPaint = find.descendant(
      of: find.byType(RotatingArcSpinner),
      matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ArcSpinnerPainter),
    );

    await tester.pump(const Duration(milliseconds: 150));
    final first = tester.widget<CustomPaint>(spinnerPaint).painter! as ArcSpinnerPainter;

    await tester.pump(const Duration(milliseconds: 150));
    final second = tester.widget<CustomPaint>(spinnerPaint).painter! as ArcSpinnerPainter;

    expect(first.turn, isNot(second.turn));

    // Dispose the animating ticker before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('freezes at a fixed deterministic angle when animations are disabled (screenshot mode)', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: RotatingArcSpinner(size: 20, color: Colors.white)),
        ),
      ),
    );

    final spinnerPaint = find.descendant(
      of: find.byType(RotatingArcSpinner),
      matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ArcSpinnerPainter),
    );

    await tester.pump(const Duration(milliseconds: 150));
    final before = tester.widget<CustomPaint>(spinnerPaint).painter! as ArcSpinnerPainter;
    await tester.pump(const Duration(milliseconds: 150));
    final after = tester.widget<CustomPaint>(spinnerPaint).painter! as ArcSpinnerPainter;

    expect(before.turn, after.turn);
    expect(before.turn, RotatingArcSpinner.frozenTurn);
  });
}
