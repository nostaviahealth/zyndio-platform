import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';

void main() {
  group('BrandTheme Zyndio tokens', () {
    test('light theme primary colour matches the Zyndio brand token', () {
      final light = BrandTheme.lightTheme;
      expect(light.colorScheme.primary, const Color(0xFF2C5CF2));
      expect(light.extension<ZyndioColors>()!.brandPrimary, const Color(0xFF2C5CF2));
    });

    test('dark theme primary colour matches the Zyndio dark brand token', () {
      final dark = BrandTheme.darkTheme;
      expect(dark.colorScheme.primary, const Color(0xFF7C9CFF));
      expect(dark.extension<ZyndioColors>()!.brandPrimary, const Color(0xFF7C9CFF));
    });

    test('both themes keep the legacy BrandThemeColors extension registered', () {
      expect(BrandTheme.lightTheme.extension<BrandThemeColors>(), BrandThemeColors.light);
      expect(BrandTheme.darkTheme.extension<BrandThemeColors>(), BrandThemeColors.dark);
    });

    test('text theme is built on the Inter family', () {
      expect(BrandTheme.lightTheme.textTheme.bodyLarge?.fontFamily, 'Inter');
      expect(BrandTheme.darkTheme.textTheme.bodyLarge?.fontFamily, 'Inter');
    });
  });
}
