import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../providers/patient_provider.dart';
import 'zyndio_glyphs.dart';

export 'zyndio_glyphs.dart' show ZyndioGlyph;

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
    final c = context.zc;
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
  final c = context.zc;
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
    final c = context.zc;
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
    final c = context.zc;
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

/// Zyndio's app-icon tile: a continuous-corner squircle with a vertical
/// gradient, a top sheen, an inner hairline and a soft coloured shadow, holding
/// one of Zyndio's own hand-drawn glyphs ([ZyndioGlyph]).
///
/// Pass [glyph] directly, or an [icon]: stock icons that have a bespoke
/// Zyndio glyph are swapped automatically ([ZyndioGlyph.forIcon]); anything
/// else falls back to the icon itself, drawn in white.
class ZyndioIconTile extends StatelessWidget {
  const ZyndioIconTile({
    super.key,
    this.icon,
    this.glyph,
    this.tint = ZyndioTint.blue,
    this.size = 48,
  }) : assert(icon != null || glyph != null);

  final IconData? icon;
  final ZyndioGlyph? glyph;
  final ZyndioTint tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = glyph ?? ZyndioGlyph.forIcon(icon!);
    final top = Color.lerp(tint.colors.first, Colors.white, 0.08)!;
    final deep = tint.colors.last;
    final shape = ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.6));
    final glyphSize = size * 0.76;
    Widget art;
    if (resolved != null) {
      final svg = resolved.svg(deep);
      art = SizedBox(
        width: glyphSize,
        height: glyphSize,
        child: Stack(
          children: [
            // A faint contact shadow under the glyph gives it a little lift.
            Positioned.fill(
              top: size * 0.02,
              child: SvgPicture.string(
                svg,
                colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.10), BlendMode.srcIn),
              ),
            ),
            Positioned.fill(child: SvgPicture.string(svg)),
          ],
        ),
      );
    } else {
      art = Icon(icon, size: size * 0.48, color: Colors.white);
    }
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, deep],
        ),
        shadows: [
          BoxShadow(
            color: deep.withValues(alpha: 0.24),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Top sheen: light falls from above, like an iOS app icon.
          Positioned.fill(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.26),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // Inner hairline keeps the edge crisp on white cards.
          Positioned.fill(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(size * 0.6),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.22), width: 1),
                ),
              ),
            ),
          ),
          ExcludeSemantics(child: art),
        ],
      ),
    );
  }
}

/// Full-width gradient call to action (client mockup: "View My Insights →").
/// A null [onTap] draws it disabled; [loading] swaps the label for a spinner.
class ZyndioGradientButton extends StatelessWidget {
  const ZyndioGradientButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.trailingArrow = true,
      this.icon,
      this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool trailingArrow;

  /// Optional leading icon (e.g. upload, camera).
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final enabled = onTap != null && !loading;
    final fg = enabled || loading ? Colors.white : c.textTertiary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: enabled || loading ? ZyndioGradients.brand : null,
              color: enabled || loading ? null : c.bgSunken,
              borderRadius: BorderRadius.circular(999),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4F57EE).withValues(alpha: 0.30),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                      if (trailingArrow) ...[
                        const SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 18, color: fg),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary full-width pill: hairline outline on the surface colour. Pairs
/// with [ZyndioGradientButton] ("Cancel", "Add manually", "Choose a file").
class ZyndioOutlineButton extends StatelessWidget {
  const ZyndioOutlineButton(
      {super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.bgSurface,
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.borderSubtle, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Header for every pushed (non-tab) screen: a round card back button and a
/// bold title, matching Profile & settings. [trailing] sits on the right.
class ZyndioBackHeader extends StatelessWidget {
  const ZyndioBackHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.backIcon = LucideIcons.chevronLeft,
  });

  final String title;
  final String? subtitle;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Use [LucideIcons.x] for modal-style flows (upload, verify).
  final IconData backIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final back = onBack ?? () => Navigator.of(context).maybePop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ZyndioCircleButton(
              icon: backIcon,
              label: backIcon == LucideIcons.x ? 'Close' : 'Back',
              onTap: back,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              color: c.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// 44pt round card icon button (back, close, share, filter) used in headers.
class ZyndioCircleButton extends StatelessWidget {
  const ZyndioCircleButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: zyndioCard(context, radius: 22),
            child: Icon(icon, size: 22, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Standard scaffold for pushed screens: light canvas, [ZyndioBackHeader],
/// 20pt side margins, scrolling body, optional pinned [bottomBar] (primary
/// action). Use [body] instead of [children] when the screen owns scrolling.
class ZyndioDetailScaffold extends StatelessWidget {
  const ZyndioDetailScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.children,
    this.body,
    this.trailing,
    this.onBack,
    this.backIcon = LucideIcons.chevronLeft,
    this.bottomBar,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 40),
  }) : assert(children != null || body != null);

  final String title;
  final String? subtitle;
  final List<Widget>? children;
  final Widget? body;
  final Widget? trailing;
  final VoidCallback? onBack;
  final IconData backIcon;
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final header = ZyndioBackHeader(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onBack: onBack,
      backIcon: backIcon,
    );
    Widget content;
    if (body != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                padding.left, padding.top, padding.right, 16),
            child: header,
          ),
          Expanded(child: body!),
        ],
      );
    } else {
      final list = ListView(
        padding: padding,
        children: [
          header,
          const SizedBox(height: 20),
          ...children!,
        ],
      );
      content = onRefresh == null
          ? list
          : RefreshIndicator(onRefresh: onRefresh!, child: list);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.z25.screenBg,
        body: SafeArea(bottom: bottomBar == null, child: content),
        bottomNavigationBar: bottomBar == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: bottomBar,
                ),
              ),
      ),
    );
  }
}

/// A plain content card (white surface, soft shadow) with standard padding.
class ZyndioCard extends StatelessWidget {
  const ZyndioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    return Container(
      decoration: zyndioCard(context, radius: radius, color: color),
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: inner,
              ),
            ),
    );
  }
}

/// Small status pill: success / warning / critical / brand / neutral.
enum ZyndioPillTone { success, warning, critical, brand, neutral }

class ZyndioPill extends StatelessWidget {
  const ZyndioPill(this.label,
      {super.key, this.tone = ZyndioPillTone.neutral, this.icon});

  final String label;
  final ZyndioPillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final z = context.z25;
    final (bg, fg) = switch (tone) {
      ZyndioPillTone.success => (c.statusSuccessSubtle, c.statusSuccess),
      ZyndioPillTone.warning => (c.statusWarningSubtle, c.statusWarning),
      ZyndioPillTone.critical => (c.statusCriticalSubtle, c.statusCritical),
      ZyndioPillTone.brand => (c.brandSubtle, c.brandOnSubtle),
      ZyndioPillTone.neutral => (z.badgeNeutralBg, z.badgeNeutralText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
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
    final c = context.zc;
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
    final c = context.zc;
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
    final c = context.zc;
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

/// The brand-gradient 270° score ring (Today's Longevity card, Lab results).
class ZyndioRingPainter extends CustomPainter {
  ZyndioRingPainter({required this.fraction, required this.track});
  final double fraction;
  final Color track;

  static const _start = math.pi * 0.75; // 135°
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      // Gradient runs 0.._sweep, rotated to the arc's start so it never wraps.
      ..shader = const SweepGradient(
        // Offset a little before the arc start so the round start cap samples
        // the first colour instead of wrapping to the last.
        startAngle: 0,
        endAngle: _sweep + 0.3,
        colors: [
          Color(0xFF7B5CFA),
          Color(0xFF4F6BF5),
          Color(0xFF2E7BEA),
          Color(0xFF38BDF8)
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
        transform: GradientRotation(_start - 0.3),
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * fraction, false, arc);
  }

  @override
  bool shouldRepaint(covariant ZyndioRingPainter old) =>
      old.fraction != fraction || old.track != track;
}
