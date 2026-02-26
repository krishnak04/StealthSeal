import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

enum AppThemeMode { dark, light, system }

class ThemeService {
  static const String _boxName = 'security';
  static const String _themeKey = 'themeMode';

  static final ValueNotifier<AppThemeMode> themeNotifier =
      ValueNotifier<AppThemeMode>(AppThemeMode.system);

  static Box _securityBox() => Hive.box(_boxName);

  static Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      await _securityBox().put(_themeKey, mode.toString());
      themeNotifier.value = mode;
      debugPrint('Theme mode set to: ${mode.toString()}');
    } catch (error) {
      debugPrint('Error setting theme mode: $error');
    }
  }

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

  static bool isDarkMode(BuildContext context) {
    final mode = getThemeMode();

    if (mode == AppThemeMode.dark) {
      return true;
    } else if (mode == AppThemeMode.light) {
      return false;
    } else {

      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

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

  static bool isDarkModeEnabled() {
    final mode = getThemeMode();
    return mode == AppThemeMode.dark;
  }

  static Future<void> enableDarkMode() async {
    await setThemeMode(AppThemeMode.dark);
  }

  static Future<void> disableDarkMode() async {
    await setThemeMode(AppThemeMode.light);
  }
}
