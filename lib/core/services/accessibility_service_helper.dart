import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

/// Manages prompts for enabling the Android accessibility service,
/// which is required for app-lock detection to function.
class AccessibilityServiceHelper {
  static const platform = MethodChannel('com.stealthseal.app/applock');

  /// Shows a one-time accessibility permission dialog when the user
  /// locks an app for the first time.
  ///
  /// Skips the dialog if the service is already enabled or if the
  /// prompt was already shown during this lock action.
  static Future<void> requestAccessibilityServiceWhenLocking(
    BuildContext context,
  ) async {
    try {
      // Check if already enabled
      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled');

      if (isEnabled == true) {
        debugPrint('Accessibility service already enabled');
        return;
      }

      // Only prompt once per lock action
      final securityBox = Hive.box('securityBox');
      final alreadyPromptedOnLock =
          securityBox.get('accessibility_prompt_on_lock_shown',
              defaultValue: false) as bool;

      if (alreadyPromptedOnLock) {
        debugPrint('Accessibility lock prompt already shown, skipping');
        return;
      }

      debugPrint('Showing accessibility permission popup for app lock...');

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Enable Accessibility'),
            content: const Text(
              'For app locking to work, StealthSeal needs accessibility permission.\n\n'
              'Without it, the PIN screen won\'t show when you open locked apps.\n\n'
              'Go to Settings > Accessibility > StealthSeal and enable it.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Mark as shown but keep allowing reminders
                },
                child: const Text('Remind Me Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Open Android accessibility settings
                  _openAccessibilitySettings();
                  debugPrint(
                      'User confirmed - Opening accessibility settings');
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );

      // Mark as shown on lock action
      await securityBox.put('accessibility_prompt_on_lock_shown', true);
    } catch (error) {
      debugPrint('Accessibility lock prompt error: $error');
    }
  }

  /// Opens the Android accessibility settings page.
  static Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
      debugPrint('Opened accessibility settings');
    } catch (error) {
      debugPrint('Error opening accessibility settings: $error');
      // Silently fail - user can open manually
    }
  }
}
