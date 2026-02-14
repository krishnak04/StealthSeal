import 'package:flutter/material.dart';

/// Theme configuration helper for consistent light/dark mode colors
class ThemeConfig {
  /// Get background color based on theme
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF0A0E27);
  }

  /// Get surface color (card background)
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[50]!
        : const Color(0xFF1A1F3A);
  }

  /// Get border color
  static Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[300]!
        : const Color(0xFF2A2F4A);
  }

  /// Get text color (primary)
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black87
        : Colors.white;
  }

  /// Get text color (secondary)
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[600]!
        : const Color(0xFF8B8FA3);
  }

  /// Get accent color
  static Color accentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue
        : const Color(0xFF6366F1);
  }

  /// Get input field background
  static Color inputBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[50]!
        : const Color(0xFF0A0E27);
  }

  /// Get card color
  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1A1F3A);
  }

  /// Get AppBar background
  static Color appBarBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF0A0E27);
  }

  /// Get switch/toggle active color
  static Color switchActiveColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue
        : const Color(0xFF6366F1);
  }

  /// Get error/warning color
  static Color errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.red[600]!
        : Colors.red[400]!;
  }

  /// Get success color
  static Color successColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.green[600]!
        : Colors.green[400]!;
  }

  /// Get info/info color (for status displays)
  static Color infoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue[300]!
        : const Color(0xFF5FA3D0);
  }

  /// Get info background (for status displays)
  static Color infoBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue[50]!
        : const Color(0xFF1B2F4D);
  }

  /// Get divider color
  static Color dividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[300]!
        : const Color(0xFF2A2F4A);
  }
}
