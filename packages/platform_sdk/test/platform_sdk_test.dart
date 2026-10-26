import 'package:flutter_test/flutter_test.dart';

import 'package:platform_sdk/platform_sdk.dart';

void main() {
  test('platform_sdk library exports load', () {
    expect(BrandSDK, isNotNull);
  });
}
