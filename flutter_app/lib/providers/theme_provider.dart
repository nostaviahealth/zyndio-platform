import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeKey = 'isImageTheme';

/// Provider to manage the theme state (Default vs Image Background)
class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadTheme();
    return true; // Default to Immersive (true)
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_themeKey) ?? true; // Default to Immersive (true)
  }

  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
  }

  void toggleTheme() {
    state = !state;
    _saveTheme(state);
  }
  
  void setLink(bool value) {
    state = value;
    _saveTheme(value);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(() {
  return ThemeNotifier();
});
