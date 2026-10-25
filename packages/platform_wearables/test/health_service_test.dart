import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_wearables/src/health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('platform_wearables');
  final messenger =
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('HealthService', () {
    test('requestPermissions returns false when platform is unavailable',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'no native impl');
      });

      final result = await HealthService().requestPermissions();

      expect(result, isFalse);
    });

    test('getSleepSessions returns an empty list when no plugin is registered',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });

      final result = await HealthService()
          .getSleepSessions(DateTime(2024, 1, 1), DateTime(2024, 1, 2));

      expect(result, isEmpty);
    });
  });
}
