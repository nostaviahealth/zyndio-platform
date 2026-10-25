import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _timelineViewKey = 'isSwipeTimeline';

/// Provider to manage the Timeline view layout (List vs Swipe Cards)
class TimelineViewNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadPreference();
    return false; // Default to Vertical List (false)
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_timelineViewKey) ?? false; // Default to Vertical List (false)
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timelineViewKey, value);
  }

  void toggleView() {
    state = !state;
    _savePreference(state);
  }
}

final timelineViewProvider = NotifierProvider<TimelineViewNotifier, bool>(() {
  return TimelineViewNotifier();
});
