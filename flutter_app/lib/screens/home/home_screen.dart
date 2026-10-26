import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
// <--- Added Import
import '../../providers/patient_provider.dart';
import '../../providers/protocol_provider.dart'; // <--- Added Import
import '../../providers/lab_reports_provider.dart'; // <--- Added Import
import '../../utils/bio_age_calculator.dart'; 
import '../../models/lab_report.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/wearable_sync_provider.dart';
import '../../providers/purchase_provider.dart';
import '../settings/paywall_screen.dart';
import '../../providers/navbar_provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'food_intelligence_screen.dart';
import '../../providers/theme_provider.dart'; // <--- Added Import
// <--- Added Import
import '../../widgets/rhythm_card.dart';
import '../../services/tutorial_service.dart';
import '../../services/ai_consent_service.dart';
import '../../data/health_data_repository.dart';
import 'package:intl/intl.dart';
import '../../models/food_log.dart';
import '../../models/food_analysis.dart';
import '../../providers/nutrition_goals_provider.dart';
import '../settings/lens_history_screen.dart'; // To get foodLogsProvider
import '../../providers/lens_provider.dart';
import '../../providers/module_order_provider.dart';
import '../../widgets/cardio_module_card.dart';
import '../../widgets/performance_module_card.dart';
import '../settings/nutrition_trends_screen.dart';
import '../../widgets/onboarding_overlay.dart'; 
import '../../services/vo2_max_service.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/alert_provider.dart';
import '../../providers/activity_goals_provider.dart';
import '../../widgets/xp_coins_header.dart';
/// Home screen matching React Home.tsx
/// Home screen matching React Home.tsx
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Use ValueNotifier to avoid full setState rebuilds during drag
  final ValueNotifier<double> _sheetExtentNotifier = ValueNotifier(0.45);
  double _startExtent = 0.45;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  // 0 = Dashboard, 1 = Today's Rhythm
  int _activeTab = 0;
  
  // Multi-metric card state
  String _selectedHeroMetric = 'BIOLOGICAL AGE';

  // Track if we have already triggered onboarding in this session
  bool _onboardingTriggered = false;

  // Track if onboarding was forced via query parameter
  bool _forceOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedMetric(); // Persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure navbar is visible when on Home
        ref.read(navbarVisibleProvider.notifier).show();
        
        final uri = GoRouterState.of(context).uri;
        _forceOnboarding = uri.queryParameters['onboarding'] == 'true';
        
        // Initial check for consent if already loaded
        final consentState = ref.read(aiConsentProvider);
        if (consentState.hasValue) {
          _checkOnboarding(consentState);
        }

        ref.read(tutorialServiceProvider).showGuidedTour(context);
        
        // Trigger health data sync on app open
        ref.read(wearableSyncProvider.notifier).sync();
      }
    });
  }

  Future<void> _loadSelectedMetric() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('hero_metric_selection');
    final validMetrics = ['BIOLOGICAL AGE', 'VO2 MAX', 'HRV', 'ENERGY BURNED', 'STEPS'];
    if (saved != null && validMetrics.contains(saved) && mounted) {
      setState(() {
        _selectedHeroMetric = saved;
      });
    }
  }

  Future<void> _saveSelectedMetric(String metric) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hero_metric_selection', metric);
  }

  void _checkOnboarding(AsyncValue<bool> consentState) {
    if (_onboardingTriggered || !mounted) return;
    
    final isDemoMode = ref.read(isDemoModeProvider);
    if (isDemoMode) return;

    final bool isForceOnboarding = _forceOnboarding;
    
    consentState.whenData((hasConsented) {
      if (!hasConsented || isForceOnboarding) {
        _onboardingTriggered = true;
        
        debugPrint('🏠 Onboarding Trigger: hasConsented=$hasConsented, isForce=$isForceOnboarding');
        
        // Use a microtask/timer to ensure we aren't in the middle of a build
        Future.microtask(() {
          if (!mounted) return;
          
          if (isForceOnboarding) {
            context.go('/'); // Clean up URL
          }

          showGeneralDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.5),
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, anim1, anim2) => const OnboardingOverlay(),
          ).then((_) {
            if (mounted) {
              // High-conversion placement: show paywall right after onboarding completes
              PaywallScreen.show(context);
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _sheetExtentNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to consent state to trigger onboarding
    ref.listen<AsyncValue<bool>>(aiConsentProvider, (previous, next) {
      if (next.hasValue) {
        _checkOnboarding(next);
      }
    });

    // Listen for gamification rewards and show alert toast
    ref.listen<RewardEvent?>(lastRewardEventProvider, (previous, next) {
      if (next != null && (previous == null || next.timestamp != previous.timestamp)) {
        ref.read(alertProvider.notifier).showAchievement(
          next.leveledUp ? 'Level Up! 🎉' : '${next.label} ✨',
          '+${next.xp} XP  •  +${next.coins} Coins',
        );
        // Clear after showing
        Future.delayed(const Duration(milliseconds: 300), () {
          ref.read(gamificationProvider.notifier).clearLastReward();
        });
      }
    });

    final profileAsync = ref.watch(patientProfileProvider);
    final profile = profileAsync.value;

    final user = ref.watch(currentUserProvider);
    
    // Logic: Profile Name > Auth Metadata Name > 'User'
    // Logic: Profile Name > Auth Metadata Name > 'User'
    final String name = (profile?.name != null && profile!.name!.isNotEmpty) 
        ? profile.name! 
        : (user?.userMetadata?['name'] as String? ?? 'User');
    
    // Watch Theme Provider
    final isImageTheme = ref.watch(themeProvider);
    
    // Watch Protocol Provider for current protocol name (rebuild on change)
    ref.watch(protocolProvider);


    
    final intelligenceAsync = ref.watch(intelligenceDataProvider);
    final intelligence = intelligenceAsync.value;
    
    // Unify state by consuming the single source of truth for wearables
    final wearableAsync = ref.watch(wearableSyncProvider);
    final wearable = wearableAsync.value?.snapshot;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // Responsive scale: 1.0 on 6.7" (~932px), ~0.87 on 6.1" (~812px)
    final double rs = (screenHeight / 900).clamp(0.82, 1.0);
    
    // Onboarding check moved to initState() for stability

    // Check for tutorial trigger via query params

    // --- DATA PREP ---
    // --- DATA PREP ---
    final int? chronAge = profile?.age;
    int? bioAge;
    double calculatedPace = 1.0;
    
    if (intelligence?.biologicalAge != null) {
      bioAge = intelligence!.biologicalAge;
      if (chronAge != null && chronAge > 0) {
        calculatedPace = bioAge! / chronAge;
      }
    } else if (intelligence?.overallScore != null && chronAge != null) {
      final double score = intelligence!.overallScore!.toDouble();
      // Pace = 2.0 - (Score / 100) -> e.g. 30 score = 1.70x, 100 score = 1.00x
      calculatedPace = 2.0 - (score / 100.0);
      bioAge = (chronAge * calculatedPace).round();
    }
    
    // --- BIO AGE: Intelligence -> Lab Algorithm -> null ---
    final labReportsAsync = ref.watch(labReportsProvider);
    if (bioAge == null && chronAge != null) {
      final labs = labReportsAsync.value;
      if (labs != null) {
        final computed = calculateBioAgeFromLabs(labs, chronAge);
        if (computed != null) {
          bioAge = computed;
          calculatedPace = bioAge / chronAge;
        }
      }
    }
    
    final int ageDiff = (bioAge != null && chronAge != null) ? (bioAge - chronAge).abs() : 0;
    final bool isYounger = (bioAge != null && chronAge != null) ? bioAge < chronAge : false;



    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.nc.scaffoldBg,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: Size.zero,
          child: Container(color: Colors.transparent),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Solid background layer
            Container(
              color: context.nc.scaffoldBg,
            ),
            
            // ── HOME-SPECIFIC AMBIENT GLOW (Stronger Gradient) ──
            if (context.nc.isDark) ...[
                // Indigo/Purple Aura (Top Left)
                Positioned(
                  top: -150,
                  left: -100,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF4F46E5).withValues(alpha: 0.5),
                          const Color(0xFF4F46E5).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Emerald/Teal Aura (Center Right)
                Positioned(
                  top: 250,
                  right: -150,
                  child: Container(
                    width: 450,
                    height: 450,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF10B981).withValues(alpha: 0.25),
                          const Color(0xFF10B981).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Amber/Rose Aura (Bottom Left)
                Positioned(
                  bottom: 50,
                  left: -150,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          const Color(0xFFF59E0B).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
             ],
            // Background image when image theme is enabled (Disabled in Dark Mode)
            if (isImageTheme && !context.nc.isDark)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/theme_bg.png',
                  fit: BoxFit.cover,
                ),
              ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (_) {
                _startExtent = _sheetExtentNotifier.value;
              },
              onVerticalDragUpdate: (details) {
                final delta = details.primaryDelta ?? 0;
                final screenHeight = MediaQuery.of(context).size.height;
                // High sensitivity (2.5x) for an effortless feel
                final newExtent = (_sheetExtentNotifier.value - (2.5 * delta / screenHeight)).clamp(0.24, 0.85);
                _sheetController.jumpTo(newExtent);
              },
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                
                // 1. High Velocity Flick (Trigger next state immediately)
                if (velocity < -200) { // Flick UP
                  double target = _startExtent < 0.38 ? 0.45 : 0.85;
                  _sheetController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                  return;
                }
                if (velocity > 200) { // Flick DOWN
                  double target = _startExtent > 0.6 ? 0.45 : 0.24;
                  _sheetController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                  return;
                }
 
                // 2. Small Displacement Snap (Change state if moved > 5%)
                final displacement = _sheetExtentNotifier.value - _startExtent;
                if (displacement.abs() > 0.05) {
                  double target = _startExtent;
                  if (displacement > 0) { // Moved UP
                    target = _startExtent < 0.4 ? 0.45 : 0.85;
                  } else { // Moved DOWN
                    target = _startExtent > 0.6 ? 0.45 : 0.24;
                  }
                  _sheetController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                } else {
                  // Not enough movement, snap back to origin
                  _sheetController.animateTo(_startExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
                }
              },
              // Wrap the morphing card area in ValueListenableBuilder to isolate rebuilds
              child: Stack(
                children: [
                  // 1. STATIC header — never needs to rebuild due to scroll
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SizedBox(height: 16 * rs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Welcome,", style: TextStyle(color: BrandColors.slate400, fontSize: 14 * rs)),
                                    Text(name, style: TextStyle(color: Colors.white, fontSize: 20 * rs, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    // Removed old XpCoinsHeader from here
                                  ],
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => context.push('/settings/leagues'),
                                      child: const CoinsPill(),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => context.push('/settings'),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(LucideIcons.settings, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. ANIMATED section — morphing card + action icons
                  // AnimatedBuilder on the controller (a Listenable) so only THIS
                  // sub-tree rebuilds on scroll, not the entire build() method.
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _sheetExtentNotifier,
                      builder: (context, _) {
                        final sheetExtent = _sheetExtentNotifier.value;

                        // --- ANIMATION CONTROLLERS ---
                        final double upProgress = ((sheetExtent - 0.45) / (0.85 - 0.45)).clamp(0.0, 1.0);
                        final double downProgress = ((0.45 - sheetExtent) / (0.45 - 0.24)).clamp(0.0, 1.0);
                        final double morphCurve = upProgress;

                        // --- LAYOUT INTERPOLATION ---
                        final double sheetTopDefault = screenHeight * (1 - 0.45);
                        final double headerBottom = 75.0 * rs;
                        final double cardHeight = 200.0 * rs;
                        final double actionIconGap = 32.0 * rs;
                        final double contentHeight = cardHeight + actionIconGap + 96.0 * rs;

                        double defaultOffset = (sheetTopDefault - headerBottom - contentHeight) * 0.3;
                        if (defaultOffset < 0) defaultOffset = 0;
                        final double defaultTop = (headerBottom + defaultOffset).clamp(30.0, double.infinity);

                        final double sheetTopDown = screenHeight * 0.80;
                        double downOffset = (sheetTopDown - headerBottom - contentHeight) / 2;
                        if (downOffset < 0) downOffset = 0;
                        final double downTop = (headerBottom + downOffset).clamp(50.0, double.infinity);

                        final double startTop = ui.lerpDouble(defaultTop, downTop, downProgress) ?? defaultTop;
                        const double startLeft = 24.0;
                        const double startRight = 24.0;
                        final double startHeight = cardHeight;

                        const double endTop = 16.0;
                        const double pillWidth = 96.0; // Increased from 75.0 for better text fit
                        const double endRight = 76.0;
                        final double endLeft = screenWidth - endRight - pillWidth;
                        const double endHeight = 48.0;

                        final double currentTop = ui.lerpDouble(startTop, endTop, morphCurve) ?? startTop;
                        final double currentLeft = ui.lerpDouble(startLeft, endLeft, morphCurve) ?? startLeft;
                        final double currentRight = ui.lerpDouble(startRight, endRight, morphCurve) ?? startRight;
                        final double currentHeight = ui.lerpDouble(startHeight, endHeight, morphCurve) ?? startHeight;

                        final double bigContentOpacity = (1.0 - (upProgress - 0.2) * 2.5).clamp(0.0, 1.0);
                        final double pillContentOpacity = ((upProgress - 0.6) * 2.5).clamp(0.0, 1.0);
                        final double actionsOpacity = (1.0 - upProgress * 3.0).clamp(0.0, 1.0);

                        final currentPadding = EdgeInsets.lerp(
                          const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          EdgeInsets.zero,
                          upProgress,
                        ) ?? const EdgeInsets.fromLTRB(16, 16, 16, 8);

                        return Stack(
                          children: [
                            // 2a. Ask Intelligence Pill (shown when sheet is pulled down)
                            if (downProgress > 0.05)
                              Positioned(
                                top: MediaQuery.of(context).padding.top + currentTop - 75,
                                left: 24,
                                right: 24,
                                child: Opacity(
                                  opacity: downProgress,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () => context.push('/settings/leagues'),
                                      child: const XpCoinsPill(),
                                    ),
                                  ),
                                ),
                              ),

                            // 2b. Morphing BioCard
                            Positioned(
                              top: MediaQuery.of(context).padding.top + currentTop,
                              left: currentLeft,
                              right: currentRight,
                              height: currentHeight,
                              child: Consumer(
                                builder: (context, ref, child) {
                                  ref.watch(purchaseProvider);
                                  final profile = ref.watch(patientProfileProvider).value;

                                  return _LockedCardOverlay(
                                    isLocked: false, // Unlocked for all users
                                    onTap: () => PaywallScreen.show(context),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      decoration: BoxDecoration(
                                        color: context.nc.cardSurfaceElevated,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: context.nc.cardBorder),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: BackdropFilter(
                                          filter: ui.ImageFilter.blur(
                                            sigmaX: context.nc.isDark ? 30 : 0,
                                            sigmaY: context.nc.isDark ? 30 : 0,
                                          ),
                                          child: Stack(
                                            children: [
                                            Opacity(
                                              opacity: bigContentOpacity,
                                              child: SingleChildScrollView(
                                                physics: const NeverScrollableScrollPhysics(),
                                                child: SizedBox(
                                                  height: cardHeight,
                                                  width: screenWidth - 48,
                                                    child: Consumer(
                                                      builder: (context, ref, _) {
                                                        final activityGoals = ref.watch(activityGoalsProvider);
                                                        final labReports = ref.watch(labReportsProvider).value ?? [];
                                                        return _HeroMetricCardContent(
                                                          profile: profile,
                                                          bioAge: bioAge,
                                                          chronAge: chronAge,
                                                          ageDiff: ageDiff,
                                                          pace: calculatedPace,
                                                          padding: currentPadding,
                                                          wearable: wearable,
                                                          selectedMetric: _selectedHeroMetric,
                                                          activityGoals: activityGoals,
                                                          labReports: labReports,
                                                          ref: ref,
                                                          onMetricSelected: (metric) {
                                                            setState(() {
                                                              _selectedHeroMetric = metric;
                                                            });
                                                            _saveSelectedMetric(metric); // Save selection
                                                          },
                                                        );
                                                      }
                                                    ),
                                                ),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Opacity(
                                                opacity: pillContentOpacity,
                                                child: Center(
                                                  child: Builder(
                                                    builder: (context) {
                                                      if (_selectedHeroMetric == 'VO2 MAX') {
                                                        return Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Text(wearable?.vo2Max?.toStringAsFixed(1) ?? "--", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.nc.textPrimary, height: 1.0)),
                                                            const SizedBox(width: 4),
                                                            Text("ml/kg\n/min", style: TextStyle(fontSize: 9, color: context.nc.textTertiary, height: 1.1)),
                                                          ],
                                                        );
                                                        } else if (_selectedHeroMetric == 'HRV') {
                                                          return Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              Text("${wearable?.hrv?.round() ?? "--"}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.nc.textPrimary, height: 1.0)),
                                                              const SizedBox(width: 4),
                                                              Text("ms\nHRV", style: TextStyle(fontSize: 9, color: context.nc.textTertiary, height: 1.1)),
                                                            ],
                                                          );
                                                        } else if (_selectedHeroMetric == 'ENERGY BURNED') {
                                                          return Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              Text("${wearable?.activeEnergy.round() ?? "--"}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.nc.textPrimary, height: 1.0)),
                                                              const SizedBox(width: 4),
                                                              Text("kcal\nburned", style: TextStyle(fontSize: 9, color: context.nc.textTertiary, height: 1.1)),
                                                            ],
                                                          );
                                                        } else if (_selectedHeroMetric == 'STEPS') {
                                                          return Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              Text("${wearable?.steps ?? "--"}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.nc.textPrimary, height: 1.0)),
                                                              const SizedBox(width: 4),
                                                              Text("steps\ntoday", style: TextStyle(fontSize: 9, color: context.nc.textTertiary, height: 1.1)),
                                                            ],
                                                          );
                                                        }
                                                        
                                                        return Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Text("$ageDiff", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.nc.textPrimary, height: 1.0)),
                                                          const SizedBox(width: 4),
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text("years", style: TextStyle(fontSize: 9, color: context.nc.textTertiary, height: 1.1)),
                                                              Text(isYounger ? "younger" : "older", style: TextStyle(fontSize: 9, color: context.nc.textTertiary, height: 1.1)),
                                                            ],
                                                          ),
                                                        ],
                                                      );
                                                    }
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                },
                              ),
                            ),

                            // 2c. Action Icons
                            Positioned(
                              top: MediaQuery.of(context).padding.top + currentTop + currentHeight + actionIconGap,
                              left: 24,
                              right: 24,
                              child: Opacity(
                                opacity: actionsOpacity,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ActionCircle(assetPath: 'assets/icons/diet_plan.png', label: "Diet Plan", onTap: () => context.push('/weekly-menu'), isGlass: isImageTheme),
                                    _ActionCircle(assetPath: 'assets/icons/food_log.png', label: "Log Meal", onTap: () {
  ref.read(lensScanProvider.notifier).reset();
  context.push('/lens');
}, isGlass: isImageTheme),
                                    _ActionCircle(icon: Icons.auto_awesome_rounded, label: "Ask AI", onTap: () => context.push('/chat'), isGlass: isImageTheme),
                                    _ActionCircle(icon: LucideIcons.flower, label: "Meditate", onTap: () => context.push('/meditate'), isGlass: isImageTheme),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),


          // --- LAYER 2: Draggable Sheet ---
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // Update ValueNotifier instead of setState — only rebuilds the
              // ValueListenableBuilder above, not the entire build() method
              if ((notification.extent - _sheetExtentNotifier.value).abs() > 0.001) {
                _sheetExtentNotifier.value = notification.extent;
              }
              return true;
            },
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.45,
              minChildSize: 0.24, // Raised slightly from 0.20
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.24, 0.45, 0.85],
              builder: (context, scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: context.nc.isDark ? 25.0 : (isImageTheme ? 15.0 : 0.0),
                      sigmaY: context.nc.isDark ? 25.0 : (isImageTheme ? 15.0 : 0.0),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.nc.isDark 
                            ? context.nc.cardSurface.withOpacity(0.5) 
                            : (isImageTheme ? context.nc.cardSurface.withOpacity(0.9) : context.nc.cardSurface),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        border: Border(
                          top: BorderSide(
                            color: context.nc.isDark 
                                ? Colors.white.withOpacity(0.12) 
                                : context.nc.cardBorder,
                            width: 1.5,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            final double dy = notification.scrollDelta ?? 0.0;
                            // Hide navbar when scrolling down (dy > 3.0), show when scrolling up (dy < -3.0)
                            if (dy > 3.0) {
                              ref.read(navbarVisibleProvider.notifier).hide();
                            } else if (dy < -3.0) {
                              ref.read(navbarVisibleProvider.notifier).show();
                            }
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                          child: _buildDashboardContent(context),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              'Intelligence Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        
        if (_activeTab == 0) ...[
          Builder(
            builder: (context) {
              final moduleOrder = ref.watch(moduleOrderProvider);
              return Column(
                children: moduleOrder.map((module) {
                  switch (module) {
                    case IntelligenceModule.protocol:
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: RhythmCard(key: ValueKey('rhythm_tab')),
                      );
                    case IntelligenceModule.food:
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildFoodIntelligenceCard(),
                      );
                    case IntelligenceModule.cardio:
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: CardioModuleCard(),
                      );
                    case IntelligenceModule.performance:
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: PerformanceModuleCard(),
                      );
                  }
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 64),
        ] else if (_activeTab == 1) ...[
          _buildMealsTab(key: const ValueKey('meals_tab')),
          const SizedBox(height: 80),
        ],
      ],
    );
  }

  Widget _buildFoodIntelligenceCard() {
    return ref.watch(foodLogsProvider).when(
      data: (logs) {
        double totalCal = 0;
        double totalPro = 0;
        double totalCarb = 0;
        double totalFat = 0;
        double totalScore = 0;
        int mealsScored = 0;
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        for (final log in logs) {
          final logDay = DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
          if (logDay == todayDate) {
            final analysis = FoodAnalysis.fromJson(log.analysis);
            totalCal += analysis.calories;
            totalPro += analysis.macros.protein.toDouble();
            totalCarb += analysis.macros.carbs.toDouble();
            totalFat += analysis.macros.fat.toDouble();
            if (analysis.score > 0) {
              totalScore += analysis.score;
              mealsScored++;
            }
          }
        }
        final avgScore = mealsScored > 0 ? totalScore / mealsScored : 0.0;
        return _buildNutritionSummaryCard(totalCal, totalPro, totalCarb, totalFat, avgScore);
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildMealsTab({Key? key}) {
    return _buildMealsTabContent(key: key);
  }

  Widget _buildMealsTabContent({Key? key}) {
    final logsAsync = ref.watch(foodLogsProvider);

    return KeyedSubtree(
      key: key,
      child: logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(LucideIcons.utensilsCrossed, size: 48, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 16),
                Text(
                  'No meals logged yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use Zyndio Lens to analyze your first meal and see its biological impact!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(lensScanProvider.notifier).reset();
                    context.push('/lens');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.emerald500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Start Food Scan'),
                ),
              ],
            ),
          );
        }

        // Group logs by date (borrowed logic from LensHistoryScreen)
        final Map<String, List<FoodLog>> grouped = {};
        double totalCal = 0;
        double totalPro = 0;
        double totalCarb = 0;
        double totalFat = 0;
        double totalScore = 0;
        int mealsScored = 0;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (final log in logs) {
          final day = _formatDateHeader(log.loggedAt);
          grouped.putIfAbsent(day, () => []).add(log);

          // Calculate today's totals
          final logDay = DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
          if (logDay == today) {
            final analysis = FoodAnalysis.fromJson(log.analysis);
            totalCal += analysis.calories;
            totalPro += analysis.macros.protein.toDouble();
            totalCarb += analysis.macros.carbs.toDouble();
            totalFat += analysis.macros.fat.toDouble();
            if (analysis.score > 0) {
              totalScore += analysis.score;
              mealsScored++;
            }
          }
        }

        final avgScore = mealsScored > 0 ? totalScore / mealsScored : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNutritionSummaryCard(totalCal, totalPro, totalCarb, totalFat, avgScore),
            const SizedBox(height: 8),
            Center(
              child: Opacity(
                opacity: 0.6,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NutritionTrendsScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Trends',
                          style: TextStyle(
                            color: context.nc.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.arrowRight, size: 14, color: context.nc.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...grouped.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 8),
                child: Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: BrandColors.slate400,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ...entry.value.map((log) => _buildMealCard(log)),
            ]),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.emerald500)),
              SizedBox(height: 12),
              Text('Fetching your meals...', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(date.year, date.month, date.day);
    if (logDay == today) return 'Today';
    if (logDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildMealCard(FoodLog log) {
    final foodName = log.analysis['food_name'] ?? log.analysis['dish_name'] ?? 'Analyzed Meal';
    final score = log.analysis['score'] ?? 0;
    final calories = log.analysis['calories'] ?? 0;
    final timeStr = DateFormat('h:mm a').format(log.loggedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/meal-detail', extra: log),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.nc.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.nc.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
              // Score Ring (mini)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (score >= 80 ? BrandColors.emerald500 : (score >= 50 ? BrandColors.amber500 : BrandColors.red500)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: score >= 80 ? BrandColors.emerald500 : (score >= 50 ? BrandColors.amber500 : BrandColors.red500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.nc.textPrimary),
                    ),
                    Text(
                      '$calories kcal • $timeStr',
                      style: TextStyle(fontSize: 12, color: context.nc.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: BrandColors.slate300),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildNutritionSummaryCard(double cal, double pro, double carb, double fat, double score) {
    final goals = ref.watch(nutritionGoalsProvider);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutQuart,
      builder: (context, animValue, child) {
        final currentCal = (cal * animValue).round();
        final progress = (cal / 2200).clamp(0.0, 1.0);

        return Container(
          width: double.infinity,
          height: 440,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF10B981), Color(0xFF022C22)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: context.nc.isDark ? 20 : 0,
                sigmaY: context.nc.isDark ? 20 : 0,
              ),
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
              // Radial Glow
              Positioned(
                top: -50,
                left: 0,
                right: 0,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.15),
                        const Color(0xFF10B981).withOpacity(0),
                      ],
                      center: Alignment.topCenter,
                      radius: 1.0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 13),
                child: Column(
                  children: [
                    Text(
                      'FOOD INTELLIGENCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Segmented Dial
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -70),
                          child: SizedBox(
                            width: 240,
                            height: 160,
                            child: CustomPaint(
                              painter: SegmentedDialPainter(
                                progress: progress,
                                animValue: animValue,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            const SizedBox(height: 40),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentCal.toString(),
                                  style: const TextStyle(
                                    fontSize: 54,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -2,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.3),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getBadgeText(cal, goals),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white.withOpacity(0.8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getInsightTitle(cal, pro, goals),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getInsightDescription(cal, pro, carb, fat, goals),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Macro Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroMini('PROTEIN', '${pro.round()}g'),
                          Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                          _buildMacroMini('CARBOHYDRATES', '${carb.round()}g'),
                          Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                          _buildMacroMini('FATS', '${fat.round()}g'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodIntelligenceScreen()));
                  },
                  child: Icon(LucideIcons.chevronRight, size: 20, color: Colors.white.withOpacity(0.4)),
                ),
              ),
            ],
          ),
        ),
        ),
        );
      },
    );
  }

  Widget _buildMacroMini(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _getBadgeText(double cal, NutritionGoals goals) {
    if (cal == 0) return 'FASTING';
    final phase = _getMetabolicPhase(cal);
    switch (phase) {
      case 'ABSORPTION': return 'ABSORPTION';
      case 'GLYCOGEN LOAD': return 'REPLENISHING';
      case 'ANABOLIC': return 'REBUILDING';
      default: return 'ACTIVE';
    }
  }

  String _getInsightTitle(double cal, double pro, NutritionGoals goals) {
    if (cal == 0) return 'Your body is repairing';
    final phase = _getMetabolicPhase(cal);
    switch (phase) {
      case 'ABSORPTION':
        return 'Processing your last meal';
      case 'GLYCOGEN LOAD':
        return 'Refilling your fuel tanks';
      case 'ANABOLIC':
        return 'Building and recovering';
      default:
        return 'Your metabolism is active';
    }
  }

  String _getInsightDescription(double cal, double pro, double carb, double fat, NutritionGoals goals) {
    final phase = _getMetabolicPhase(cal);
    
    // Determine leading nutrient profile
    String profile = 'balanced';
    if (cal == 0) {
      profile = 'start';
    } else {
      final total = pro + carb + fat;
      if (total > 0) {
        final p = pro / total;
        final c = carb / total;
        final f = fat / total;
        if (p > 0.35) profile = 'protein';
        else if (c > 0.45) profile = 'carb';
        else if (f > 0.35) profile = 'fat';
      }
    }

    // 16-Combination Matrix
    switch (phase) {
      case 'FASTING':
        if (profile == 'start') return "Good morning! Your body spent the night repairing. You're primed and ready for your first meal.";
        if (profile == 'protein') return "You're in deep repair mode. Your body is clearing old cells, but let's prioritize protein in your next meal.";
        if (profile == 'carb') return "Your body is successfully switching to fat-burning. You're becoming more metabolically flexible right now.";
        return "You've reached a perfect state of metabolic rest. Your system is recovering and preparing for a fresh start.";
      
      case 'ABSORPTION':
        if (profile == 'protein') return "You've fueled up with quality protein. Your body is busy breaking this down to support your muscle tissue.";
        if (profile == 'carb') return "You've got a fresh energy boost. Your body is converting those carbs into immediate fuel for your brain.";
        if (profile == 'fat') return "That was a healthy dose of fats. Your blood sugar is likely stable as you absorb these key nutrients.";
        return "Your body is taking in nutrients from your recent log to fuel your upcoming activity levels.";

      case 'GLYCOGEN LOAD':
        if (profile == 'protein') return "Your energy stores are refilling, and that extra protein is ensuring your recovery is high-quality today.";
        if (profile == 'carb') return "You're topping up your glycogen tanks. You'll feel strong and energized for your next physical challenge.";
        if (cal > goals.calorieGoal * 0.9) return "You're almost at your daily target. Your body is well-fueled and ready to tackle the rest of your day.";
        return "Your fuel levels are rising steadily. You're providing your body with exactly what it needs to stay at peak.";

      case 'ANABOLIC':
        if (pro >= goals.proteinGoal) return "Great job on the protein! Your body is in a prime state for muscle growth and tissue repair right now.";
        if (carb >= goals.carbGoal) return "Your energy reserves are full. You've provided enough fuel to support both recovery and tomorrow's activity.";
        if (fat >= goals.fatGoal) return "Your hormonal health is supported by your healthy intake. Your recovery system is operating at 100%.";
        return "You've hit the metabolic sweet spot. Your body has everything it needs to rebuild stronger than before.";

      default:
        return "You're in a great spot. Your current nutrition is perfectly aligned with your activity levels.";
    }
  }

  String _getMetabolicPhase(double cal) {
    if (cal == 0) return 'FASTING';
    if (cal < 500) return 'ABSORPTION';
    if (cal < 1500) return 'GLYCOGEN LOAD';
    return 'ANABOLIC';
  }

}

class _ActionCircle extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final String label;
  final VoidCallback onTap;
  final bool isGlass;

  const _ActionCircle({this.icon, this.assetPath, required this.label, required this.onTap, this.isGlass = false});

  @override
  Widget build(BuildContext context) {
    final double rs = (MediaQuery.of(context).size.height / 900).clamp(0.82, 1.0);
    final bgColor = isGlass ? Colors.white.withOpacity(0.20) : context.nc.cardSurface;
    final borderColor = isGlass ? Colors.white.withOpacity(0.3) : context.nc.cardBorder;
    final iconColor = isGlass ? Colors.white : context.nc.textPrimary;
    final double circleSize = 56 * rs;
    final double iconSize = 24 * rs;
    final double innerPadding = 14 * rs;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: isGlass
            ? ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: circleSize, height: circleSize,
                    padding: EdgeInsets.all(innerPadding),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: assetPath != null 
                      ? Image.asset(assetPath!, fit: BoxFit.contain)
                      : Icon(icon, color: iconColor, size: iconSize),
                  ),
                ),
              )
            : Container(
                width: circleSize, height: circleSize,
                padding: EdgeInsets.all(innerPadding),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                ),
                child: assetPath != null 
                  ? Image.asset(assetPath!, fit: BoxFit.contain)
                  : Icon(icon, color: iconColor, size: iconSize),
              ),
        ),
        SizedBox(height: 6 * rs),
        Text(
          label, 
          textAlign: TextAlign.center,
          style: TextStyle(
             color: isGlass ? Colors.white.withOpacity(0.9) : context.nc.textTertiary, 
             fontSize: 11 * rs, fontWeight: FontWeight.w500, height: 1.2
          )
        ),
      ],
    );
  }
}




class _HeroMetricCardContent extends StatelessWidget {
  final dynamic profile;
  final int? bioAge;
  final int? chronAge;
  final int ageDiff;
  final double? pace;
  final EdgeInsets padding;
  final dynamic wearable;
  final String selectedMetric;
  final dynamic activityGoals;
  final List<LabReport> labReports;
  final WidgetRef ref;
  final ValueChanged<String> onMetricSelected;

  const _HeroMetricCardContent({
    required this.profile,
    required this.bioAge,
    required this.chronAge,
    required this.ageDiff,
    this.pace,
    this.padding = const EdgeInsets.all(24),
    this.wearable,
    required this.selectedMetric,
    required this.activityGoals,
    required this.labReports,
    required this.ref,
    required this.onMetricSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double rs = (MediaQuery.of(context).size.height / 900).clamp(0.82, 1.0);
    final bool hasBioData = bioAge != null;
    final double displayPace = pace ?? 1.0;
    final bool isYounger = (bioAge != null && chronAge != null) ? bioAge! < chronAge! : false;

    // Default: Biological Age
    String mainValue = hasBioData ? bioAge.toString() : "--";
    Widget subtext = hasBioData 
      ? Text(ageDiff == 0 ? "Optimized to match age" : "$ageDiff years ${isYounger ? 'younger' : 'older'}", style: TextStyle(fontSize: 18 * rs, color: context.nc.textTertiary, fontWeight: FontWeight.normal))
      : Text("Calculated from markers", style: TextStyle(fontSize: 16 * rs, color: context.nc.textTertiary, fontWeight: FontWeight.w500));
    
    Widget rightSide = Builder(builder: (context) {
      final Color paceColor;
      if (displayPace <= 1.0) paceColor = const Color(0xFF10B981);
      else if (displayPace <= 1.15) paceColor = const Color(0xFFF59E0B);
      else paceColor = const Color(0xFFEF4444);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Aging Speed", style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text("${displayPace.toStringAsFixed(2)}x", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: paceColor)),
        ],
      );
    });

    if (selectedMetric == 'VO2 MAX') {
      mainValue = wearable?.vo2Max?.toStringAsFixed(1) ?? "--";
      subtext = Text("ml/kg/min", style: TextStyle(fontSize: 18 * rs, color: context.nc.textTertiary, fontWeight: FontWeight.normal));
      
      final fitness = Vo2MaxService.classifyFitness(
        wearable?.vo2Max ?? 0, 
        age: profile?.age,
        isMale: profile?.questionnaireData?['gender'] == 'Male',
      );
      String fitnessLevel = wearable?.vo2Max != null ? fitness.level : 'Unknown';
      Color fitnessColor = wearable?.vo2Max != null ? fitness.color : BrandColors.slate400;
      rightSide = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Fitness Level", style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(fitnessLevel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fitnessColor)),
        ],
      );
    } else if (selectedMetric == 'HRV') {
      mainValue = wearable?.hrv != null ? wearable!.hrv!.round().toString() : "--";
      subtext = Text("ms (RMSSD)", style: TextStyle(fontSize: 18 * rs, color: context.nc.textTertiary, fontWeight: FontWeight.normal));
      
      String stressStatus = 'Normal';
      Color stressColor = const Color(0xFF10B981); // Emerald
      if (wearable?.stressScore != null) {
        final int s = wearable!.stressScore!;
        if (s >= 75) { stressStatus = 'High Stress'; stressColor = const Color(0xFFEF4444); }
        else if (s >= 40) { stressStatus = 'Moderate'; stressColor = const Color(0xFFF59E0B); }
      }
      
      rightSide = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Stress State", style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(stressStatus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stressColor)),
        ],
      );
    } else if (selectedMetric == 'ENERGY BURNED') {
      mainValue = (wearable?.activeEnergy ?? 0) > 0 ? wearable!.activeEnergy.round().toString() : "--";
      subtext = Text("kcal today", style: TextStyle(fontSize: 18 * rs, color: context.nc.textTertiary, fontWeight: FontWeight.normal));
      
      final double progress = activityGoals != null ? (wearable?.activeEnergy ?? 0) / activityGoals.moveGoal : 0;
      
      rightSide = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Move Goal", style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text("${(progress * 100).round()}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFF97316))), // Orange
        ],
      );
    } else if (selectedMetric == 'STEPS') {
      mainValue = wearable?.steps != null ? wearable!.steps!.toString() : "--";
      subtext = Text("steps today", style: TextStyle(fontSize: 18 * rs, color: context.nc.textTertiary, fontWeight: FontWeight.normal));
      
      final double progress = activityGoals != null ? (wearable?.steps ?? 0) / activityGoals.stepsGoal : 0;
      
      rightSide = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Daily Goal", style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text("${(progress * 100).round()}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))), // Emerald
        ],
      );
    }

    return Padding(
      padding: padding,
      // Scrollable (but non-scrolling) wrapper: gives the Column unbounded height so it
      // never overflows its fixed-height slot on short screens (small rs) instead of
      // throwing a RenderFlex overflow.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<String>(
                onSelected: onMetricSelected,
                offset: const Offset(0, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.nc.cardBorder, width: 1),
                ),
                color: context.nc.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                elevation: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selectedMetric, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'BIOLOGICAL AGE', child: Text('Biological Age', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                  PopupMenuItem(value: 'VO2 MAX', child: Text('VO₂ Max', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                  PopupMenuItem(value: 'HRV', child: Text('HRV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                  PopupMenuItem(value: 'ENERGY BURNED', child: Text('Energy Burned', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                  PopupMenuItem(value: 'STEPS', child: Text('Steps', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
                ],
              ),
              GestureDetector(
                onTap: () => _showMetricInfo(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.nc.textPrimary.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.info, color: context.nc.textPrimary, size: 20),
                ),
              )
            ],
          ),
          
          const SizedBox(height: 42),

          // 2. Main Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 child: FittedBox(
                   fit: BoxFit.scaleDown,
                   alignment: Alignment.bottomLeft,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                           mainValue,
                           style: TextStyle(fontSize: 64 * rs, fontWeight: FontWeight.w900, color: context.nc.textPrimary, height: 1.0, letterSpacing: -2.0)
                       ),
                       SizedBox(height: 4 * rs),
                       subtext,
                     ],
                   ),
                 ),
               ),
               const SizedBox(width: 8),
               rightSide,
            ],
          ),
        ],
        ),
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context, String markerName, String unit) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.nc.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Enter $markerName',
          style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manually entering this value will update your Biological Age calculation.',
              style: TextStyle(color: context.nc.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: context.nc.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 85.5',
                suffixText: unit,
                suffixStyle: TextStyle(color: context.nc.textTertiary, fontWeight: FontWeight.bold),
                hintStyle: TextStyle(color: context.nc.textTertiary),
                filled: true,
                fillColor: context.nc.isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.nc.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && profile?.id != null) {
                final success = await HealthDataRepository.saveManualBiomarker(
                  profileId: profile.id,
                  markerName: markerName,
                  value: controller.text,
                  unit: unit,
                );
                
                if (success) {
                  // Invalidate provider to refresh data
                  ref.invalidate(labReportsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$markerName updated successfully'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMetricInfo(BuildContext context) {
    final Map<String, Map<String, String>> info = {
      'BIOLOGICAL AGE': {
        'title': 'Biological Age',
        'desc': 'Biological age measures how your body is functioning at a cellular level compared to your chronological age. It is the "true" age of your body\'s systems.',
        'impact': 'Lowering your biological age is the gold standard for longevity. It reflects improved cellular repair, metabolic health, and a lower risk of age-related decline.',
        'tip': 'Optimize sleep, manage chronic stress, and maintain a high-nutrient diet to "de-age" your biological markers.'
      },
      'VO2 MAX': {
        'title': 'VO₂ Max',
        'desc': 'VO₂ Max is the maximum rate of oxygen your body can utilize during intense exercise. It is the single most accurate measure of cardiorespiratory fitness.',
        'impact': 'Statistically, a higher VO₂ Max is one of the strongest predictors of a long, healthy life. It strengthens heart efficiency and mitochondrial health.',
        'tip': 'Incorporate at least one Zone 2 session and one HIIT session per week to effectively raise your VO₂ Max.'
      },
      'HRV': {
        'title': 'Heart Rate Variability',
        'desc': 'HRV measures the millisecond variations between consecutive heartbeats. It is a direct window into your autonomic nervous system.',
        'impact': 'High HRV indicates a resilient, well-recovered system ready for stress. Persistent low HRV signals overtraining, high stress, or potential illness.',
        'tip': 'Focus on deep breathing (box breathing) and consistent sleep windows to improve your nervous system resilience.'
      },
      'ENERGY BURNED': {
        'title': 'Energy Burned',
        'desc': 'This represents the active calories you have burned through movement and exercise today, beyond your resting metabolic rate.',
        'impact': 'Consistent daily movement prevents metabolic dysfunction, improves insulin sensitivity, and is critical for maintaining healthy body composition.',
        'tip': 'Avoid long periods of sitting. Even 2 minutes of movement every hour can significantly improve your daily energy expenditure profile.'
      },
      'STEPS': {
        'title': 'Daily Steps',
        'desc': 'Steps are a fundamental indicator of baseline physical activity and non-exercise thermogenesis (NEAT).',
        'impact': 'Walking 8,000–10,000 steps per day is linked to significant reductions in all-cause mortality, improved cardiovascular health, and better mood regulation.',
        'tip': 'Take a 10-minute walk after each meal. This not only hits your step goal but also effectively blunts blood glucose spikes.'
      },
    };

    final data = info[selectedMetric] ?? info['BIOLOGICAL AGE']!;
    
    // Biomarker Checklist Logic for Bio Age
    final List<Map<String, dynamic>> biomarkers = [
      {'name': 'Glucose', 'unit': 'mg/dL', 'aliases': ['blood glucose', 'fasting glucose', 'fbs', 'blood sugar', 'glucose']},
      {'name': 'HbA1c', 'unit': '%', 'aliases': ['hemoglobin a1c', 'glycated hemoglobin', 'a1c', 'hba1c']},
      {'name': 'HDL', 'unit': 'mg/dL', 'aliases': ['hdl', 'hdl-c', 'high density lipoprotein']},
      {'name': 'LDL', 'unit': 'mg/dL', 'aliases': ['ldl', 'ldl-c', 'low density lipoprotein', 'ldl cholesterol']},
      {'name': 'Triglycerides', 'unit': 'mg/dL', 'aliases': ['tg', 'trigs', 'triglycerides']},
      {'name': 'Creatinine', 'unit': 'mg/dL', 'aliases': ['serum creatinine', 'creatinine', 'cr']},
      {'name': 'ALT', 'unit': 'U/L', 'aliases': ['alanine aminotransferase', 'alt', 'sgpt']},
      {'name': 'Hemoglobin', 'unit': 'g/dL', 'aliases': ['hemoglobin', 'hgb', 'hb', 'haemoglobin']},
      {'name': 'TSH', 'unit': 'mIU/L', 'aliases': ['thyroid stimulating hormone', 'tsh']},
      {'name': 'Vitamin D', 'unit': 'ng/mL', 'aliases': ['25-oh vitamin d', '25-hydroxyvitamin d', 'vit d', 'vitamin d', 'vitamin d3']},
    ];

    final Set<String> presentBiomarkers = {};
    for (final report in labReports) {
      for (final marker in report.markers) {
        final mName = marker.name.toLowerCase().trim();
        for (final config in biomarkers) {
          final allNames = [config['name'].toLowerCase(), ...config['aliases'].map((a) => a.toString().toLowerCase())];
          if (allNames.contains(mName)) {
            presentBiomarkers.add(config['name']);
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true, 
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: context.nc.isDark 
              ? const Color(0xFF0F172A).withOpacity(0.96)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: context.nc.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Stack(
              children: [
                // Zenith Aurora Blobs
                if (context.nc.isDark) ...[
                  Positioned(
                    top: -80, right: -80,
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4F46E5).withOpacity(0.12),
                            const Color(0xFF4F46E5).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40, left: -40,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.08),
                            const Color(0xFF10B981).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.nc.textPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title']!,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: context.nc.textPrimary,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'WHAT IT IS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: context.nc.textTertiary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['desc']!,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.nc.textSecondary,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'WHY IT MATTERS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: context.nc.textTertiary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['impact']!,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.nc.textSecondary,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            if (selectedMetric == 'BIOLOGICAL AGE') ...[
                              const SizedBox(height: 28),
                              Text(
                                'BIOMARKER CHECKLIST',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: context.nc.textTertiary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.nc.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: context.nc.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: biomarkers.map((b) {
                                    final isPresent = presentBiomarkers.contains(b['name']);
                                    return GestureDetector(
                                      onTap: () => _showManualEntryDialog(context, b['name'], b['unit']),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isPresent 
                                              ? const Color(0xFF10B981).withOpacity(0.08) 
                                              : context.nc.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isPresent 
                                                ? const Color(0xFF10B981).withOpacity(0.15) 
                                                : Colors.transparent,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPresent ? Icons.check_circle : Icons.add_circle_outline,
                                              size: 11,
                                              color: isPresent ? const Color(0xFF10B981) : context.nc.textTertiary,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              b['name'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isPresent ? const Color(0xFF10B981) : context.nc.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.nc.textPrimary,
                                  foregroundColor: context.nc.scaffoldBg,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Got it',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                ),
                              ),
                            ),
                            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                          ],
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
    );
  }
}

class _LockedCardOverlay extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final VoidCallback? onTap;

  const _LockedCardOverlay({
    required this.child,
    required this.isLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? onTap : null,
      child: Stack(
        children: [
          // Content always at the same level to prevent RenderObject detached errors
          child,
          if (isLocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            // Lock Icon
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6), // Frosted glass feel
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Icon(LucideIcons.lock, color: BrandColors.slate900, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SegmentedDialPainter extends CustomPainter {
  final double progress;
  final double animValue;
  final Color activeColor;
  final Color inactiveColor;

  SegmentedDialPainter({
    required this.progress,
    required this.animValue,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Shallower bridge-like arc
    final center = Offset(size.width / 2, size.height * 1.6);
    final radius = size.width * 0.75;
    const segments = 24;
    const spacing = 0.06; // More defined spacing
    const sweepAngle = math.pi * 0.7; // Shallower sweep
    const startAngle = -math.pi - (sweepAngle - math.pi) / 2;
    
    final segmentAngle = (sweepAngle - (segments - 1) * spacing) / segments;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;

    // 1. Draw Background Track (All segments)
    paint.color = inactiveColor;
    for (int i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i * (segmentAngle + spacing),
        segmentAngle,
        false,
        paint,
      );
    }

    // 2. Draw Active Segments with Glow
    final activeCount = (segments * progress * animValue).floor();
    for (int i = 0; i < activeCount; i++) {
      final angle = startAngle + i * (segmentAngle + spacing);
      
      // Draw Glow Layer
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        segmentAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18 // Slightly thicker for glow
          ..color = activeColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Draw Solid Layer (Perfectly aligned)
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        segmentAngle,
        false,
        paint..color = activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
