import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/screens/lab_review/lab_review_controller.dart';
import 'package:zyndio_patient/demo/screens/lab_review/lab_review_state.dart';

void main() {
  group('LabReviewController', () {
    test('editValue updates only the targeted row and keeps the rest', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(labReviewControllerProvider.notifier);

      final before = container.read(labReviewControllerProvider).values;
      final hba1cIndex = before.indexWhere((v) => v.name == 'HbA1c');

      controller.editValue(hba1cIndex, '5.6');

      final after = container.read(labReviewControllerProvider).values;
      expect(after[hba1cIndex].value, '5.6');
      for (var i = 0; i < after.length; i++) {
        if (i != hba1cIndex) {
          expect(after[i].value, before[i].value);
        }
      }
    });

    test('save marks the state saved', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(labReviewControllerProvider.notifier);

      controller.save();

      expect(container.read(labReviewControllerProvider).banner, LabReviewBannerKind.saved);
    });
  });
}
