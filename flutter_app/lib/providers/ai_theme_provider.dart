import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AIThemeMode {
  classic, // Blue/Cyan (Zyndio Intelligence)
  siri,    // Orange/Purple/Pink (Radiance)
}

class AIThemeNotifier extends Notifier<AIThemeMode> {
  @override
  AIThemeMode build() {
    // Load preference asynchronously after build
    _loadTheme();
    return AIThemeMode.siri; // Default
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('ai_theme');
    if (savedTheme == 'classic') {
      state = AIThemeMode.classic;
    } else {
      state = AIThemeMode.siri;
    }
  }

  Future<void> toggleTheme(AIThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_theme', mode == AIThemeMode.classic ? 'classic' : 'siri');
  }
}

final aiThemeProvider = NotifierProvider<AIThemeNotifier, AIThemeMode>(() {
  return AIThemeNotifier();
});
