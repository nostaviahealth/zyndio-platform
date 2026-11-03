import 'package:flutter/material.dart';

/// Zyndio Color Palette
/// Matches the React web app design system
class BrandColors {
  // Primary Colors
  static const Color dark = Color(0xFF0F172A);
  static const Color gold = Color(0xFFF59E0B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color sageDark = Color(0xFF334155);

  // Slate Scale
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color orange50 = Color(0xFFFFF7ED);
  static const Color orange100 = Color(0xFFFFEDD5); // Added
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Accent Colors
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald800 = Color(0xFF065F46); // Added for Rhythm Card
  static const Color purple400 = Color(0xFFA78BFA);
  static const Color purple500 = Color(0xFF8B5CF6);
  static const Color purple600 = Color(0xFF7C3AED);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color orange400 = Color(0xFFFB923C);
  static const Color orange500 = Color(0xFFF97316);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color indigo100 = Color(0xFFE0E7FF); // Added
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo900 = Color(0xFF312E81); // Added for AI Card
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
}

// ─────────────────────────────────────────────────────────────
// ZYNDIO DESIGN TOKENS — generated from design/handoff/tokens/zyndio-site.tokens.json
// ─────────────────────────────────────────────────────────────

/// Semantic colour tokens (1:1 with color.* in the tokens JSON). Read via
/// `Theme.of(context).extension<ZyndioColors>()!`.
@immutable
class ZyndioColors extends ThemeExtension<ZyndioColors> {
  const ZyndioColors({required this.bgCanvas, required this.bgSurface, required this.bgSunken, required this.textPrimary, required this.textSecondary, required this.textTertiary, required this.borderSubtle, required this.borderStrong, required this.brandPrimary, required this.brandOnPrimary, required this.brandSubtle, required this.brandOnSubtle, required this.actionSecondary, required this.actionOnSecondary, required this.statusSuccess, required this.statusSuccessSubtle, required this.statusWarning, required this.statusWarningSubtle, required this.statusCritical, required this.statusCriticalSubtle, required this.chartLine, required this.chartRange, required this.focusRing});

  /// Screen background
  final Color bgCanvas;
  /// Cards, sheets, inputs, tab bar
  final Color bgSurface;
  /// Skeletons, segmented track, inset areas
  final Color bgSunken;
  /// Headings, body, values
  final Color textPrimary;
  /// Supporting copy
  final Color textSecondary;
  /// Meta, captions, units (contrast ratio >= 4.5:1 on surface & sunken)
  final Color textTertiary;
  /// Dividers, card hairlines (decorative, no contrast requirement)
  final Color borderSubtle;
  /// Input/outline-button borders, unchecked controls (contrast ratio >= 3:1)
  final Color borderStrong;
  /// PLACEHOLDER brand: primary buttons, links, active tab, selected controls
  final Color brandPrimary;
  /// Text/icons on brand.primary
  final Color brandOnPrimary;
  /// PLACEHOLDER brand tint: info banners, brand badge
  final Color brandSubtle;
  /// Text on brand.subtle
  final Color brandOnSubtle;
  /// Strong secondary button fill (near-black / inverse)
  final Color actionSecondary;
  /// Text on action.secondary
  final Color actionOnSecondary;
  /// Success text/icon
  final Color statusSuccess;
  /// Success banner/badge fill
  final Color statusSuccessSubtle;
  /// Warning text/icon
  final Color statusWarning;
  /// Warning banner/badge fill, FICTIONAL DATA tag
  final Color statusWarningSubtle;
  /// Error text/icon/field border
  final Color statusCritical;
  /// Error banner/badge fill
  final Color statusCriticalSubtle;
  /// Trend line & points
  final Color chartLine;
  /// Default-range band
  final Color chartRange;
  /// Keyboard/switch-control focus ring
  final Color focusRing;

  static const light = ZyndioColors(
    bgCanvas: Color(0xFFF1F4FC),
    bgSurface: Color(0xFFFFFFFF),
    bgSunken: Color(0xFFE6ECFA),
    textPrimary: Color(0xFF030616),
    textSecondary: Color(0xFF48556A),
    textTertiary: Color(0xFF56637B),
    borderSubtle: Color(0xFFDEE5F5),
    borderStrong: Color(0xFF7A86A0),
    brandPrimary: Color(0xFF2C5CF2),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandSubtle: Color(0xFFDEEAFC),
    brandOnSubtle: Color(0xFF2346DD),
    actionSecondary: Color(0xFF030616),
    actionOnSecondary: Color(0xFFFFFFFF),
    statusSuccess: Color(0xFF15784A),
    statusSuccessSubtle: Color(0xFFE3F5EC),
    statusWarning: Color(0xFF8A4F00),
    statusWarningSubtle: Color(0xFFFBEFD8),
    statusCritical: Color(0xFFB42318),
    statusCriticalSubtle: Color(0xFFFCE8E6),
    chartLine: Color(0xFF2C5CF2),
    chartRange: Color(0xFFE3F5EC),
    focusRing: Color(0xFF2346DD),
  );

  static const dark = ZyndioColors(
    bgCanvas: Color(0xFF070A14),
    bgSurface: Color(0xFF10141F),
    bgSunken: Color(0xFF0B0F19),
    textPrimary: Color(0xFFEEF1F8),
    textSecondary: Color(0xFFA6B0C3),
    textTertiary: Color(0xFF8F9AAF),
    borderSubtle: Color(0xFF222838),
    borderStrong: Color(0xFF6C7690),
    brandPrimary: Color(0xFF7C9CFF),
    brandOnPrimary: Color(0xFF030616),
    brandSubtle: Color(0xFF18224A),
    brandOnSubtle: Color(0xFFAFC3FF),
    actionSecondary: Color(0xFFF1F4FC),
    actionOnSecondary: Color(0xFF030616),
    statusSuccess: Color(0xFF5FD39A),
    statusSuccessSubtle: Color(0xFF0F2A1D),
    statusWarning: Color(0xFFF2B65A),
    statusWarningSubtle: Color(0xFF2F220D),
    statusCritical: Color(0xFFFF8F86),
    statusCriticalSubtle: Color(0xFF3A1614),
    chartLine: Color(0xFF7C9CFF),
    chartRange: Color(0xFF0F2A1D),
    focusRing: Color(0xFFAFC3FF),
  );

  @override
  ZyndioColors copyWith({Color? bgCanvas, Color? bgSurface, Color? bgSunken, Color? textPrimary, Color? textSecondary, Color? textTertiary, Color? borderSubtle, Color? borderStrong, Color? brandPrimary, Color? brandOnPrimary, Color? brandSubtle, Color? brandOnSubtle, Color? actionSecondary, Color? actionOnSecondary, Color? statusSuccess, Color? statusSuccessSubtle, Color? statusWarning, Color? statusWarningSubtle, Color? statusCritical, Color? statusCriticalSubtle, Color? chartLine, Color? chartRange, Color? focusRing}) => ZyndioColors(
        bgCanvas: bgCanvas ?? this.bgCanvas,
        bgSurface: bgSurface ?? this.bgSurface,
        bgSunken: bgSunken ?? this.bgSunken,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        borderSubtle: borderSubtle ?? this.borderSubtle,
        borderStrong: borderStrong ?? this.borderStrong,
        brandPrimary: brandPrimary ?? this.brandPrimary,
        brandOnPrimary: brandOnPrimary ?? this.brandOnPrimary,
        brandSubtle: brandSubtle ?? this.brandSubtle,
        brandOnSubtle: brandOnSubtle ?? this.brandOnSubtle,
        actionSecondary: actionSecondary ?? this.actionSecondary,
        actionOnSecondary: actionOnSecondary ?? this.actionOnSecondary,
        statusSuccess: statusSuccess ?? this.statusSuccess,
        statusSuccessSubtle: statusSuccessSubtle ?? this.statusSuccessSubtle,
        statusWarning: statusWarning ?? this.statusWarning,
        statusWarningSubtle: statusWarningSubtle ?? this.statusWarningSubtle,
        statusCritical: statusCritical ?? this.statusCritical,
        statusCriticalSubtle: statusCriticalSubtle ?? this.statusCriticalSubtle,
        chartLine: chartLine ?? this.chartLine,
        chartRange: chartRange ?? this.chartRange,
        focusRing: focusRing ?? this.focusRing,
      );

  @override
  ZyndioColors lerp(ThemeExtension<ZyndioColors>? other, double t) {
    if (other is! ZyndioColors) return this;
    return ZyndioColors(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgSunken: Color.lerp(bgSunken, other.bgSunken, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandOnPrimary: Color.lerp(brandOnPrimary, other.brandOnPrimary, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      brandOnSubtle: Color.lerp(brandOnSubtle, other.brandOnSubtle, t)!,
      actionSecondary: Color.lerp(actionSecondary, other.actionSecondary, t)!,
      actionOnSecondary: Color.lerp(actionOnSecondary, other.actionOnSecondary, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusSuccessSubtle: Color.lerp(statusSuccessSubtle, other.statusSuccessSubtle, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusWarningSubtle: Color.lerp(statusWarningSubtle, other.statusWarningSubtle, t)!,
      statusCritical: Color.lerp(statusCritical, other.statusCritical, t)!,
      statusCriticalSubtle: Color.lerp(statusCriticalSubtle, other.statusCriticalSubtle, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
      chartRange: Color.lerp(chartRange, other.chartRange, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

/// Type scale (1:1 with typography.*). height = lineHeight / fontSize; letterSpacing in logical px.
/// Sizes are the default (Large) Dynamic Type size; Flutter scales them with MediaQuery.textScaler. Do not clamp below 2.0.
abstract final class ZyndioType {
  static const String family = 'Inter';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
  static const TextStyle display = TextStyle(fontFamily: family, fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w700, letterSpacing: -0.85);
  static const TextStyle title1 = TextStyle(fontFamily: family, fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.7);
  static const TextStyle title2 = TextStyle(fontFamily: family, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, letterSpacing: -0.55);
  static const TextStyle title3 = TextStyle(fontFamily: family, fontSize: 20, height: 24 / 20, fontWeight: FontWeight.w600, letterSpacing: 0);
  static const TextStyle headline = TextStyle(fontFamily: family, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, letterSpacing: 0);
  static const TextStyle body = TextStyle(fontFamily: family, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w400, letterSpacing: 0);
  static const TextStyle callout = TextStyle(fontFamily: family, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, letterSpacing: 0);
  static const TextStyle subhead = TextStyle(fontFamily: family, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w400, letterSpacing: 0);
  static const TextStyle footnote = TextStyle(fontFamily: family, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, letterSpacing: 0);
  static const TextStyle caption = TextStyle(fontFamily: family, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0);
  static const TextStyle numericHero = TextStyle(fontFamily: family, fontSize: 44, height: 48 / 44, fontWeight: FontWeight.w700, letterSpacing: 0, fontFeatures: tabular);

  /// Lab values, dates in tables, deltas: always tabular figures.
  static TextStyle numeric(TextStyle base) => base.copyWith(fontFeatures: tabular);

  static TextTheme textTheme(Color primary, Color muted) => TextTheme(
        headlineLarge: display.copyWith(color: primary),
        headlineMedium: title1.copyWith(color: primary),
        headlineSmall: title2.copyWith(color: primary),
        titleLarge: title3.copyWith(color: primary),
        titleMedium: headline.copyWith(color: primary),
        bodyLarge: body.copyWith(color: primary),
        bodyMedium: callout.copyWith(color: primary),
        labelLarge: subhead.copyWith(color: primary),
        bodySmall: footnote.copyWith(color: muted),
        labelSmall: caption.copyWith(color: muted),
      );
}

/// 8pt grid (4 allowed for tight inline gaps)
abstract final class ZyndioSpace {
  static const double s0 = 0.0;
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;
}

/// Corner radii; button/pill 999 = StadiumBorder
abstract final class ZyndioRadius {
  static const double sm = 10.0;
  static const double md = 16.0;
  static const double lg = 16.0;
  static const double button = 999.0;
  static const double pill = 999.0;
}

/// Component sizes; every interactive hit area >= touchMin
abstract final class ZyndioSize {
  static const double touchMin = 44.0;
  static const double buttonHeight = 52.0;
  static const double buttonSmallHeight = 44.0;
  static const double fieldHeight = 48.0;
  static const double rowMin = 56.0;
  static const double historyRowMin = 48.0;
  static const double navBarHeight = 44.0;
  static const double tabBarHeight = 83.0;
  static const double segmentedHeight = 44.0;
  static const double otpCellWidth = 48.0;
  static const double otpCellHeight = 56.0;
  static const double checkbox = 24.0;
  static const double switchWidth = 51.0;
  static const double switchHeight = 31.0;
  static const double switchKnob = 25.0;
  static const double icon = 24.0;
  static const double iconSmall = 18.0;
  static const double spinner = 20.0;
  static const double progressHeight = 4.0;
  static const double chartHeight = 176.0;
}

/// Stroke widths
abstract final class ZyndioBorder {
  static const double hairline = 1.0;
  static const double control = 2.0;
  static const double focus = 3.0;
}

/// Card shadow (light only; dark = none).
abstract final class ZyndioShadow {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A030616), offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0),
    BoxShadow(color: Color(0x142C5CF2), offset: Offset(0, 8), blurRadius: 24, spreadRadius: 0),
  ];
  static List<BoxShadow> cardFor(Brightness b) => b == Brightness.light ? card : const [];
}

/// Motion. Use [ZyndioMotion.of] so OS Reduce Motion (MediaQuery.disableAnimations) collapses to 0.
abstract final class ZyndioMotion {
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration reduced = Duration(milliseconds: 0);
  static Duration of(BuildContext context) => MediaQuery.of(context).disableAnimations ? reduced : standard;
}

/// ThemeData for light/dark built from the Zyndio tokens. Material widgets are themed to the
/// spec; custom widgets should read colours from [ZyndioColors] (or the legacy [BrandThemeColors]
/// via `context.nc`), never hex literals.
ThemeData _zyndioThemeData(Brightness brightness) {
  final c = brightness == Brightness.light ? ZyndioColors.light : ZyndioColors.dark;
  final legacy = brightness == Brightness.light ? BrandThemeColors.light : BrandThemeColors.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brandPrimary,
    onPrimary: c.brandOnPrimary,
    primaryContainer: c.brandSubtle,
    onPrimaryContainer: c.brandOnSubtle,
    secondary: c.actionSecondary,
    onSecondary: c.actionOnSecondary,
    error: c.statusCritical,
    onError: c.brandOnPrimary,
    errorContainer: c.statusCriticalSubtle,
    onErrorContainer: c.statusCritical,
    surface: c.bgSurface,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerHighest: c.bgSunken,
    outline: c.borderStrong,
    outlineVariant: c.borderSubtle,
  );
  final text = ZyndioType.textTheme(c.textPrimary, c.textTertiary);
  const pill = StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bgCanvas,
    fontFamily: ZyndioType.family,
    textTheme: text,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
    extensions: <ThemeExtension<dynamic>>[
      c,
      legacy,
      brightness == Brightness.light ? ZyndioTc025Colors.light : ZyndioTc025Colors.dark,
    ],
    dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: ZyndioBorder.hairline, space: ZyndioBorder.hairline),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: c.brandPrimary, foregroundColor: c.brandOnPrimary,
      minimumSize: const Size(ZyndioSize.touchMin, ZyndioSize.buttonHeight), shape: pill,
      textStyle: ZyndioType.headline, padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s24))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      backgroundColor: c.bgSurface, foregroundColor: c.textPrimary, side: BorderSide(color: c.borderStrong),
      minimumSize: const Size(ZyndioSize.touchMin, ZyndioSize.buttonHeight), shape: pill, textStyle: ZyndioType.headline)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: c.brandPrimary, foregroundColor: c.brandOnPrimary,
      padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s24, vertical: ZyndioSpace.s16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZyndioRadius.sm)),
      textStyle: ZyndioType.headline)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      foregroundColor: c.brandPrimary, minimumSize: const Size(ZyndioSize.touchMin, ZyndioSize.touchMin),
      textStyle: ZyndioType.subhead.copyWith(fontWeight: FontWeight.w600))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.bgSurface,
      constraints: const BoxConstraints(minHeight: ZyndioSize.fieldHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZyndioRadius.sm), borderSide: BorderSide(color: c.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZyndioRadius.sm), borderSide: BorderSide(color: c.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZyndioRadius.sm), borderSide: BorderSide(color: c.focusRing, width: ZyndioBorder.focus)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZyndioRadius.sm), borderSide: BorderSide(color: c.statusCritical, width: ZyndioBorder.control)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZyndioRadius.sm), borderSide: BorderSide(color: c.statusCritical, width: ZyndioBorder.focus)),
      labelStyle: ZyndioType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
      errorStyle: ZyndioType.footnote.copyWith(color: c.statusCritical), errorMaxLines: 3,
      hintStyle: ZyndioType.body.copyWith(color: c.textTertiary)),
    cardTheme: CardThemeData(color: c.bgSurface, elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZyndioRadius.lg), side: BorderSide(color: c.borderSubtle))),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brandPrimary : c.bgSurface),
      checkColor: WidgetStatePropertyAll(c.brandOnPrimary),
      side: BorderSide(color: c.borderStrong, width: ZyndioBorder.control),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brandPrimary : c.bgSunken),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brandPrimary : c.borderStrong),
      thumbColor: WidgetStatePropertyAll(c.bgSurface)),
    segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(
      backgroundColor: c.bgSunken, foregroundColor: c.textSecondary,
      selectedBackgroundColor: c.bgSurface, selectedForegroundColor: c.textPrimary,
      side: BorderSide.none, minimumSize: const Size(ZyndioSize.touchMin, ZyndioSize.segmentedHeight),
      textStyle: ZyndioType.footnote.copyWith(fontWeight: FontWeight.w600), shape: pill)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brandPrimary, linearTrackColor: c.bgSunken, circularTrackColor: c.brandSubtle),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bgSurface, indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: ZyndioSize.icon, color: s.contains(WidgetState.selected) ? c.brandPrimary : c.textTertiary)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => ZyndioType.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? c.brandPrimary : c.textTertiary))),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.bgSurface, selectedItemColor: c.brandPrimary, unselectedItemColor: c.textTertiary,
      type: BottomNavigationBarType.fixed, elevation: 0),
    appBarTheme: AppBarTheme(backgroundColor: c.bgCanvas, foregroundColor: c.brandPrimary, elevation: 0, scrolledUnderElevation: 0,
      titleTextStyle: ZyndioType.headline.copyWith(color: c.textPrimary), toolbarHeight: ZyndioSize.navBarHeight),
    snackBarTheme: SnackBarThemeData(backgroundColor: c.actionSecondary, contentTextStyle: ZyndioType.subhead.copyWith(color: c.actionOnSecondary)),
  );
}

// ─────────────────────────────────────────────────────────────
// ZYNDIO THEME EXTENSION — Semantic color tokens
// ─────────────────────────────────────────────────────────────

/// Semantic color tokens that adapt to light/dark mode.
/// Access via `Theme.of(context).extension<BrandThemeColors>()!`
/// or the shorthand `context.nc`.
class BrandThemeColors extends ThemeExtension<BrandThemeColors> {
  final Color primary;
  final Color scaffoldBg;
  final Color cardSurface;
  final Color cardSurfaceElevated;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnDark;       // Text/icons on dark-colored surfaces (always white-ish)
  final Color iconDefault;
  final Color iconSubtle;
  final Color divider;
  final Color navbarBg;
  final Color navbarPillBg;
  final Color inputFill;
  final Color inputBorder;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color glassBg;          // Glassmorphism / frosted backgrounds
  final Color glassBorder;
  final Color shadowColor;
  final bool isDark;

  const BrandThemeColors({
    required this.primary,
    required this.scaffoldBg,
    required this.cardSurface,
    required this.cardSurfaceElevated,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnDark,
    required this.iconDefault,
    required this.iconSubtle,
    required this.divider,
    required this.navbarBg,
    required this.navbarPillBg,
    required this.inputFill,
    required this.inputBorder,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.glassBg,
    required this.glassBorder,
    required this.shadowColor,
    required this.isDark,
  });

  // ── LIGHT MODE ──
  static const light = BrandThemeColors(
    primary: Color(0xFF3B82F6),          // blue500
    scaffoldBg: Color(0xFFF8FAFC),       // slate50
    cardSurface: Colors.white,
    cardSurfaceElevated: Colors.white,
    cardBorder: Color(0xFFF1F5F9),       // slate100
    textPrimary: Color(0xFF0F172A),      // dark
    textSecondary: Color(0xFF475569),    // slate600
    textTertiary: Color(0xFF94A3B8),     // slate400
    textOnDark: Colors.white,
    iconDefault: Color(0xFF475569),      // slate600
    iconSubtle: Color(0xFF94A3B8),       // slate400
    divider: Color(0xFFE2E8F0),          // slate200
    navbarBg: Colors.white,
    navbarPillBg: Color(0xFFF2F2F7),
    inputFill: Color(0xFFF8FAFC),        // slate50
    inputBorder: Color(0xFFE2E8F0),      // slate200
    shimmerBase: Color(0xFFE2E8F0),
    shimmerHighlight: Color(0xFFF8FAFC),
    glassBg: Color(0xCCFFFFFF),          // white 80%
    glassBorder: Color(0x59FFFFFF),      // white 35%
    shadowColor: Color(0x14000000),      // black 8%
    isDark: false,
  );

  // ── DARK MODE (Premium Intelligence) ──
  static const dark = BrandThemeColors(
    primary: Color(0xFF3B82F6),          // blue500
    scaffoldBg: Color(0xFF020617),       // Deep Obsidian (slate-950)
    cardSurface: Color(0x401E293B),      // 25% Slate-800 Glass (High transparency)
    cardSurfaceElevated: Color(0x66334155), // 40% Slate-700 Glass
    cardBorder: Color(0x4DFFFFFF),       // 30% White border (Glassy edge)
    textPrimary: Color(0xFFF8FAFC),      // slate-50
    textSecondary: Color(0xFFCBD5E1),    // slate-300
    textTertiary: Color(0xFF94A3B8),     // slate-400
    textOnDark: Colors.white,
    iconDefault: Color(0xFFCBD5E1),      // slate-300
    iconSubtle: Color(0xFF64748B),       // slate-500
    divider: Color(0x1EFFFFFF),          // 12% white divider
    navbarBg: Color(0x80020617),         // 50% navbar glass
    navbarPillBg: Color(0x661E293B),     // 40% pill glass
    inputFill: Color(0x331E293B),        // 20% transparent input
    inputBorder: Color(0x1EFFFFFF),      // 12% white border
    shimmerBase: Color(0xFF1E293B),
    shimmerHighlight: Color(0xFF334155),
    glassBg: Color(0x4D0F172A),          // 30% slate-900 glass
    glassBorder: Color(0x40FFFFFF),      // 25% white border
    shadowColor: Color(0x66000000),      // black 40%
    isDark: true,
  );

  @override
  BrandThemeColors copyWith({
    Color? primary,
    Color? scaffoldBg,
    Color? cardSurface,
    Color? cardSurfaceElevated,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnDark,
    Color? iconDefault,
    Color? iconSubtle,
    Color? divider,
    Color? navbarBg,
    Color? navbarPillBg,
    Color? inputFill,
    Color? inputBorder,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? glassBg,
    Color? glassBorder,
    Color? shadowColor,
    bool? isDark,
  }) {
    return BrandThemeColors(
      primary: primary ?? this.primary,
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardSurface: cardSurface ?? this.cardSurface,
      cardSurfaceElevated: cardSurfaceElevated ?? this.cardSurfaceElevated,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnDark: textOnDark ?? this.textOnDark,
      iconDefault: iconDefault ?? this.iconDefault,
      iconSubtle: iconSubtle ?? this.iconSubtle,
      divider: divider ?? this.divider,
      navbarBg: navbarBg ?? this.navbarBg,
      navbarPillBg: navbarPillBg ?? this.navbarPillBg,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      glassBg: glassBg ?? this.glassBg,
      glassBorder: glassBorder ?? this.glassBorder,
      shadowColor: shadowColor ?? this.shadowColor,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  BrandThemeColors lerp(ThemeExtension<BrandThemeColors>? other, double t) {
    if (other is! BrandThemeColors) return this;
    return BrandThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardSurfaceElevated: Color.lerp(cardSurfaceElevated, other.cardSurfaceElevated, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnDark: Color.lerp(textOnDark, other.textOnDark, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconSubtle: Color.lerp(iconSubtle, other.iconSubtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      navbarBg: Color.lerp(navbarBg, other.navbarBg, t)!,
      navbarPillBg: Color.lerp(navbarPillBg, other.navbarPillBg, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      glassBg: Color.lerp(glassBg, other.glassBg, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Convenience extension — use `context.nc` anywhere
extension BrandThemeX on BuildContext {
  BrandThemeColors get nc =>
      Theme.of(this).extension<BrandThemeColors>() ?? BrandThemeColors.dark;

  bool get isDarkMode => nc.isDark;
}

// ─────────────────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// TC-025 TOKENS — Brett's 5-tab patient UI (Ava Rev 2, 1 Nov 2026)
// Additive block. Source: handoff/tc-025/tokens-tc025.additions.json.
// Kept as a NEW ThemeExtension (not folded into ZyndioColors) so this stays a
// self-contained block and the later #29 theme.dart merge is trivial.
// ─────────────────────────────────────────────────────────────

/// Brand gradients (identical in light and dark per the tokens file).
abstract final class ZyndioGradients {
  /// Primary CTA / Schedule / avatar, 90°. White text ≥ 4.93:1 on every stop.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF7444F0), Color(0xFF3D5BF5), Color(0xFF0B6FD6)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Active segment/filter pill. White 14/600 ≥ 5.49:1.
  static const LinearGradient segmentActive = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF7444F0), Color(0xFF6A45F0)],
  );
}

/// TC-025 semantic colours, light (`$value`) and dark (`app.dark`).
/// Read via `context.z25` or `Theme.of(context).extension<ZyndioTc025Colors>()!`.
@immutable
class ZyndioTc025Colors extends ThemeExtension<ZyndioTc025Colors> {
  const ZyndioTc025Colors({
    required this.segmentBg,
    required this.segmentText,
    required this.tileBg,
    required this.deltaNeutral,
    required this.deltaFavourable,
    required this.deltaUnfavourable,
    required this.badgeActiveBg,
    required this.badgeActiveText,
    required this.badgeNeutralBg,
    required this.badgeNeutralText,
    required this.tabActive,
    required this.tabInactive,
    required this.critText,
    required this.critBg,
    required this.warnText,
    required this.warnBg,
    required this.screenBg,
  });

  /// Inactive segment pill fill
  final Color segmentBg;

  /// Inactive segment pill text
  final Color segmentText;

  /// Today wearable tiles / Progress scan panels
  final Color tileBg;

  /// USED for all deltas, changes and compare values (never red/green).
  final Color deltaNeutral;

  /// DEFINED-UNUSED until Zyndio's clinical lead confirms direction per metric.
  final Color deltaFavourable;

  /// DEFINED-UNUSED (see [deltaFavourable]).
  final Color deltaUnfavourable;

  /// Active (e.g. plan) status badge fill
  final Color badgeActiveBg;

  /// Active status badge text
  final Color badgeActiveText;

  /// Neutral (Paused/Stopped/Coming soon) badge fill
  final Color badgeNeutralBg;

  /// Neutral badge text
  final Color badgeNeutralText;

  /// Active tab colour
  final Color tabActive;

  /// Inactive tab colour
  final Color tabInactive;

  /// Error banner text/icon
  final Color critText;

  /// Error banner fill
  final Color critBg;

  /// Warning (offline / missed reminder) banner text/icon
  final Color warnText;

  /// Warning banner fill
  final Color warnBg;

  /// Screen background for the 5 patient tabs
  final Color screenBg;

  static const light = ZyndioTc025Colors(
    segmentBg: Color(0xFFEEF0F5),
    segmentText: Color(0xFF283152),
    tileBg: Color(0xFFEAF4FF),
    deltaNeutral: Color(0xFF283152),
    deltaFavourable: Color(0xFF0E7F48),
    deltaUnfavourable: Color(0xFFB42318),
    badgeActiveBg: Color(0xFFE3F7EC),
    badgeActiveText: Color(0xFF0B6E3D),
    badgeNeutralBg: Color(0xFFEEF0F5),
    badgeNeutralText: Color(0xFF3A4463),
    tabActive: Color(0xFF2C4DFE),
    tabInactive: Color(0xFF4A5470),
    critText: Color(0xFFB42318),
    critBg: Color(0xFFFEF0EE),
    warnText: Color(0xFF8A4B00),
    warnBg: Color(0xFFFFF4E2),
    screenBg: Color(0xFFF7F8FC),
  );

  static const dark = ZyndioTc025Colors(
    segmentBg: Color(0xFF1A2133),
    segmentText: Color(0xFFD5DBEA),
    tileBg: Color(0xFF141B2E),
    deltaNeutral: Color(0xFFD5DBEA),
    deltaFavourable: Color(0xFF4BD98F),
    deltaUnfavourable: Color(0xFFFF9B8F),
    badgeActiveBg: Color(0xFF0F2A1E),
    badgeActiveText: Color(0xFF6EE7A8),
    badgeNeutralBg: Color(0xFF1A2133),
    badgeNeutralText: Color(0xFFD5DBEA),
    tabActive: Color(0xFF9DB2FF),
    tabInactive: Color(0xFFA6B0C3),
    critText: Color(0xFFFF9B8F),
    critBg: Color(0xFF2A1414),
    warnText: Color(0xFFFFC56B),
    warnBg: Color(0xFF2A2010),
    screenBg: Color(0xFF070A14),
  );

  @override
  ZyndioTc025Colors copyWith({
    Color? segmentBg,
    Color? segmentText,
    Color? tileBg,
    Color? deltaNeutral,
    Color? deltaFavourable,
    Color? deltaUnfavourable,
    Color? badgeActiveBg,
    Color? badgeActiveText,
    Color? badgeNeutralBg,
    Color? badgeNeutralText,
    Color? tabActive,
    Color? tabInactive,
    Color? critText,
    Color? critBg,
    Color? warnText,
    Color? warnBg,
    Color? screenBg,
  }) =>
      ZyndioTc025Colors(
        segmentBg: segmentBg ?? this.segmentBg,
        segmentText: segmentText ?? this.segmentText,
        tileBg: tileBg ?? this.tileBg,
        deltaNeutral: deltaNeutral ?? this.deltaNeutral,
        deltaFavourable: deltaFavourable ?? this.deltaFavourable,
        deltaUnfavourable: deltaUnfavourable ?? this.deltaUnfavourable,
        badgeActiveBg: badgeActiveBg ?? this.badgeActiveBg,
        badgeActiveText: badgeActiveText ?? this.badgeActiveText,
        badgeNeutralBg: badgeNeutralBg ?? this.badgeNeutralBg,
        badgeNeutralText: badgeNeutralText ?? this.badgeNeutralText,
        tabActive: tabActive ?? this.tabActive,
        tabInactive: tabInactive ?? this.tabInactive,
        critText: critText ?? this.critText,
        critBg: critBg ?? this.critBg,
        warnText: warnText ?? this.warnText,
        warnBg: warnBg ?? this.warnBg,
        screenBg: screenBg ?? this.screenBg,
      );

  @override
  ZyndioTc025Colors lerp(ThemeExtension<ZyndioTc025Colors>? other, double t) {
    if (other is! ZyndioTc025Colors) return this;
    return ZyndioTc025Colors(
      segmentBg: Color.lerp(segmentBg, other.segmentBg, t)!,
      segmentText: Color.lerp(segmentText, other.segmentText, t)!,
      tileBg: Color.lerp(tileBg, other.tileBg, t)!,
      deltaNeutral: Color.lerp(deltaNeutral, other.deltaNeutral, t)!,
      deltaFavourable: Color.lerp(deltaFavourable, other.deltaFavourable, t)!,
      deltaUnfavourable: Color.lerp(deltaUnfavourable, other.deltaUnfavourable, t)!,
      badgeActiveBg: Color.lerp(badgeActiveBg, other.badgeActiveBg, t)!,
      badgeActiveText: Color.lerp(badgeActiveText, other.badgeActiveText, t)!,
      badgeNeutralBg: Color.lerp(badgeNeutralBg, other.badgeNeutralBg, t)!,
      badgeNeutralText: Color.lerp(badgeNeutralText, other.badgeNeutralText, t)!,
      tabActive: Color.lerp(tabActive, other.tabActive, t)!,
      tabInactive: Color.lerp(tabInactive, other.tabInactive, t)!,
      critText: Color.lerp(critText, other.critText, t)!,
      critBg: Color.lerp(critBg, other.critBg, t)!,
      warnText: Color.lerp(warnText, other.warnText, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
      screenBg: Color.lerp(screenBg, other.screenBg, t)!,
    );
  }
}

/// `context.z25` → the TC-025 colour tokens for the active brightness.
extension ZyndioTc025X on BuildContext {
  ZyndioTc025Colors get z25 =>
      Theme.of(this).extension<ZyndioTc025Colors>() ?? ZyndioTc025Colors.light;
}

/// Zyndio Theme Configuration
class BrandTheme {
  /// Light ThemeData built from the Zyndio design tokens. Registers both
  /// [ZyndioColors] (new semantic tokens) and [BrandThemeColors] (legacy
  /// `context.nc` tokens still read by existing screens) as extensions.
  static ThemeData get lightTheme => _zyndioThemeData(Brightness.light);

  /// Dark ThemeData built from the Zyndio design tokens. See [lightTheme].
  static ThemeData get darkTheme => _zyndioThemeData(Brightness.dark);
}
