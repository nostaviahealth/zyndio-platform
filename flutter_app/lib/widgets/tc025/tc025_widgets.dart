import 'package:flutter/material.dart';
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
    required this.children,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;

  /// Small spaced capitals above the title (e.g. today's date).
  final String? eyebrow;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        const ZyndioBrandRow(),
        const SizedBox(height: 20),
        ZyndioPageHeader(title: title, subtitle: subtitle, eyebrow: eyebrow),
        const SizedBox(height: 24),
        ...children,
      ],
    );
    return Container(
      color: context.z25.screenBg,
      child: SafeArea(
        bottom: false,
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}

/// Brand row (specs §1): 26pt Zyndio mark + "ZYNDIO AI" wordmark, and a 48pt
/// initials avatar on the right that opens Profile & settings. Scrolls with the
/// page content.
class ZyndioBrandRow extends ConsumerWidget {
  const ZyndioBrandRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final profile = ref.watch(patientProfileProvider).value;
    final initials = zyndioInitials(profile?.name);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Image.asset('assets/icons/zyndio-mark-tight.png',
              height: 24, excludeFromSemantics: true),
          const SizedBox(width: 10),
          Text(
            'ZYNDIO AI',
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.textPrimary,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            container: true,
            label: 'Profile and settings',
            onTap: () => context.pushNamed('settings'), // H1
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pushNamed('settings'),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gradient ring around the avatar (client mockup).
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: ZyndioGradients.brand,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.bgSurface,
                          ),
                          child: initials.isEmpty
                              ? Icon(LucideIcons.user, size: 20, color: c.textPrimary)
                              : Text(
                                  initials,
                                  style: TextStyle(
                                    fontFamily: ZyndioType.family,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                        ),
                      ),
                      // Online dot.
                      Positioned(
                        right: 3,
                        bottom: 4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF22C55E),
                            border: Border.all(color: c.bgSurface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour families for gradient icon tiles (client mockup's coloured icons).
enum ZyndioTint {
  blue([Color(0xFF4F7CFF), Color(0xFF2E62E6)]),
  violet([Color(0xFF8B6BFF), Color(0xFF6A4CF5)]),
  rose([Color(0xFFFF6B8B), Color(0xFFE5486A)]),
  green([Color(0xFF34D399), Color(0xFF12A36A)]),
  amber([Color(0xFFFFB547), Color(0xFFF08A1C)]),
  teal([Color(0xFF38C6E0), Color(0xFF0E94B0)]),
  indigo([Color(0xFF5B6CFF), Color(0xFF3B3FD8)]);

  const ZyndioTint(this.colors);
  final List<Color> colors;
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
  const ZyndioGradientButton({super.key, required this.label, required this.onTap, this.trailingArrow = true});

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
                  const Icon(LucideIcons.arrowRight, size: 18, color: Colors.white),
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
                      gradient: i == selected ? ZyndioGradients.segmentActive : null,
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
  const ZyndioPageHeader({super.key, required this.title, this.subtitle, this.eyebrow});

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
              fontSize: 30,
              height: 36 / 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.8,
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
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderSubtle),
      ),
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
      label: [title, if (subtitle != null) subtitle, if (trailingBadge != null) trailingBadge]
          .join(', '),
      onTap: onTap, // H1: screen-reader activation == finger tap
      child: ExcludeSemantics(
        child: Material(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.borderSubtle),
              ),
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
                  Icon(LucideIcons.chevronRight, size: 20, color: c.textTertiary),
                ],
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
