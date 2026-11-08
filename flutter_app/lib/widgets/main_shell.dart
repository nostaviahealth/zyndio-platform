import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import '../data/programme_journey.dart';
import '../providers/navbar_provider.dart';
import '../providers/programme_journey_provider.dart';
import '../services/milestone_reminders.dart';
import '../providers/lens_provider.dart';
import '../services/conversion_service.dart';
import '../services/notification_permission_prompt.dart';

/// One destination in the 5-tab patient shell.
class _TabSpec {
  const _TabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<_TabSpec> _kTabs = [
  _TabSpec('Today', LucideIcons.home),
  _TabSpec('Progress', LucideIcons.trendingUp),
  _TabSpec('Biomarkers', LucideIcons.activity),
  _TabSpec('My Plan', LucideIcons.clipboardList),
  _TabSpec('Care', LucideIcons.heartPulse),
];

/// Main patient shell: a fixed 5-tab bar (Today · Progress · Biomarkers ·
/// My Plan · Care) over the branch navigation stack (specs §8). The brand row
/// and profile avatar live inside each tab's content, not here.
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // The shell only exists for a signed-in patient, so this is the first
    // in-context moment to ask for notifications (once; see the prompt class).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationPermissionPromptProvider).maybeAskOnce();
    });
    // APP-14: keep the Day 90 / 180 / 365 scan-and-labs reminders in step
    // with the patient's records (re-planned only when the plan changes).
    ref.listenManual<ProgrammeJourney?>(programmeJourneyProvider,
        (previous, next) {
      final scheduler = ref.read(milestoneReminderSchedulerProvider);
      if (next == null || scheduler == null) return;
      final key = planMilestoneReminders(next, DateTime.now())
          .map((r) => '${r.id}@${r.at.toIso8601String()}')
          .join(',');
      if (key == _reminderPlanKey) return;
      _reminderPlanKey = key;
      syncMilestoneReminders(next, scheduler).then((ok) {
        // Not allowed yet (or the plugin failed): try again on the next change.
        if (!ok && _reminderPlanKey == key) _reminderPlanKey = null;
      });
    }, fireImmediately: true);
  }

  String? _reminderPlanKey;

  void _onTapBranch(int index) {
    ref.read(navbarVisibleProvider.notifier).show();
    // Re-tapping the active tab resets its branch to the initial location
    // (pops nested routes / returns to top).
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.navigationShell.currentIndex;

    // ── Background food-scan listener (Lens): jump to results on completion. ──
    ref.listen(lensScanProvider, (previous, next) {
      if ((next.phase == LensScanPhase.fastComplete ||
              next.phase == LensScanPhase.deepComplete) &&
          (previous?.phase == LensScanPhase.analyzing ||
              previous?.phase == LensScanPhase.uploading)) {
        ref.read(conversionServiceProvider).recordAhaMoment(context);
        context.pushNamed('lens');
      } else if (next.phase == LensScanPhase.failed &&
          previous?.phase != LensScanPhase.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(next.errorMessage ?? 'Analysis failed. Please try again.'),
            backgroundColor: BrandColors.red500,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) ref.read(lensScanProvider.notifier).reset();
        });
      }
    });

    final scanState = ref.watch(lensScanProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.z25.screenBg,
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: Consumer(
          builder: (context, ref, child) {
            final isVisible = ref.watch(navbarVisibleProvider);
            return AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(ignoring: !isVisible, child: child!),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (scanState.isAnalyzing || scanState.isDeepLoading)
                Positioned(
                  bottom: 96,
                  left: 16,
                  right: 16,
                  child: _LensProgressBar(state: scanState),
                ),
              _ZyndioTabBar(
                selectedIndex: selectedIndex,
                onTap: _onTapBranch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating tab bar: a light frosted bar of quiet icons; the active tab
/// becomes the client mockup's blue-violet pill with its label.
///
/// Switching is one continuous motion driven by a single animation: the old
/// tab narrows while the new one widens, the pill travels from the old tab's
/// shape to the new one's (so it is always locked to a tab), the label
/// unfolds and fades in, and the icon colours cross-fade. Every item keeps a
/// >= 48pt target and its "name, tab n of 5" semantics label.
class _ZyndioTabBar extends StatefulWidget {
  const _ZyndioTabBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final void Function(int) onTap;

  @override
  State<_ZyndioTabBar> createState() => _ZyndioTabBarState();
}

class _ZyndioTabBarState extends State<_ZyndioTabBar>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 420);

  /// Width units: the active tab takes 13, the others 5 each.
  static const _activeUnits = 13.0;
  static const _idleUnits = 5.0;
  static const _pillInset = 4.0;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration, value: 1);
  late final Animation<double> _progress = CurvedAnimation(
      parent: _controller, curve: Curves.easeInOutCubicEmphasized);
  late int _from = widget.selectedIndex;
  late int _to = widget.selectedIndex;

  @override
  void didUpdateWidget(_ZyndioTabBar old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != _to) {
      _from = _to;
      _to = widget.selectedIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How "active" tab [i] is right now, 0..1.
  double _activeness(int i, double p) {
    if (_from == _to) return i == _to ? 1 : 0;
    if (i == _to) return p;
    if (i == _from) return 1 - p;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: (dark ? const Color(0xFF1A2136) : Colors.white)
                    .withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? 0.06 : 0.9)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1A0F1438),
                      blurRadius: 30,
                      offset: Offset(0, 10)),
                ],
              ),
              child: LayoutBuilder(builder: (context, box) {
                final n = _kTabs.length;
                final unit =
                    box.maxWidth / (_activeUnits + _idleUnits * (n - 1));
                final idleW = unit * _idleUnits;
                final extraW = unit * (_activeUnits - _idleUnits);
                return AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) {
                    final p = _progress.value;
                    final t = [for (var i = 0; i < n; i++) _activeness(i, p)];
                    final widths = [for (final v in t) idleW + extraW * v];
                    double leftOf(int i) =>
                        widths.take(i).fold(0.0, (a, b) => a + b);
                    // The pill travels from the old tab's rect to the new one's.
                    final pillLeft =
                        ui.lerpDouble(leftOf(_from), leftOf(_to), p)!;
                    final pillWidth =
                        ui.lerpDouble(widths[_from], widths[_to], p)!;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Positioned(
                          // Inset a little so the pill breathes in its slot.
                          left: pillLeft + _pillInset,
                          width: pillWidth - _pillInset * 2,
                          top: 9,
                          height: 52,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: ZyndioGradients.brand,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(26)),
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x404A55F0),
                                    blurRadius: 14,
                                    offset: Offset(0, 6)),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < n; i++)
                              _TabItem(
                                spec: _kTabs[i],
                                index: i,
                                selected: i == widget.selectedIndex,
                                activeness: t[i],
                                width: widths[i],
                                onTap: () => widget.onTap(i),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.index,
    required this.selected,
    required this.activeness,
    required this.width,
    required this.onTap,
  });

  final _TabSpec spec;
  final int index;
  final bool selected;

  /// 0 = idle icon, 1 = full pill with label; animates in between.
  final double activeness;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final t = activeness;
    return Semantics(
      label: '${spec.label}, tab ${index + 1} of ${_kTabs.length}',
      selected: selected,
      button: true,
      onTap: onTap, // H1: screen-reader activation == finger tap
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: 52,
            child: ClipRect(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(spec.icon,
                      size: 22,
                      color: Color.lerp(c.textTertiary, Colors.white, t)),
                  // The label unfolds from zero width and fades in.
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: t,
                      child: Opacity(
                        opacity: Curves.easeIn.transform(t.clamp(0.0, 1.0)),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            spec.label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: const TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Global food-scan progress bar shown just above the tab bar while a Lens
/// analysis runs. Unchanged behaviour from the previous shell.
class _LensProgressBar extends StatelessWidget {
  final LensScanState state;

  const _LensProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child:
                          Icon(LucideIcons.scan, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zyndio Intelligence Scan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(state.progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  color: const Color(0xFF10B981),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
