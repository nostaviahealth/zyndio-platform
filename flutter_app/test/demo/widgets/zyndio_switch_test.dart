import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/zyndio_switch.dart';

void main() {
  Future<void> pumpSwitch(WidgetTester tester, {required ThemeData theme, required bool value}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: ZyndioSwitch(value: value))),
      ),
    );
  }

  Container trackOf(WidgetTester tester) => tester.widget<Container>(
        find.descendant(of: find.byType(ZyndioSwitch), matching: find.byType(Container)).first,
      );

  Container knobOf(WidgetTester tester) => tester.widget<Container>(
        find.descendant(of: find.byType(ZyndioSwitch), matching: find.byType(Container)).last,
      );

  for (final entry in {'light': ZyndioColors.light, 'dark': ZyndioColors.dark}.entries) {
    final themeName = entry.key;
    final colors = entry.value;
    final theme = themeName == 'light' ? BrandTheme.lightTheme : BrandTheme.darkTheme;

    for (final value in [false, true]) {
      final stateName = value ? 'on' : 'off';

      testWidgets('$themeName theme, $stateName: track and knob are the correct size', (tester) async {
        await pumpSwitch(tester, theme: theme, value: value);

        expect(tester.getSize(find.byType(ZyndioSwitch)), const Size(ZyndioSize.switchWidth, ZyndioSize.switchHeight));
        expect(tester.getSize(find.descendant(of: find.byType(ZyndioSwitch), matching: find.byType(Container)).last),
            const Size(ZyndioSize.switchKnob, ZyndioSize.switchKnob));
      });

      testWidgets('$themeName theme, $stateName: track fill/border match ZyndioColors tokens', (tester) async {
        await pumpSwitch(tester, theme: theme, value: value);

        final trackDecoration = trackOf(tester).decoration as BoxDecoration;
        final expectedTrackColor = value ? colors.brandPrimary : colors.bgSunken;
        final expectedTrackBorder = value ? colors.brandPrimary : colors.borderStrong;

        expect(trackDecoration.color, expectedTrackColor);
        expect(trackDecoration.border, Border.all(color: expectedTrackBorder));
      });

      testWidgets('$themeName theme, $stateName: knob fill/outline match ZyndioColors tokens', (tester) async {
        await pumpSwitch(tester, theme: theme, value: value);

        final knobDecoration = knobOf(tester).decoration as BoxDecoration;
        final expectedKnobOutline = value ? colors.brandPrimary : colors.borderStrong;

        expect(knobDecoration.color, colors.bgSurface);
        expect(knobDecoration.shape, BoxShape.circle);
        expect(knobDecoration.border, Border.all(color: expectedKnobOutline));
      });

      testWidgets('$themeName theme, $stateName: knob sits at the ${value ? 'right' : 'left'}', (tester) async {
        await pumpSwitch(tester, theme: theme, value: value);

        final trackLeft = tester.getTopLeft(find.byType(ZyndioSwitch)).dx;
        final knobLeft = tester.getTopLeft(
          find.descendant(of: find.byType(ZyndioSwitch), matching: find.byType(Container)).last,
        ).dx;
        final offsetWithinTrack = knobLeft - trackLeft;
        // 1px track border (auto-inset by BoxDecoration) + the spec's
        // 2px (off) / 22px (on) CSS left offset.
        final expectedOffset = value ? 23.0 : 3.0;

        expect(offsetWithinTrack, closeTo(expectedOffset, 0.1));
      });
    }
  }
}
