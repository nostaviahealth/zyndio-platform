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
      'I want to die',
      'My chest hurts',
      "I can't catch my breath",
      'I have shortness of breath',
      'I took all my pills',
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
      'I do not have chest pain',
      'no shortness of breath today',
    ]) {
      test('companion: "$text"', () {
        expect(routeCompanionMessage(text), CompanionRoute.companion);
      });
    }
  });

  group('emergencyGuidance', () {
    test('local emergency guidance does not depend on whether a row was saved', () {
      final saved = emergencyGuidance('chest pain', filed: true);
      final failed = emergencyGuidance('chest pain', filed: false);
      expect(saved, contains('local emergency services'));
      expect(failed, contains('local emergency services'));
      expect(saved, contains('does not mean anyone has seen it'));
      expect(failed, contains('Nothing was filed'));
      expect(saved, isNot(contains('has been alerted')));
      expect(failed, isNot(contains('911')));
      expect(failed, isNot(contains('988')));
    });

    test('self-harm guidance does not name a hotline the product has not configured', () {
      final text = emergencyGuidance('I want to die', filed: false);
      expect(text, contains('local emergency or crisis services'));
      expect(text, isNot(contains('988')));
    });
  });

  test('escalated turns stay out of the model history, the summary, and persistence', () {
    const secret = 'I have chest pain and I want to die';
    final turns = [
      CompanionTurn(role: 'user', text: secret, withheld: true),
      CompanionTurn(
        role: 'model',
        text: emergencyGuidance(secret, filed: false),
        withheld: true,
      ),
      const CompanionTurn(role: 'user', text: 'What should I eat for breakfast?', withheld: false),
      const CompanionTurn(role: 'model', text: 'Eggs and fruit.', withheld: false),
    ];
    final forModel = turnsForModel(turns);
    final joined = forModel.map((t) => t.text).join('\n');
    expect(joined, isNot(contains('chest pain')));
    expect(joined, isNot(contains('want to die')));
    expect(joined, contains('breakfast'));
    final persisted = turns.map((t) => textForPersistence(text: t.text, withheld: t.withheld)).join('\n');
    expect(persisted, isNot(contains(secret)));
    expect(persisted, contains('breakfast'));
  });

  test('filing is a no-op for ordinary companion messages', () async {
    expect(await fileCompanionEscalation(CompanionRoute.companion, 'hi'), isFalse);
  });
}
