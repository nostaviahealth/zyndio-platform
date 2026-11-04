// APP-09: emergencies and clinical questions never reach the AI companion;
// they go to the care team. Everyday wellness questions still do.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/services/companion_boundaries.dart';

void main() {
  group('routeCompanionMessage', () {
    for (final text in [
      'I have chest pain and my left arm hurts',
      'I think I am having a stroke',
      "I can't breathe properly",
      'I want to kill myself',
      'Is this an emergency?',
    ]) {
      test('emergency: "$text"', () {
        expect(routeCompanionMessage(text), CompanionRoute.emergency);
      });
    }

    for (final text in [
      'Should I increase my dose of semaglutide?',
      'Can I skip my injection this week?',
      'Is nausea a side effect of Ozempic?',
      'Can you diagnose why I feel tired?',
      'should i stop taking metformin',
      'What medication would help my cholesterol?',
    ]) {
      test('care team: "$text"', () {
        expect(routeCompanionMessage(text), CompanionRoute.careTeam);
      });
    }

    for (final text in [
      'What should I eat for a high-protein breakfast?',
      'How many mg of sodium is in this soup?',
      'What is insulin resistance?',
      'How can I sleep better?',
    ]) {
      test('companion: "$text"', () {
        expect(routeCompanionMessage(text), CompanionRoute.companion);
      });
    }
  });

  group('emergencyGuidance', () {
    test('points US patients to 911 and says the care team was alerted', () {
      final g = emergencyGuidance('chest pain');
      expect(g, contains('911'));
      expect(g, contains('care team has been alerted'));
      expect(g, isNot(contains('112')));
      expect(g, isNot(contains('988')));
    });

    test('adds the 988 crisis line for self-harm language', () {
      expect(emergencyGuidance('I want to end my life'), contains('988'));
    });
  });

  test('filing is a no-op for ordinary companion messages', () async {
    expect(await fileCompanionEscalation(CompanionRoute.companion, 'hi'), isFalse);
  });
}
