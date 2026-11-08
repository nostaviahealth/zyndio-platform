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
              height: 22, excludeFromSemantics: true),
          const SizedBox(width: 10),
          Text(
            'Zyndio',
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
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
                // 48pt hit target around a quiet 40pt avatar.
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.bgSurface,
                        border: Border.all(color: c.borderSubtle),
                      ),
                      child: initials.isEmpty
                          ? Icon(LucideIcons.user, size: 18, color: c.textPrimary)
                          : Text(
                              initials,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                color: c.textPrimary,
                              ),
                            ),
                    ),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingBadge;
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
