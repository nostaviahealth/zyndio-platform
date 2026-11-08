import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../providers/patient_provider.dart';

/// Shared TC-025 patient-tab building blocks (Brett 5-tab UI, Ava Rev 2).
/// Colours come from [context.z25] and the existing [ZyndioColors]; no hex
/// literals in screens.

/// Derive up-to-two-letter initials from a display name. Falls back to a
/// person glyph via an empty string (caller shows a person icon then).
String zyndioInitials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// Standard patient-tab scaffold (specs §1): screen bg, 16 side margin, a
/// scrolling [ZyndioBrandRow] + title + subtitle, pull-to-refresh, and bottom
/// padding so the fixed tab bar never covers content.
class ZyndioTabScaffold extends StatelessWidget {
  const ZyndioTabScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.hero,
    required this.children,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;

  /// Small spaced capitals above the title (e.g. today's date).
  final String? eyebrow;

  /// Full-bleed header that replaces the title row (Today's gradient hero).
  /// It draws under the status bar and owns its own safe-area padding.
  final Widget? hero;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(0, hero == null ? top + 6 : 0, 0, 120),
      children: [
        if (hero != null)
          hero!
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZyndioBrandRow(),
                const SizedBox(height: 18),
                ZyndioPageHeader(
                    title: title, subtitle: subtitle, eyebrow: eyebrow),
              ],
            ),
          ),
        SizedBox(height: hero == null ? 22 : 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light tabs set dark status-bar icons (Today's hero sets light ones).
      value: hero != null || dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Container(
        color: context.z25.screenBg,
        child: Stack(
          children: [
            Positioned.fill(
              child: onRefresh == null
                  ? list
                  : RefreshIndicator(onRefresh: onRefresh!, child: list),
            ),
            // Soft fade under the status bar so scrolled content never
            // collides with the clock.
            if (hero == null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: top + 8,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.7, 1.0],
                        colors: [
                          context.z25.screenBg,
                          context.z25.screenBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The patient's initials in a gradient ring; opens Profile & settings.
/// [onDark] draws it for the gradient hero (white ring, translucent fill).
class ZyndioAvatarButton extends ConsumerWidget {
  const ZyndioAvatarButton({super.key, this.onDark = false, this.size = 44});

  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final initials =
        zyndioInitials(ref.watch(patientProfileProvider).value?.name);
    final fg = onDark ? Colors.white : c.textPrimary;
    return Semantics(
      button: true,
      container: true,
      label: 'Profile and settings',
      onTap: () => context.pushNamed('settings'), // H1
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.pushNamed('settings'),
          child: SizedBox(
            width: size + 4,
            height: size + 4,
            child: Center(
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: onDark ? null : ZyndioGradients.brand,
                  color: onDark ? Colors.white.withValues(alpha: 0.55) : null,
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : c.bgSurface,
                  ),
                  child: initials.isEmpty
                      ? Icon(LucideIcons.user, size: size * 0.42, color: fg)
                      : Text(
                          initials,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: size * 0.34,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The premium card surface: white, generous radius, two soft shadows (a
/// tight contact shadow and a wide ambient one) and no outline.
BoxDecoration zyndioCard(BuildContext context,
    {double radius = 24, Color? color}) {
  final c = Theme.of(context).extension<ZyndioColors>()!;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? c.bgSurface,
    borderRadius: BorderRadius.circular(radius),
    border: dark ? Border.all(color: c.borderSubtle) : null,
    boxShadow: dark
        ? null
        : const [
            BoxShadow(
                color: Color(0x0A0E1430), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(
                color: Color(0x120E1430),
                blurRadius: 28,
                offset: Offset(0, 10)),
          ],
  );
}

/// Quiet section label that gives each tab its rhythm ("TODAY'S VITALS").
class ZyndioSectionLabel extends StatelessWidget {
  const ZyndioSectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: c.textTertiary,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Client mockup header: the Zyndio mark and "ZYNDIO AI" wordmark on the
/// left, the patient's avatar (opens Profile & settings) on the right.
class ZyndioBrandRow extends StatelessWidget {
  const ZyndioBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Row(
      children: [
        Semantics(
          label: 'Zyndio AI',
          header: false,
          child: ExcludeSemantics(
            child: Row(
              children: [
                Image.asset('assets/icons/zyndio-mark-tight.png',
                    height: 22, excludeFromSemantics: true),
                const SizedBox(width: 9),
                Text(
                  'ZYNDIO AI',
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        const ZyndioAvatarButton(),
      ],
    );
  }
}

/// Colour families for gradient icon tiles (client mockup's coloured icons).
enum ZyndioTint {
  blue([Color(0xFF4F7CFF), Color(0xFF2E62E6)], Color(0xFFEAF0FF)),
  violet([Color(0xFF8B6BFF), Color(0xFF6A4CF5)], Color(0xFFF0EBFF)),
  rose([Color(0xFFFF6B8B), Color(0xFFE5486A)], Color(0xFFFFEDF1)),
  green([Color(0xFF34D399), Color(0xFF12A36A)], Color(0xFFE5F7EF)),
  amber([Color(0xFFFFB547), Color(0xFFF08A1C)], Color(0xFFFFF3E2)),
  teal([Color(0xFF38C6E0), Color(0xFF0E94B0)], Color(0xFFE3F6FA)),
  indigo([Color(0xFF5B6CFF), Color(0xFF3B3FD8)], Color(0xFFECEDFF));

  const ZyndioTint(this.colors, this.pastel);
  final List<Color> colors;

  /// Soft tinted card surface for this colour (light mode only).
  final Color pastel;
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );
}

/// A gradient rounded-square icon with a soft coloured glow: the app's take on
/// the mockup's 3D illustrations until real product photography is supplied.
class ZyndioIconTile extends StatelessWidget {
  const ZyndioIconTile({
    super.key,
    required this.icon,
    this.tint = ZyndioTint.blue,
    this.size = 48,
  });

  final IconData icon;
  final ZyndioTint tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: tint.gradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: tint.colors.last.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.48, color: Colors.white),
    );
  }
}

/// Full-width gradient call to action (client mockup: "View My Insights →").
class ZyndioGradientButton extends StatelessWidget {
  const ZyndioGradientButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.trailingArrow = true});

  final String label;
  final VoidCallback onTap;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZyndioGradients.brand,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F57EE).withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (trailingArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight,
                      size: 18, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal segment pills at the top of a tab (client mockup): the active
/// pill is filled with the brand gradient, the rest are soft grey.
class ZyndioSegmentedTabs extends StatelessWidget {
  const ZyndioSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final z = context.z25;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: i == selected,
              label: labels[i],
              onTap: () => onSelected(i),
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          i == selected ? ZyndioGradients.segmentActive : null,
                      color: i == selected ? null : z.segmentBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: i == selected ? Colors.white : z.segmentText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Page title + subtitle (specs §1). Title is a header for semantics.
class ZyndioPageHeader extends StatelessWidget {
  const ZyndioPageHeader(
      {super.key, required this.title, this.subtitle, this.eyebrow});

  final String title;
  final String? subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 32,
              height: 38 / 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: c.textPrimary,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w400,
              color: c.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Z17 — empty / error card. Left-aligned: a small icon, title, body and an
/// optional action (44pt hit). Hairline card, no shadow.
class ZyndioStateCard extends StatelessWidget {
  const ZyndioStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: zyndioCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.z25.tileBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: c.textPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 17,
              height: 24 / 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              color: c.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                side: BorderSide(color: c.borderStrong),
                foregroundColor: c.textPrimary,
                textStyle: const TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Z11 — a tappable list row with a 56 icon chip, title + optional subline,
/// optional trailing badge, and a chevron. The whole row is one ≥44 target.
class ZyndioListRow extends StatelessWidget {
  const ZyndioListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingBadge,
    this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingBadge;

  /// When set, the icon sits in a gradient tile of this colour (mockup style).
  final ZyndioTint? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      button: true,
      label: [
        title,
        if (subtitle != null) subtitle,
        if (trailingBadge != null) trailingBadge
      ].join(', '),
      onTap: onTap, // H1: screen-reader activation == finger tap
      child: ExcludeSemantics(
        child: Container(
          decoration: zyndioCard(context, radius: 22),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    if (tint != null)
                      ZyndioIconTile(icon: icon, tint: tint!, size: 48)
                    else
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.z25.tileBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 20, color: c.textPrimary),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 16,
                              height: 22 / 16,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 14,
                                height: 20 / 14,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailingBadge != null) ...[
                      const SizedBox(width: 8),
                      _NeutralBadge(label: trailingBadge!),
                    ],
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight,
                        size: 20, color: c.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeutralBadge extends StatelessWidget {
  const _NeutralBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.z25.badgeNeutralBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: ZyndioType.family,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.z25.badgeNeutralText,
        ),
      ),
    );
  }
}

/// warn/crit state banner (Z16), a live region.
class ZyndioStateBanner extends StatelessWidget {
  const ZyndioStateBanner({
    super.key,
    required this.message,
    this.critical = false,
  });

  final String message;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final z = context.z25;
    final bg = critical ? z.critBg : z.warnBg;
    final fg = critical ? z.critText : z.warnText;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(critical ? LucideIcons.triangleAlert : LucideIcons.wifiOff,
                size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  height: 20 / 14,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
