
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> showGuidedTour(BuildContext context, {bool force = false}) async {
    return; // Tutorial disabled for now
  }
}
