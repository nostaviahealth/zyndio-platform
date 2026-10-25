import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

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

/// Zyndio Theme Configuration
class BrandTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: BrandColors.dark,
      scaffoldBackgroundColor: BrandColors.background,
      colorScheme: ColorScheme.light(
        primary: BrandColors.dark,
        secondary: BrandColors.gold,
        surface: Colors.white,
        error: BrandColors.red500,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.dark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BrandColors.dark,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: BrandColors.sageDark,
        unselectedItemColor: BrandColors.slate400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: BrandColors.slate100),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandColors.dark, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: BrandColors.slate400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.dark,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.dark,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: _lightTextTheme,
      extensions: const [BrandThemeColors.light],
    );
  }

  static ThemeData get darkTheme {
    const c = BrandThemeColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Colors.white,
      scaffoldBackgroundColor: c.scaffoldBg,
      canvasColor: Colors.black,
      cardColor: c.cardSurface,
      dialogBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.dark(
        primary: Colors.white,
        secondary: BrandColors.gold,
        surface: const Color(0xFF1E293B),
        onSurface: c.textPrimary,
        error: BrandColors.red500,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.cardSurface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.navbarBg,
        selectedItemColor: Colors.white,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: c.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: _darkTextTheme,
      extensions: const [BrandThemeColors.dark],
    );
  }

  static TextTheme get _lightTextTheme {
    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: BrandColors.dark,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: BrandColors.dark,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: BrandColors.dark,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: BrandColors.dark,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: BrandColors.dark,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: BrandColors.dark,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: BrandColors.dark,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: BrandColors.slate600,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: BrandColors.slate500,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: BrandColors.slate700,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: BrandColors.slate600,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: BrandColors.slate500,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: BrandColors.slate400,
      ),
    );
  }

  static TextTheme get _darkTextTheme {
    const c = BrandThemeColors.dark;
    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: c.textPrimary,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: c.textPrimary,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: c.textTertiary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: c.textSecondary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: c.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: c.textTertiary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: c.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: c.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: c.textTertiary,
      ),
    );
  }
}
