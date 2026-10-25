
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/tour_overlay.dart';

/// Provider for access to TutorialService
final tutorialServiceProvider = Provider<TutorialService>((ref) {
  return TutorialService();
});

class TutorialService {
  // Navigation Keys
  final GlobalKey navProtocolKey = GlobalKey();
  final GlobalKey navHealthDataKey = GlobalKey();
  final GlobalKey navIntelligenceKey = GlobalKey();
  
  // Feature keys
  final GlobalKey heroCardKey = GlobalKey(); 
  final GlobalKey timelineKey = GlobalKey(); 

  static const String _prefKey = 'has_seen_onboarding_tutorial_v4'; // Bump version for new UI

  Future<void> showGuidedTour(BuildContext context, {bool force = false}) async {
    return; // Tutorial disabled for now
    final prefs = await SharedPreferences.getInstance();
    // Reset for testing: await prefs.setBool(_prefKey, false); 
    final hasSeen = prefs.getBool(_prefKey) ?? false;
    
    if (hasSeen && !force) return;

    if (!context.mounted) return;

    // Define Steps
    List<TourStep> steps = [];

    // 1. Health Overview (BioClock Card)
    if (heroCardKey.currentContext != null) {
      steps.add(TourStep(
        targetKey: heroCardKey,
        title: "Your Health Overview",
        description: "This card shows your biological age pace and key longevity metrics at a glance.",
        alignBottom: true, // Force tooltip to bottom to avoid covering content above
        padding: const EdgeInsets.all(12), // Padded slightly
        borderRadius: 24.0,
        offset: const Offset(0, 40), // Shift down to compensate for status bar/header offset
      ));
    }

    // 2. Today's Insights (Rhythm Card)
    if (timelineKey.currentContext != null) {
      steps.add(TourStep(
        targetKey: timelineKey,
        title: "Today's Insights & Rhythm",
        description: "Your daily plan, optimized by AI. See your personalized tasks for Lifestyle, Diet, and Fitness here.",
        padding: const EdgeInsets.all(0),
        borderRadius: 32.0,
      ));
    }

    // 3. Protocol Tab
    if (navProtocolKey.currentContext != null) {
      steps.add(TourStep(
        targetKey: navProtocolKey,
        title: "Your Protocol",
        description: "Access your personalized daily plan. Explore our Protocol Library to choose curated paths for your longevity journey.",
        onShow: () => context.go('/protocols'),
        padding: const EdgeInsets.all(8),
        borderRadius: 50.0, // Circle/Pill
      ));
    }

    // 4. Health Data Tab
    if (navHealthDataKey.currentContext != null) {
      steps.add(TourStep(
        targetKey: navHealthDataKey,
        title: "Upload Health Data",
        description: "Upload your lab reports here. Our AI analyzes your blood work to unlock deep insights.",
        onShow: () => context.go('/health_data'),
        padding: const EdgeInsets.all(8),
        borderRadius: 50.0,
      ));
    }

    // 5. Meditation Tab
    if (navIntelligenceKey.currentContext != null) {
      steps.add(TourStep(
        targetKey: navIntelligenceKey,
        title: "Mindfulness & Meditation",
        description: "Access curated sessions to lower stress and improve biological markers.",
        onShow: () => context.go('/meditate'),
        padding: const EdgeInsets.all(8),
        borderRadius: 50.0,
      ));
    }

    if (steps.isEmpty) return;

    // Insert Overlay
    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TourOverlay(
          steps: steps,
          onComplete: () {
            overlayEntry?.remove();
            prefs.setBool(_prefKey, true);
          },
          onSkip: () {
            overlayEntry?.remove();
            prefs.setBool(_prefKey, true);
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }
}
