import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../providers/theme_provider.dart';
import '../providers/navbar_provider.dart';
import '../providers/cycle_provider.dart';
import '../providers/lens_provider.dart';
import '../services/conversion_service.dart';
import 'voice_log_dialog.dart';

/// Navigation icon paths
class NavIcons {
  static const String homeSelected = 'assets/icons/nav/home_selected.png';
  static const String homeUnselected = 'assets/icons/nav/home_unselected.png';
  static const String protocolSelected =
      'assets/icons/nav/protocol_selected.png';
  static const String protocolUnselected =
      'assets/icons/nav/protocol_unselected.png';
  static const String healthDataSelected =
      'assets/icons/nav/health_data_selected.png';
  static const String healthDataUnselected =
      'assets/icons/nav/health_data_unselected.png';
  static const String intelligenceSelected =
      'assets/icons/nav/intelligence_selected.png';
  static const String intelligenceUnselected =
      'assets/icons/nav/intelligence_unselected.png';
  static const String customOrb = 'assets/icons/zyndioorb.png';
}

/// Main shell widget with Action Trio Grid
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _menuController;
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache navbar PNG assets to avoid first-time load blinks/lag
    precacheImage(const AssetImage(NavIcons.homeSelected), context);
    precacheImage(const AssetImage(NavIcons.homeUnselected), context);
    precacheImage(const AssetImage(NavIcons.protocolSelected), context);
    precacheImage(const AssetImage(NavIcons.protocolUnselected), context);
    precacheImage(const AssetImage(NavIcons.healthDataSelected), context);
    precacheImage(const AssetImage(NavIcons.healthDataUnselected), context);

    // Track path changes to show navbar automatically on main dashboard tabs
    try {
      final currentPath = GoRouterState.of(context).matchedLocation;
      if (_lastPath != currentPath) {
        _lastPath = currentPath;
        const mainTabs = ['/', '/protocol', '/health_data', '/wearables'];
        if (mainTabs.contains(currentPath)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(navbarVisibleProvider.notifier).show();
            }
          });
        }
      }
    } catch (_) {
      // Safeguard if GoRouterState is not yet available in the context
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    HapticFeedback.mediumImpact();
    if (_menuController.isAnimating) return;
    if (_menuController.isCompleted) {
      _menuController.reverse();
    } else {
      _menuController.forward();
    }
  }

  void _closeMenu() {
    if (_menuController.status == AnimationStatus.completed ||
        _menuController.status == AnimationStatus.forward) {
      _menuController.reverse();
    }
  }

  void _onAction(VoidCallback action) {
    _closeMenu();
    Future.delayed(const Duration(milliseconds: 200), action);
  }

  int _getSelectedIndex() => widget.navigationShell.currentIndex;

  void _onTapBranch(int index) {
    _closeMenu();
    // Ensure navbar is immediately shown when tapping a dashboard tab
    ref.read(navbarVisibleProvider.notifier).show();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Color _getPageColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF4F46E5); // Home: Indigo
      case 1:
        return const Color(0xFF9333EA); // Protocol: Deep Purple
      case 2:
        return const Color(0xFF059669); // Labs: Emerald
      case 3:
        return const Color(0xFF0891B2); // Wearables: Cyan
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Color _getSecondaryPageColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF10B981); // Home: Emerald secondary
      case 1:
        return const Color(0xFFEC4899); // Protocol: Pink/Magenta secondary
      case 2:
        return const Color(0xFF3B82F6); // Labs: Blue secondary
      case 3:
        return const Color(0xFF8B5CF6); // Wearables: Purple secondary
      default:
        return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex();
    final globalTheme = ref.watch(themeProvider);
    final isImmersive = globalTheme;
    final isFemale = ref.watch(isFemaleUserProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    const double circleSize = 64.0;
    const double sidePadding = 32.0;
    const double internalPadding = 12.0;
    const double gap = 12.0;

    final availableWidthForItems =
        screenWidth - sidePadding - circleSize - gap - internalPadding;
    final double itemWidth = (availableWidthForItems / 4).floorToDouble();

    // ── Background Scan Listener ──
    ref.listen(lensScanProvider, (previous, next) {
      if ((next.phase == LensScanPhase.fastComplete ||
              next.phase == LensScanPhase.deepComplete) &&
          (previous?.phase == LensScanPhase.analyzing ||
              previous?.phase == LensScanPhase.uploading)) {
        // 🚀 High-conversion placement: record success and trigger paywall if threshold reached
        ref.read(conversionServiceProvider).recordAhaMoment(context);

        // Automatically jump to the results screen
        context.pushNamed('lens');
      } else if (next.phase == LensScanPhase.failed &&
          previous?.phase != LensScanPhase.failed) {
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(next.errorMessage ?? 'Analysis failed. Please try again.'),
            backgroundColor: BrandColors.red500,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Reset state so the progress bar clears out
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(lensScanProvider.notifier).reset();
          }
        });
      }
    });

    final scanState = ref.watch(lensScanProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
        children: [
          // Ambient Glow Background for Dark Mode
          if (context.nc.isDark)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                color: const Color(
                    0xFF000000), // Solid black base for maximum contrast
                child: Stack(
                  children: [
                    // Top-edge accent glow (Premium vibrant edge)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _getPageColor(selectedIndex).withOpacity(0.4),
                              _getSecondaryPageColor(selectedIndex)
                                  .withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Main ambient glow (Dynamic position based on page)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      top: selectedIndex == 0
                          ? -150
                          : (selectedIndex == 2 ? 100 : -50),
                      left: selectedIndex == 1 ? 50 : -100,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        width: 450,
                        height: 450,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _getPageColor(selectedIndex).withOpacity(0.35),
                              _getSecondaryPageColor(selectedIndex)
                                  .withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Secondary ambient glow
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      top: MediaQuery.of(context).size.height * 0.35,
                      right: selectedIndex == 0 ? -100 : -200,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getSecondaryPageColor(selectedIndex)
                              .withOpacity(0.2),
                        ),
                      ),
                    ),

                    // Bottom ambient glow
                    Positioned(
                      bottom: -200,
                      left: MediaQuery.of(context).size.width * 0.1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        width: 550,
                        height: 550,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getPageColor(selectedIndex).withOpacity(0.15),
                        ),
                      ),
                    ),

                    // Mesh Blur
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Scaffold(
            backgroundColor:
                context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
            body: isImmersive
                ? widget.navigationShell
                : SafeArea(bottom: false, child: widget.navigationShell),
            extendBody: true,
            extendBodyBehindAppBar: true,
            bottomNavigationBar: Consumer(
              builder: (context, ref, child) {
                final isNavBarVisible = ref.watch(navbarVisibleProvider);
                return AnimatedSlide(
                  offset: isNavBarVisible ? Offset.zero : const Offset(0, 1.2),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedOpacity(
                    opacity: isNavBarVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !isNavBarVisible,
                      child: child!,
                    ),
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // ── Global Lens Progress Bar ──
                  if (scanState.isAnalyzing || scanState.isDeepLoading)
                    Positioned(
                      bottom: 104, // Just above the navbar
                      left: 16,
                      right: 16,
                      child: _LensProgressBar(state: scanState),
                    ),

                  Container(
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _AnimatedNavSection(
                          isExpanded: true,
                          expandedWidth: (itemWidth * 4) + internalPadding,
                          collapsedWidth: circleSize,
                          itemWidth: itemWidth,
                          isLeft: true,
                          child: _NavPillContent(
                            items: [
                              _NavItemData(
                                  selectedIcon: NavIcons.homeSelected,
                                  unselectedIcon: NavIcons.homeUnselected,
                                  label: 'Home',
                                  isSelected: selectedIndex == 0,
                                  onTap: () => _onTapBranch(0)),
                              _NavItemData(
                                  selectedIcon: NavIcons.protocolSelected,
                                  unselectedIcon: NavIcons.protocolUnselected,
                                  label: 'Protocol',
                                  isSelected: selectedIndex == 1,
                                  onTap: () => _onTapBranch(1)),
                              _NavItemData(
                                  selectedIcon: NavIcons.healthDataSelected,
                                  unselectedIcon: NavIcons.healthDataUnselected,
                                  label: 'Labs',
                                  isSelected: selectedIndex == 2,
                                  onTap: () => _onTapBranch(2)),
                              _NavItemData(
                                  iconData: LucideIcons.watch,
                                  label: 'Wearables',
                                  isSelected: selectedIndex == 3,
                                  onTap: () => _onTapBranch(3)),
                            ],
                            itemWidth: itemWidth,
                            selectedIndex: selectedIndex,
                          ),
                        ),
                        _AnimatedNavSection(
                          isExpanded: false,
                          expandedWidth: circleSize,
                          collapsedWidth: circleSize,
                          itemWidth: itemWidth,
                          isLeft: false,
                          child: _PlusButtonCircle(
                            animation: _menuController,
                            onTap: _toggleMenu,
                            isActive: false, // No longer a primary shell branch
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _TrioActionOverlay(
            animation: _menuController,
            isFemale: isFemale,
            onClose: _closeMenu,
            onActionScanFood: () => _onAction(() async {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 70,
              );
              if (image != null) {
                ref.read(lensScanProvider.notifier).reset();
                ref
                    .read(lensScanProvider.notifier)
                    .startAnalysis(File(image.path));
              }
            }),
            onActionVoiceLog: () => _onAction(() {
              _showVoiceLogDialog();
            }),
            onActionImportFood: () => _onAction(() async {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 70,
              );
              if (image != null) {
                ref.read(lensScanProvider.notifier).reset();
                ref
                    .read(lensScanProvider.notifier)
                    .startAnalysis(File(image.path));
              }
            }),
            onActionDescribeFood: () => _onAction(() {
              _showDescribeFoodDialog();
            }),
            onActionChat: () => _onAction(() => context.pushNamed('chat')),
            onActionMeditate: () =>
                _onAction(() => context.pushNamed('meditate')),
            onActionCycle: () => _onAction(() => context.pushNamed('cycle')),
          ),
        ],
      ),
    );
  }

  void _showDescribeFoodDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E293B).withOpacity(0.85),
                    const Color(0xFF0F172A).withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Describe your meal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      cursorColor: const Color(0xFF007AFF),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'e.g., 2 eggs and a piece of toast',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 16,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'AI will analyze nutrients and longevity impact.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF0056B3)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isNotEmpty) {
                              Navigator.pop(context);
                              _onAction(() {
                                ref.read(lensScanProvider.notifier).reset();
                                ref.read(lensScanProvider.notifier).startTextAnalysis(text);
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Analyze',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVoiceLogDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoiceLogDialog(
        onResult: (text) {
          Navigator.pop(context);
          _onAction(() {
            ref.read(lensScanProvider.notifier).reset();
            ref.read(lensScanProvider.notifier).startTextAnalysis(text);
          });
        },
      ),
    );
  }
}

class _AnimatedNavSection extends StatelessWidget {
  final bool isExpanded;
  final double expandedWidth;
  final double collapsedWidth;
  final double itemWidth;
  final Widget child;
  final bool isLeft;

  const _AnimatedNavSection({
    required this.isExpanded,
    required this.expandedWidth,
    required this.collapsedWidth,
    required this.itemWidth,
    required this.child,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final targetWidth = isExpanded ? expandedWidth : collapsedWidth;
    return Container(
      width: targetWidth,
      height: 64,
      decoration: BoxDecoration(
        color: context.nc.navbarBg,
        borderRadius: BorderRadius.circular(44),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: context.nc.cardBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: context.nc.navbarBg,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _NavPillContent extends StatelessWidget {
  final List<_NavItemData> items;
  final double itemWidth;
  final int selectedIndex;

  const _NavPillContent({
    required this.items,
    required this.itemWidth,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    const double itemHeight = 52.0;
    final double horizontalPadding = 12.0 / 2; // half of internalPadding
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(
        width: itemWidth * items.length + 12.0,
        height: 64,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 6.0),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      left: selectedIndex * itemWidth,
                      top: 0,
                      child: Container(
                        width: itemWidth,
                        height: itemHeight,
                        decoration: BoxDecoration(
                          color: context.nc.navbarPillBg,
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: items
                    .map((item) => SizedBox(
                          width: itemWidth,
                          height: itemHeight,
                          child: _PillNavItem(data: item),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusButtonCircle extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTap;
  final bool isActive;

  const _PlusButtonCircle({
    required this.animation,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive && t == 0
                  ? const Color(0xFF007AFF).withOpacity(0.08)
                  : Colors.transparent,
            ),
            child: Center(
              child: Transform.rotate(
                angle: t * math.pi / 4,
                child: Icon(
                  LucideIcons.plus,
                  size: 26,
                  color: t > 0
                      ? Color.lerp(
                          BrandColors.slate600, const Color(0xFF007AFF), t)
                      : (isActive
                          ? const Color(0xFF007AFF)
                          : context.nc.iconDefault),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrioActionOverlay extends ConsumerWidget {
  final AnimationController animation;
  final bool isFemale;
  final VoidCallback onClose;
  final VoidCallback onActionScanFood;
  final VoidCallback onActionVoiceLog;
  final VoidCallback onActionImportFood;
  final VoidCallback onActionDescribeFood;
  final VoidCallback onActionChat;
  final VoidCallback onActionMeditate;
  final VoidCallback onActionCycle;

  const _TrioActionOverlay({
    required this.animation,
    this.isFemale = false,
    required this.onClose,
    required this.onActionScanFood,
    required this.onActionVoiceLog,
    required this.onActionImportFood,
    required this.onActionDescribeFood,
    required this.onActionChat,
    required this.onActionMeditate,
    required this.onActionCycle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.value == 0) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        const double navBarFootprint = 92.0;
        const double boxGap = 16.0;
        const double boxBottomOffset = navBarFootprint + boxGap;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // ── Light screen dim ──
              Positioned.fill(
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    color: Colors.black.withOpacity(0.12 * animation.value),
                  ),
                ),
              ),

              // ── Floating Liquid Glass Box ──
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: boxBottomOffset),
                  child: SizedBox(
                    width: screenWidth * 0.88,
                    child: Transform.scale(
                      scale: 0.94 +
                          (0.06 *
                              Curves.easeOutCubic.transform(animation.value)),
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: animation.value.clamp(0.0, 1.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 32, horizontal: 8),
                              decoration: BoxDecoration(
                                color: context.nc.glassBg,
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(
                                  color: context.nc.glassBorder,
                                  width: 1.5, // "Rim" catch light
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 40,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 20),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _BoxActionItem(
                                        label: 'Describe food',
                                        icon: LucideIcons.type,
                                        onTap: onActionDescribeFood,
                                      ),
                                      _BoxActionItem(
                                        label: 'Import food',
                                        icon: LucideIcons.image,
                                        onTap: onActionImportFood,
                                      ),
                                      _BoxActionItem(
                                        label: 'Voice food log',
                                        icon: LucideIcons.mic,
                                        onTap: onActionVoiceLog,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _BoxActionItem(
                                        label: 'Meditate',
                                        icon: LucideIcons.flower2,
                                        onTap: onActionMeditate,
                                      ),
                                      _BoxActionItem(
                                        label: 'Ask Zyndio',
                                        imageAsset: NavIcons.customOrb,
                                        onTap: onActionChat,
                                        isOrb: true,
                                      ),
                                      _BoxActionItem(
                                        label: 'Scan food',
                                        icon: LucideIcons.scan,
                                        onTap: onActionScanFood,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _BoxActionItem(
                                        label: 'Book Doctor',
                                        icon: LucideIcons.stethoscope,
                                        onTap: () {
                                          onClose();
                                          context.push('/appointments');
                                        },
                                      ),
                                      _BoxActionItem(
                                        label: 'Shop',
                                        icon: LucideIcons.shoppingBag,
                                        onTap: () {
                                          onClose();
                                          context.push('/shop');
                                        },
                                      ),
                                      if (isFemale)
                                        _BoxActionItem(
                                          label: 'Cycle Tracking',
                                          icon: LucideIcons.calendarHeart,
                                          onTap: onActionCycle,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Close button at navbar X position ──
              Positioned(
                right: 16,
                bottom: 28,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.nc.navbarBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: animation.value * math.pi / 4,
                        child: Icon(
                          LucideIcons.plus,
                          size: 26,
                          color: context.nc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BoxActionItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? imageAsset;
  final bool isOrb;
  final VoidCallback onTap;

  const _BoxActionItem({
    required this.label,
    this.icon,
    this.imageAsset,
    this.isOrb = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 68.0; // Normalized size for all 3

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Fixed height icon bucket to keep text level ──
            SizedBox(
              height: 84, // Anchors all labels to the same level
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ── AI Glow Aura ──
                    if (isOrb)
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF22D3EE).withOpacity(0.25),
                              const Color(0xFF22D3EE).withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),

                    // ── Main Circle ──
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOrb
                            ? Colors.transparent
                            : context.nc.cardSurfaceElevated,
                        boxShadow: [
                          if (isOrb)
                            BoxShadow(
                              color: const Color(0xFF22D3EE).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: !isOrb
                            ? Border.all(
                                color: context.nc.divider,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Center(
                        child: imageAsset != null
                            ? ClipOval(
                                child: Image.asset(
                                  imageAsset!,
                                  width: size,
                                  height: size,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                icon,
                                color: context.nc.textPrimary,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.nc.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final String? selectedIcon;
  final String? unselectedIcon;
  final IconData? iconData;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemData({
    this.selectedIcon,
    this.unselectedIcon,
    this.iconData,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

class _PillNavItem extends StatelessWidget {
  final _NavItemData data;

  const _PillNavItem({required this.data});

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF007AFF);
    final unselectedColor = context.nc.textTertiary;
    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: data.isSelected ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 200),
            child: _buildIcon(context, selectedColor, unselectedColor),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: data.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: data.isSelected ? selectedColor : unselectedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(
      BuildContext context, Color selectedColor, Color unselectedColor) {
    if (data.iconData != null) {
      return Icon(data.iconData,
          size: 24, color: data.isSelected ? selectedColor : unselectedColor);
    }

    // Only apply tinting to PNG icons in dark mode to fix visibility.
    // In light mode, keep the original assets untouched as requested.
    if (!context.nc.isDark) {
      return Image.asset(
        data.isSelected ? data.selectedIcon! : data.unselectedIcon!,
        width: 24,
        height: 24,
      );
    }

    return Image.asset(
      data.isSelected ? data.selectedIcon! : data.unselectedIcon!,
      width: 24,
      height: 24,
      color: data.isSelected ? selectedColor : unselectedColor,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}

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
            color: const Color(0xFF1E293B).withOpacity(0.85), // Dark Slate
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
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
                      color: Colors.white.withOpacity(0.1),
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
                          "Zyndio Intelligence Scan",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${(state.progress * 100).toInt()}%",
                    style: TextStyle(
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
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: const Color(0xFF10B981), // Emerald 500
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
