// Client walkthrough (19 Nov 2026): the AI companion recommends supplements
// from Zyndio's own line, tied to the patient's uploaded blood work.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/precision_nutrition.dart';

void main() {
  final context = precisionNutritionAiContext();

  test('lists every product in the store with its price', () {
    for (final p in precisionNutritionProducts) {
      expect(context, contains(p.name));
      expect(context, contains(p.price));
    }
  });

  test('keeps suggestions to this catalogue and tied to lab results', () {
    expect(context, contains('recommend ONLY from this list'));
    expect(context, contains('Never name other brands'));
    expect(context, contains('LATEST LAB RESULTS'));
    expect(context, contains('navigate_to_supplements'));
  });

  test('stays within the wellness boundaries', () {
    expect(context, contains('not treatment'));
    expect(context, contains('never suggest a dose beyond the label'));
    expect(context, contains('check with their care team'));
    // Product copy keeps its FDA asterisks on screen, not in the prompt.
    expect(context, isNot(contains('*')));
  });
}
