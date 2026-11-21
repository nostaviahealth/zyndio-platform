import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored appearance choice: `system`, `light` or `dark`.
const String themeModePrefsKey = 'zyndio_theme_mode';

/// The patient's appearance choice (Settings → Appearance). Defaults to the
/// phone's own light/dark setting (TC-025 C4); the client walkthrough
/// (19 Nov 2026) asked for a manual light or dark choice on top of that.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = _decode(prefs.getString(themeModePrefsKey));
      if (stored != state) state = stored;
    } catch (_) {
      // No stored choice: keep following the phone.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModePrefsKey, mode.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  static ThemeMode _decode(String? value) => ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.system,
      );
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
