import 'package:health/health.dart';

void main() {
  print("Available Health Types:");
  for (var value in HealthDataType.values) {
    print(value.toString().replaceAll('HealthDataType.', ''));
  }
}
