import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

/// Helper class to manage accessibility service requests
class AccessibilityServiceHelper {
  static const platform = MethodChannel('com.stealthseal.app/applock');

  /// Show accessibility popup when user locks an app for the first time
  static Future<void> requestAccessibilityServiceWhenLocking(
    BuildContext context,
  ) async {
    try {
      // Check if already enabled
      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled');

      if (isEnabled == true) {
        debugPrint('✅ Accessibility service already enabled');
        return;
      }

      // Check if we already prompted when locking - only ask ONCE per lock action
      final box = Hive.box('securityBox');
      final alreadyPromptedOnLock =
          box.get('accessibility_prompt_on_lock_shown', defaultValue: false) as bool;
      
      if (alreadyPromptedOnLock) {
        debugPrint('ℹ️ Accessibility lock prompt already shown, skipping');
        return;
      }

      debugPrint('📱 Showing accessibility permission popup for app lock...');

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('⚠️ Enable Accessibility'),
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
                  debugPrint('✅ User confirmed - Opening accessibility settings');
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );

      // Mark as shown on lock action
      await box.put('accessibility_prompt_on_lock_shown', true);
    } catch (e) {
      debugPrint('❌ Accessibility lock prompt error: $e');
    }
  }

  /// Open Android accessibility settings
  static Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
      debugPrint('✅ Opened accessibility settings');
    } catch (e) {
      debugPrint('⚠️ Error opening accessibility settings: $e');
      // Silently fail - user can open manually
    }
  }
}
