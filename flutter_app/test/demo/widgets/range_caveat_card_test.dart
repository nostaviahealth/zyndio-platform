import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/message_care_team_button.dart';
import 'package:zyndio_patient/demo/widgets/range_caveat_card.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  const caveatText =
      'These are general default ranges. Your Zyndio care team will confirm the ranges used for your care.';

  testWidgets(
      'T-BIO-02: always shows the default-range caveat copy, with no action button by default',
      (tester) async {
    await tester.pumpWidget(wrap(const RangeCaveatCard()));

    expect(find.text(caveatText), findsOneWidget);
    expect(find.text('Message care team'), findsNothing);
  });

  testWidgets('shows a Message care team button when provided', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
        wrap(RangeCaveatCard(onMessageCareTeam: () => tapped = true)));

    expect(find.text(caveatText), findsOneWidget);
    await tester.tap(find.text('Message care team'));
    expect(tapped, isTrue);
  });

  testWidgets(
      'Message care team uses the shared compact pill, not a full-width button',
      (tester) async {
    await tester.pumpWidget(
      wrap(SizedBox(
          width: 358, child: RangeCaveatCard(onMessageCareTeam: () {}))),
    );

    expect(find.byType(MessageCareTeamButton), findsOneWidget);
    final buttonWidth = tester.getSize(find.byType(FilledButton)).width;
    expect(buttonWidth, lessThan(358));
  });
}
