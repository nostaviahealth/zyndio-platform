import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/optional_card.dart';

void main() {
  testWidgets('OptionalCard renders its copy and toggles on tap anywhere in the card', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(
          body: OptionalCard(
            title: 'Share progress with my body composition partner',
            subtitle: 'Only results your Zyndio clinician has reviewed.',
            value: value,
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );

    expect(find.text('Share progress with my body composition partner'), findsOneWidget);
    expect(find.text('Only results your Zyndio clinician has reviewed.'), findsOneWidget);

    await tester.tap(find.text('Share progress with my body composition partner'));
    expect(value, isTrue);
  });

  testWidgets(
    'dark mode: OFF switch thumb/track/outline colours come from ZyndioColors tokens, never a hardcoded white knob',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BrandTheme.darkTheme,
          home: Scaffold(
            body: OptionalCard(
              title: 'Share progress',
              subtitle: 'Optional sharing',
              value: false,
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(Switch));
      final colors = Theme.of(context).extension<ZyndioColors>()!;
      final switchTheme = Theme.of(context).switchTheme;
      const offStates = <WidgetState>{};

      final thumbColor = switchTheme.thumbColor!.resolve(offStates);
      final trackColor = switchTheme.trackColor!.resolve(offStates);
      final outlineColor = switchTheme.trackOutlineColor!.resolve(offStates);

      expect(thumbColor, colors.bgSurface);
      expect(thumbColor, isNot(Colors.white));
      expect(trackColor, colors.bgSunken);
      expect(outlineColor, colors.borderStrong);
    },
  );
}
