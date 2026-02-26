import 'package:flutter/material.dart';

class ThemeConfig {
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF0A0E27);
  }

  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[50]!
        : const Color(0xFF1A1F3A);
  }

  static Color inputBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[50]!
        : const Color(0xFF0A0E27);
  }

  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1A1F3A);
  }

  static Color appBarBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF0A0E27);
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[300]!
        : const Color(0xFF2A2F4A);
  }

  static Color dividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[300]!
        : const Color(0xFF2A2F4A);
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black87
        : Colors.white;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.grey[600]!
        : const Color(0xFF8B8FA3);
  }

  static Color accentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue
        : const Color(0xFF6366F1);
  }

  static Color switchActiveColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue
        : const Color(0xFF6366F1);
  }

  static Color errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.red[600]!
        : Colors.red[400]!;
  }

  static Color successColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.green[600]!
        : Colors.green[400]!;
  }

  static Color infoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue[300]!
        : const Color(0xFF5FA3D0);
  }

  static Color infoBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.blue[50]!
        : const Color(0xFF1B2F4D);
  }
}
