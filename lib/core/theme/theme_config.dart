import 'package:flutter/material.dart';

/// Centralised colour palette that adapts to light and dark themes.
///
/// All methods accept a [BuildContext] and resolve colours based
/// on the current [Brightness].
class ThemeConfig {
  // ──────────────────────────────────────────────
  //  Backgrounds
  // ──────────────────────────────────────────────

  /// Scaffold / page background.
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF0A0E27);
  }

  /// Card and elevated-surface background.
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[50]!
        : const Color(0xFF1A1F3A);
  }

  /// Input field fill colour.
  static Color inputBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[50]!
        : const Color(0xFF0A0E27);
  }

  /// Card widget colour.
  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1A1F3A);
  }

  /// AppBar background.
  static Color appBarBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF0A0E27);
  }

  // ──────────────────────────────────────────────
  //  Borders & Dividers
  // ──────────────────────────────────────────────

  /// General border colour.
  static Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[300]!
        : const Color(0xFF2A2F4A);
  }

  /// Divider / separator colour.
  static Color dividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[300]!
        : const Color(0xFF2A2F4A);
  }

  // ──────────────────────────────────────────────
  //  Text
  // ──────────────────────────────────────────────

  /// Primary text colour.
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black87
        : Colors.white;
  }

  /// Secondary / muted text colour.
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[600]!
        : const Color(0xFF8B8FA3);
  }

  // ──────────────────────────────────────────────
  //  Accent & Interactive
  // ──────────────────────────────────────────────

  /// Primary accent / brand colour.
  static Color accentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue
        : const Color(0xFF6366F1);
  }

  /// Active colour for switches and toggles.
  static Color switchActiveColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue
        : const Color(0xFF6366F1);
  }

  // ──────────────────────────────────────────────
  //  Semantic Colours
  // ──────────────────────────────────────────────

  /// Error / destructive-action colour.
  static Color errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.red[600]!
        : Colors.red[400]!;
  }

  /// Success / confirmation colour.
  static Color successColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.green[600]!
        : Colors.green[400]!;
  }

  /// Informational foreground colour.
  static Color infoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue[300]!
        : const Color(0xFF5FA3D0);
  }

  /// Informational background colour.
  static Color infoBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue[50]!
        : const Color(0xFF1B2F4D);
  }
}
