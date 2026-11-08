import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import '../providers/navbar_provider.dart';
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
  }

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

class _ZyndioTabBar extends StatelessWidget {
  const _ZyndioTabBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: c.bgSurface,
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < _kTabs.length; i++)
                Expanded(
                  child: _TabItem(
                    spec: _kTabs[i],
                    index: i,
                    selected: i == selectedIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
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
    required this.onTap,
  });

  final _TabSpec spec;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = context.z25;
    final color = selected ? z.tabActive : z.tabInactive;
    return Semantics(
      label: '${spec.label}, tab ${index + 1} of ${_kTabs.length}',
      selected: selected,
      button: true,
      onTap: onTap, // H1: screen-reader activation == finger tap
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 78, minHeight: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Slim indicator above the active tab.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 20 : 0,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 7),
                  decoration: BoxDecoration(
                    color: z.tabActive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(spec.icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  spec.label,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 11,
                    letterSpacing: 0.1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
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
                      child: Icon(LucideIcons.scan, size: 18, color: Colors.white),
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
