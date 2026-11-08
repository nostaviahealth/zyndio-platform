import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';

ZyndioColors zcOf(BuildContext context) =>
    Theme.of(context).extension<ZyndioColors>()!;

/// Ava handoff shell: Back link, left-aligned title/body, scroll content,
/// full-width brand-blue primary. No floating card / toggle / Google.
class PatientAuthShell extends StatelessWidget {
  const PatientAuthShell({
    super.key,
    this.backLabel,
    this.onBack,
    required this.title,
    this.subtitle,
    this.banner,
    this.hero,
    this.wordmark = false,
    required this.body,
    this.footer,
  });

  final String? backLabel;
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;
  final Widget? banner;
  final Widget? hero;
  final bool wordmark;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (backLabel != null) ...[
                      TextButton(
                        onPressed: onBack,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: c.brandPrimary,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.chevronLeft,
                                size: 20, color: c.brandPrimary),
                            const SizedBox(width: 2),
                            Text(backLabel!,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (wordmark) ...[
                      const AuthWordmark(),
                      const SizedBox(height: 32),
                    ],
                    if (hero != null) ...[
                      hero!,
                      const SizedBox(height: 20),
                    ],
                    if (banner != null) ...[
                      banner!,
                      const SizedBox(height: 16),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 28,
                        height: 36 / 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.025 * 28,
                        color: c.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    body,
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key});

  /// Official tagline from the Zyndio brand pack (zyndio-logo-wide.png).
  static const tagline = 'PHYSICIAN-LED TELEHEALTH CARE';

  /// Lockup proportions follow the official wide logo: the mark spans both
  /// text lines; "ZYNDIO" is light and widely tracked; the tagline is small,
  /// about twice the wordmark's width. The mark asset is cropped to its edges
  /// (zyndio-mark-tight.png) so its height really matches the text block.
  static const double markHeight = 44;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    return Semantics(
      container: true,
      label: 'Zyndio, physician-led telehealth care',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/zyndio-mark-tight.png',
              height: markHeight,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ZYNDIO',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 24,
                    height: 1.0,
                    letterSpacing: 0.18 * 24,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  tagline,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 9.5,
                    height: 1.0,
                    letterSpacing: 0.12 * 9.5,
                    color: c.brandOnSubtle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum AuthBannerTone { critical, warning, info, success }

class AuthStatusBanner extends StatelessWidget {
  const AuthStatusBanner({
    super.key,
    required this.message,
    this.tone = AuthBannerTone.critical,
  });

  final String message;
  final AuthBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    late Color bg, fg;
    late IconData icon;
    switch (tone) {
      case AuthBannerTone.critical:
        bg = c.statusCriticalSubtle;
        fg = c.statusCritical;
        icon = LucideIcons.triangleAlert;
      case AuthBannerTone.warning:
        bg = c.statusWarningSubtle;
        fg = c.statusWarning;
        icon = LucideIcons.wifiOff;
      case AuthBannerTone.info:
        bg = c.brandSubtle;
        fg = c.brandOnSubtle;
        icon = LucideIcons.info;
      case AuthBannerTone.success:
        bg = c.statusSuccessSubtle;
        fg = c.statusSuccess;
        icon = LucideIcons.check;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: fg, fontSize: 14, height: 20 / 14)),
          ),
        ],
      ),
    );
  }
}

class AuthLabeledField extends StatelessWidget {
  const AuthLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.errorText,
  });

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
        const SizedBox(height: 6),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.triangleAlert,
                  size: 16, color: c.statusCritical),
              const SizedBox(width: 6),
              Expanded(
                child: Text(errorText!,
                    style: TextStyle(
                        color: c.statusCritical, fontSize: 13, height: 18 / 13)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

InputDecoration authFieldDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffix,
  bool error = false,
}) {
  final c = zcOf(context);
  final borderColor = error ? c.statusCritical : c.borderStrong;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.textTertiary),
    filled: true,
    fillColor: c.bgSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: error ? c.statusCritical : c.brandPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.statusCritical, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.statusCritical, width: 2),
    ),
  );
}

// Ava R3: Inter's descenders (p, y, g) were clipped by the default tight
// line box in these button labels. height >= 1.2 plus
// applyHeightToLastDescent gives the glyph room without changing the fixed
// 50px button height.
const _kAuthButtonLabelStyle =
    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2);
const _kAuthButtonTextHeightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: true,
);

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    // Ava R2: busy buttons keep solid fill + white spinner (no fade).
    if (destructive) {
      final bg = c.statusCritical;
      final fg = c.brandOnPrimary;
      if (loading) {
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg,
              disabledForegroundColor: fg,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: _kAuthButtonLabelStyle,
                    textHeightBehavior: _kAuthButtonTextHeightBehavior),
              ],
            ),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: bg,
            side: BorderSide(color: bg, width: 1.5),
            shape: const StadiumBorder(),
          ),
          child: Text(label,
              style: _kAuthButtonLabelStyle,
              textHeightBehavior: _kAuthButtonTextHeightBehavior),
        ),
      );
    }
    final bg = c.brandPrimary;
    final fg = c.brandOnPrimary;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          // Full-strength fill while busy (Ava R2 / WCAG).
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: fg),
                  ),
                  const SizedBox(width: 10),
                  Text(label,
                      style: _kAuthButtonLabelStyle,
                      textHeightBehavior: _kAuthButtonTextHeightBehavior),
                ],
              )
            : Text(label,
                style: _kAuthButtonLabelStyle,
                textHeightBehavior: _kAuthButtonTextHeightBehavior),
      ),
    );
  }
}

class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    // Disabled label stays ≥4.5:1 (Ava R2 locked "Send a new code").
    final disabledFg = c.textSecondary;
    if (!outlined) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: c.brandPrimary,
            disabledForegroundColor: disabledFg,
          ),
          child: Text(label,
              style: _kAuthButtonLabelStyle,
              textHeightBehavior: _kAuthButtonTextHeightBehavior),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          disabledForegroundColor: disabledFg,
          side: BorderSide(
              color: onPressed == null ? c.borderSubtle : c.borderStrong),
          shape: const StadiumBorder(),
        ),
        child: Text(label,
            style: _kAuthButtonLabelStyle,
            textHeightBehavior: _kAuthButtonTextHeightBehavior),
      ),
    );
  }
}

class AuthHeroIcon extends StatelessWidget {
  const AuthHeroIcon({
    super.key,
    required this.icon,
    this.tone = AuthBannerTone.success,
  });

  final IconData icon;
  final AuthBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    late Color bg, fg;
    switch (tone) {
      case AuthBannerTone.success:
        bg = c.statusSuccessSubtle;
        fg = c.statusSuccess;
      case AuthBannerTone.critical:
        bg = c.statusCriticalSubtle;
        fg = c.statusCritical;
      case AuthBannerTone.warning:
        bg = c.statusWarningSubtle;
        fg = c.statusWarning;
      case AuthBannerTone.info:
        bg = c.brandSubtle;
        fg = c.brandOnSubtle;
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 28, color: fg),
    );
  }
}

class AuthInfoCard extends StatelessWidget {
  const AuthInfoCard({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ZyndioShadow.cardFor(brightness),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? LucideIcons.lock, size: 18, color: c.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: c.textSecondary, fontSize: 14, height: 20 / 14)),
          ),
        ],
      ),
    );
  }
}
