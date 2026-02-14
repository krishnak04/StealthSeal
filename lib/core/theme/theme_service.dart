import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

enum AppThemeMode { dark, light, system }

class ThemeService {
  static const String _boxName = 'security';
  static const String _themeKey = 'themeMode';
  
  /// ValueNotifier to notify listeners when theme changes
  static final ValueNotifier<AppThemeMode> themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.system);

  /// Get or create the security box
  static Box _box() => Hive.box(_boxName);

  /// Set theme mode
  static Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      await _box().put(_themeKey, mode.toString());
      themeNotifier.value = mode; // Notify listeners
      debugPrint('✅ Theme mode set to: ${mode.toString()}');
    } catch (e) {
      debugPrint('❌ Error setting theme mode: $e');
    }
  }

  /// Get current theme mode
  static AppThemeMode getThemeMode() {
    try {
      final modeString = _box().get(_themeKey, defaultValue: 'AppThemeMode.system');
      if (modeString == 'AppThemeMode.dark') {
        return AppThemeMode.dark;
      } else if (modeString == 'AppThemeMode.light') {
        return AppThemeMode.light;
      } else {
        return AppThemeMode.system;
      }
    } catch (e) {
      debugPrint('❌ Error getting theme mode: $e');
      return AppThemeMode.system; // Default to system
    }
  }

  /// Check if dark mode should be used
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

  /// Toggle between dark, light, and system modes
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

  /// Get theme description text
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

  /// Legacy method for backward compatibility
  static bool isDarkModeEnabled() {
    final mode = getThemeMode();
    return mode == AppThemeMode.dark;
  }

  /// Legacy method for backward compatibility
  static Future<void> enableDarkMode() async {
    await setThemeMode(AppThemeMode.dark);
  }

  /// Legacy method for backward compatibility
  static Future<void> disableDarkMode() async {
    await setThemeMode(AppThemeMode.light);
  }
}

