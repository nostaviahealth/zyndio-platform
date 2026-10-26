import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/white_label_config.dart';

void main() {
  group('WhiteLabelConfig defaults', () {
    test('zyndioDefault carries the Zyndio brand name and endpoints', () {
      const config = WhiteLabelConfig.zyndioDefault;
      expect(config.hospitalBrandName, 'ZYNDIO');
      expect(config.supportEmail, 'care@zyndio.health');
      expect(config.apiBaseUrl, 'https://api.zyndio.health/v1');
      expect(config.enableTelehealth, isTrue);
      expect(config.enableInPersonVisits, isTrue);
      expect(config.enableHomeVisits, isTrue);
      expect(config.requireInsuranceId, isFalse);
      expect(config.requirePatientPhone, isTrue);
    });

    test('WhiteLabelConfigNotifier defaults to the Zyndio preset', () {
      final notifier = WhiteLabelConfigNotifier();
      final initial = notifier.build();
      expect(initial.hospitalBrandName, 'ZYNDIO');
    });
  });
}
