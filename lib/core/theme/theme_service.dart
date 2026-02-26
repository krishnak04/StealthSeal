import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

/// Available theme modes for the application.
enum AppThemeMode { dark, light, system }

/// Persists and exposes the user's chosen theme mode via Hive,
/// with a [ValueNotifier] so widgets can react to changes.
class ThemeService {
  static const String _boxName = 'security';
  static const String _themeKey = 'themeMode';

  /// Notifies listeners whenever the theme mode changes.
  static final ValueNotifier<AppThemeMode> themeNotifier =
      ValueNotifier<AppThemeMode>(AppThemeMode.system);

  /// Returns the Hive security box.
  static Box _securityBox() => Hive.box(_boxName);

  // ──────────────────────────────────────────────
  //  Getters & Setters
  // ──────────────────────────────────────────────

  /// Persists the given [mode] and notifies listeners.
  static Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      await _securityBox().put(_themeKey, mode.toString());
      themeNotifier.value = mode;
      debugPrint('Theme mode set to: ${mode.toString()}');
    } catch (error) {
      debugPrint('Error setting theme mode: $error');
    }
  }

  /// Reads the persisted theme mode from Hive.
  static AppThemeMode getThemeMode() {
    try {
      final modeString =
          _securityBox().get(_themeKey, defaultValue: 'AppThemeMode.system');
      if (modeString == 'AppThemeMode.dark') {
        return AppThemeMode.dark;
      } else if (modeString == 'AppThemeMode.light') {
        return AppThemeMode.light;
      } else {
        return AppThemeMode.system;
      }
    } catch (error) {
      debugPrint('Error getting theme mode: $error');
      return AppThemeMode.system;
    }
  }

  // ──────────────────────────────────────────────
  //  Convenience Helpers
  // ──────────────────────────────────────────────

  /// Returns `true` if dark mode should be used, respecting the
  /// system brightness when the mode is set to [AppThemeMode.system].
  static bool isDarkMode(BuildContext context) {
    final mode = getThemeMode();

    if (mode == AppThemeMode.dark) {
      return true;
    } else if (mode == AppThemeMode.light) {
      return false;
    } else {
      // System default
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

  /// Cycles through dark → light → system → dark.
  static Future<void> toggleThemeMode() async {
    final currentMode = getThemeMode();
    late AppThemeMode nextMode;

    if (currentMode == AppThemeMode.dark) {
      nextMode = AppThemeMode.light;
    } else if (currentMode == AppThemeMode.light) {
      nextMode = AppThemeMode.system;
    } else {
      nextMode = AppThemeMode.dark;
    }

    await setThemeMode(nextMode);
  }

  /// Returns a human-readable label for the current theme mode.
  static String getThemeDescription() {
    final mode = getThemeMode();
    switch (mode) {
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  // ──────────────────────────────────────────────
  //  Legacy API (backward compatibility)
  // ──────────────────────────────────────────────

  /// Legacy method for backward compatibility.
  static bool isDarkModeEnabled() {
    final mode = getThemeMode();
    return mode == AppThemeMode.dark;
  }

  /// Legacy method for backward compatibility.
  static Future<void> enableDarkMode() async {
    await setThemeMode(AppThemeMode.dark);
  }

  /// Legacy method for backward compatibility.
  static Future<void> disableDarkMode() async {
    await setThemeMode(AppThemeMode.light);
  }
}

