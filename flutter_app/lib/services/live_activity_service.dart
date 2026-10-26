import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiveActivityService {
  /// 🧬 LENS ANALYSIS ACTIVITY
  Future<void> startLensActivity({required String foodName}) async {
    // Feature disabled
  }

  Future<void> updateLensProgress(double progress, String status) async {
    // Feature disabled
  }

  /// ⏱️ FASTING / PROTOCOL TIMER ACTIVITY
  Future<void> startTimerActivity({
    required String title,
    required DateTime endTime,
    required String emoji,
  }) async {
    // Feature disabled
  }

  /// 📊 DAILY RHYTHM ACTIVITY
  Future<void> startRhythmActivity({
    required int score,
    required String nextWindow,
  }) async {
    // Feature disabled
  }

  Future<void> stopAll() async {
    // Feature disabled
  }
}

final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  return LiveActivityService();
});
