import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';

/// WCAG 2.x relative luminance of a (fully opaque) sRGB colour.
double _relativeLuminance(Color c) {
  double channel(int v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel((c.r * 255).round());
  final g = channel((c.g * 255).round());
  final b = channel((c.b * 255).round());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('TC-025 tokens — exact values per brightness', () {
    test('light tokens match tokens-tc025.additions.json', () {
      const l = ZyndioTc025Colors.light;
      expect(l.segmentBg, const Color(0xFFF0F2F5));
      expect(l.segmentText, const Color(0xFF1F2837));
      expect(l.tileBg, const Color(0xFFF0F2F5));
      expect(l.deltaNeutral, const Color(0xFF1F2837));
      expect(l.deltaFavourable, const Color(0xFF0E7F48));
      expect(l.deltaUnfavourable, const Color(0xFFB42318));
      expect(l.badgeActiveBg, const Color(0xFFE3F7EC));
      expect(l.badgeActiveText, const Color(0xFF0B6E3D));
      expect(l.tabActive, const Color(0xFF031943));
      expect(l.tabInactive, const Color(0xFF626B7C));
      expect(l.screenBg, const Color(0xFFF6F7F9));
    });

    test('dark tokens match tokens-tc025.additions.json', () {
      const d = ZyndioTc025Colors.dark;
      expect(d.segmentBg, const Color(0xFF1A2133));
      expect(d.segmentText, const Color(0xFFD5DBEA));
      expect(d.tileBg, const Color(0xFF141B2E));
      expect(d.deltaNeutral, const Color(0xFFD5DBEA));
      expect(d.deltaFavourable, const Color(0xFF4BD98F));
      expect(d.deltaUnfavourable, const Color(0xFFFF9B8F));
      expect(d.badgeActiveText, const Color(0xFF6EE7A8));
      expect(d.tabActive, const Color(0xFF9CD6F7));
      expect(d.screenBg, const Color(0xFF070A14));
    });

    test('brand gradient is the brand navy (premium pass, no purple)', () {
      expect(ZyndioGradients.brand.colors,
          const [Color(0xFF0B2A5E), Color(0xFF031943)]);
      expect(ZyndioGradients.segmentActive.colors,
          const [Color(0xFF031943), Color(0xFF031943)]);
    });

    test('both themes register the TC-025 extension', () {
      expect(BrandTheme.lightTheme.extension<ZyndioTc025Colors>(),
          ZyndioTc025Colors.light);
      expect(BrandTheme.darkTheme.extension<ZyndioTc025Colors>(),
          ZyndioTc025Colors.dark);
    });
  });

  group('TC-025 delta.neutral contrast — computed, not hard-coded (specs §4)', () {
    test('light: deltaNeutral ≥ AA on surface, tile and screen bg', () {
      const l = ZyndioTc025Colors.light;
      const surface = Color(0xFFFFFFFF);
      // spec: 12.72 on surface, 11.43 on tile, 11.98 on screen
      expect(_contrast(l.deltaNeutral, surface), greaterThan(12.0));
      expect(_contrast(l.deltaNeutral, l.tileBg), greaterThan(11.0));
      expect(_contrast(l.deltaNeutral, l.screenBg), greaterThan(11.0));
    });

    test('dark: deltaNeutral ≥ AA on surface, tile and screen bg', () {
      const d = ZyndioTc025Colors.dark;
      const surface = Color(0xFF10141F);
      // spec: 13.27 on surface, 12.36 on tile, 14.26 on screen
      expect(_contrast(d.deltaNeutral, surface), greaterThan(12.5));
      expect(_contrast(d.deltaNeutral, d.tileBg), greaterThan(12.0));
      expect(_contrast(d.deltaNeutral, d.screenBg), greaterThan(13.5));
    });

    test('Active badge text passes AA on its badge fill (both brightnesses)', () {
      expect(
          _contrast(ZyndioTc025Colors.light.badgeActiveText,
              ZyndioTc025Colors.light.badgeActiveBg),
          greaterThan(4.5));
      expect(
          _contrast(ZyndioTc025Colors.dark.badgeActiveText,
              ZyndioTc025Colors.dark.badgeActiveBg),
          greaterThan(4.5));
    });

    // M2 (Ava, PR #30 review): dark chart marks were < 3:1 on the lab band.
    test('M2: chart tokens — brand blue to teal, dark lifted', () {
      const l = ZyndioTc025Colors.light;
      expect(l.chartLineStart, const Color(0xFF0962C0));
      expect(l.chartLineEnd, const Color(0xFF0E839C));
      expect(l.chartPointStroke, const Color(0xFF0962C0));
      const d = ZyndioTc025Colors.dark;
      expect(d.chartLineStart, const Color(0xFF0B6FD6));
      expect(d.chartLineEnd, const Color(0xFF4FB8F2));
      expect(d.chartPointStroke, const Color(0xFF4FB8F2));
    });

    test('M2: dark chart marks ≥ 3:1 on the lab band and the surface (1.4.11)', () {
      const d = ZyndioTc025Colors.dark;
      const surface = Color(0xFF10141F);
      for (final mark in [d.chartLineStart, d.chartLineEnd, d.chartPointStroke]) {
        expect(_contrast(mark, d.badgeActiveBg), greaterThanOrEqualTo(3.0),
            reason: '$mark on band');
        expect(_contrast(mark, surface), greaterThanOrEqualTo(3.0),
            reason: '$mark on surface');
      }
      // Measured for the premium-pass brand blue (was 4.77 / 3.96 for the
      // purple stops); the >= 3:1 rule above is what must hold.
      expect(_contrast(d.chartPointStroke, d.badgeActiveBg), closeTo(6.91, 0.02));
      expect(_contrast(d.chartLineEnd, d.badgeActiveBg), closeTo(6.91, 0.02));
    });

    test('sanity: contrast helper gives 21:1 for black on white', () {
      expect(_contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          closeTo(21.0, 0.1));
    });
  });
}
