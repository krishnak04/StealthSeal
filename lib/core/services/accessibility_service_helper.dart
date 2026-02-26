import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class AccessibilityServiceHelper {
  static const platform = MethodChannel('com.stealthseal.app/applock');

  static Future<void> requestAccessibilityServiceWhenLocking(
    BuildContext context,
  ) async {
    try {

      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled');

      if (isEnabled == true) {
        debugPrint('Accessibility service already enabled');
        return;
      }

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

                },
                child: const Text('Remind Me Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);

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

      await securityBox.put('accessibility_prompt_on_lock_shown', true);
    } catch (error) {
      debugPrint('Accessibility lock prompt error: $error');
    }
  }

  static Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
      debugPrint('Opened accessibility settings');
    } catch (error) {
      debugPrint('Error opening accessibility settings: $error');

    }
  }
}
