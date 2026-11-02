// TC-026: auth_provider.dart must never reference the removed `profiles`
// table. isAdminProvider was the one place it did (reading a `role` column
// that doesn't exist on any current table) and has no consumers anywhere in
// lib/ or test/ - this guards against it (or an equivalent) coming back.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth_provider.dart does not reference the profiles table', () {
    final source = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(source.contains("'profiles'"), isFalse, reason: source);
  });
}
