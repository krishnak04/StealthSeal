import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class to manage accessibility service requests
class AccessibilityServiceHelper {
  static const platform = MethodChannel('com.stealthseal.app/applock');

  /// Request user to enable accessibility service when locking an app
  /// Only shows once per installation (uses SharedPreferences flag)
  static Future<void> requestAccessibilityServiceWhenLocking(
    BuildContext context,
  ) async {
    try {
      // Check if already shown
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown =
          prefs.getBool('accessibility_requested_for_app_lock') ?? false;

      if (alreadyShown) {
        return; // Already shown, don't show again
      }

      // Check if already enabled
      final isEnabled = await _isAccessibilityServiceEnabled();
      if (isEnabled) {
        // Already enabled, mark as shown and return
        await prefs.setBool('accessibility_requested_for_app_lock', true);
        return;
      }

      // Show accessibility service request dialog
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Enable Accessibility Service'),
            content: const Text(
              'To protect your apps, StealthSeal needs accessibility permission. '
              'This allows the app to detect when you open locked apps and show the PIN screen.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Open accessibility settings
                  _openAccessibilitySettings();

                  // Mark as shown (user can now go enable it)
                  prefs.setBool('accessibility_requested_for_app_lock', true);

                  debugPrint(
                      '✅ User confirmed - Opening accessibility settings');
                },
                child: const Text('Enable'),
              ),
            ],
          );
        },
      );

      // Mark as shown
      await prefs.setBool('accessibility_requested_for_app_lock', true);
    } catch (e) {
      debugPrint(
          '❌ Accessibility request error: $e');
    }
  }

  /// Check if accessibility service is enabled
  static Future<bool> _isAccessibilityServiceEnabled() async {
    try {
      final result = await platform.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking accessibility service: $e');
      return false;
    }
  }

  /// Open accessibility settings screen
  static Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error opening accessibility settings: $e');
    }
  }
}
