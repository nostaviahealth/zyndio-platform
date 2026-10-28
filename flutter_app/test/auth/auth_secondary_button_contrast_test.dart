// Ava R4: "Send a new code" stays enabled on the locked link-record state
// (server lockout only guards redeem, not new-code requests — see
// patient-request-link-code, which never checks patient_link_attempts). This
// guards that the enabled-state label color for AuthSecondaryButton (the
// outlined variant used for "Send a new code") clears WCAG AA (>=4.5:1)
// against the canvas/surface backgrounds it's shown on, in both themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';

double _channelLinear(double v) =>
    v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);

double _relativeLuminance(Color c) {
  final r = _channelLinear(c.r);
  final g = _channelLinear(c.g);
  final b = _channelLinear(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AuthSecondaryButton enabled-state contrast (Ava R4)', () {
    test('light: textPrimary label on bgCanvas >= 4.5:1', () {
      const c = ZyndioColors.light;
      final ratio = _contrastRatio(c.textPrimary, c.bgCanvas);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ratio was $ratio (fg textPrimary on bg bgCanvas)');
    });

    test('light: textPrimary label on bgSurface >= 4.5:1', () {
      const c = ZyndioColors.light;
      final ratio = _contrastRatio(c.textPrimary, c.bgSurface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ratio was $ratio (fg textPrimary on bg bgSurface)');
    });

    test('dark: textPrimary label on bgCanvas >= 4.5:1', () {
      const c = ZyndioColors.dark;
      final ratio = _contrastRatio(c.textPrimary, c.bgCanvas);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ratio was $ratio (fg textPrimary on bg bgCanvas)');
    });

    test('dark: textPrimary label on bgSurface >= 4.5:1', () {
      const c = ZyndioColors.dark;
      final ratio = _contrastRatio(c.textPrimary, c.bgSurface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ratio was $ratio (fg textPrimary on bg bgSurface)');
    });

    test('light: disabledForeground textSecondary clears 4.5:1 if ever used',
        () {
      const c = ZyndioColors.light;
      final ratio = _contrastRatio(c.textSecondary, c.bgCanvas);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ratio was $ratio (fg textSecondary on bg bgCanvas)');
    });

    test('dark: disabledForeground textSecondary clears 4.5:1 if ever used',
        () {
      const c = ZyndioColors.dark;
      final ratio = _contrastRatio(c.textSecondary, c.bgCanvas);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ratio was $ratio (fg textSecondary on bg bgCanvas)');
    });
  });
}
