import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _darkModeKey = 'isDarkMode';

/// Provider to manage Dark Mode state
class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _forceDarkOnce();
    return true; // Default: Dark Mode
  }

  Future<void> _forceDarkOnce() async {
    final prefs = await SharedPreferences.getInstance();
    // Force true if not set or if previously set to false
    if (prefs.getBool(_darkModeKey) != true) {
      state = true;
      await prefs.setBool(_darkModeKey, true);
    }
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  void toggleDarkMode() {
    state = !state;
    _savePreference(state);
  }

  void setDarkMode(bool value) {
    state = value;
    _savePreference(value);
  }
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(() {
  return DarkModeNotifier();
});
