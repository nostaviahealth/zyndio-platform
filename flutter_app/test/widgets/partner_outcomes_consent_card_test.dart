import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/widgets/partner_outcomes_consent_card.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('PartnerOutcomesConsentCard (APP-03)', () {
    testWidgets(
      'renders DEXASCAN disclosure and explains that revoking stops future deliveries',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const PartnerOutcomesConsentCard(
              initialAuthorized: false,
            ),
          ),
        );

        expect(
          find.text('Share milestone outcomes with DEXASCAN'),
          findsOneWidget,
        );
        expect(find.text('Not authorised'), findsOneWidget);
        expect(
          find.textContaining(
            'revoking immediately stops future outcome deliveries to DEXASCAN',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Authorise outcome sharing'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'grants and revokes partner outcome authorisation via callback',
      (tester) async {
        final recordedCalls = <Map<String, dynamic>>[];

        await tester.pumpWidget(
          buildTestApp(
            PartnerOutcomesConsentCard(
              initialAuthorized: false,
              consentVersion: 'v1.0',
              onUpdateConsent: ({
                required bool authorized,
                required String consentVersion,
                required String consentText,
              }) async {
                recordedCalls.add({
                  'authorized': authorized,
                  'consentVersion': consentVersion,
                  'consentText': consentText,
                });
              },
            ),
          ),
        );

        // Tap action button to grant authorisation
        await tester.tap(find.byKey(const Key('partner-consent-action-button')));
        await tester.pumpAndSettle();

        expect(recordedCalls.length, 1);
        expect(recordedCalls.first['authorized'], isTrue);
        expect(recordedCalls.first['consentVersion'], 'v1.0');
        expect(
          recordedCalls.first['consentText'],
          PartnerOutcomesConsentCard.defaultConsentText,
        );
        expect(find.text('Authorised (v1.0)'), findsOneWidget);
        expect(find.text('Revoke authorisation'), findsOneWidget);

        // Tap action button again to revoke authorisation
        await tester.tap(find.byKey(const Key('partner-consent-action-button')));
        await tester.pumpAndSettle();

        expect(recordedCalls.length, 2);
        expect(recordedCalls.last['authorized'], isFalse);
        expect(find.text('Not authorised'), findsOneWidget);
      },
    );

    testWidgets(
      'displays error banner and preserves previous state if update fails',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            PartnerOutcomesConsentCard(
              initialAuthorized: true,
              onUpdateConsent: ({
                required bool authorized,
                required String consentVersion,
                required String consentText,
              }) async {
                throw Exception('network failure');
              },
            ),
          ),
        );

        expect(find.text('Authorised (v1.0)'), findsOneWidget);

        await tester.tap(find.byKey(const Key('partner-consent-action-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('partner-consent-error-banner')),
          findsOneWidget,
        );
        // Remains authorised because revocation failed
        expect(find.text('Authorised (v1.0)'), findsOneWidget);
      },
    );
  });
}
