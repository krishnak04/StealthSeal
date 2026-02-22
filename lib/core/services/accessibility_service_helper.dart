import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class AccessibilityServiceHelper {
  static const MethodChannel _channel =
      MethodChannel('com.stealthseal.app/applock');

  /// Show accessibility service enable dialog when user locks an app
  /// Returns true if user enabled it, false otherwise
  static Future<bool> requestAccessibilityServiceWhenLocking(
      BuildContext context) async {
    try {
      // Check if already enabled
      final isEnabled =
          await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');

      if (isEnabled == true) {
        debugPrint('✅ Accessibility service already enabled, skipping prompt');
        return true;
      }

      // Check if we already prompted before — only ask ONCE
      final box = Hive.box('securityBox');
      final alreadyPrompted =
          box.get('accessibility_prompt_shown', defaultValue: false) as bool;
      
      if (alreadyPrompted) {
        debugPrint('ℹ️ Accessibility prompt already shown before, skipping');
        return false;
      }

      debugPrint(
          '📱 User locked app - Requesting accessibility service (first time)...');

      // Show popup dialog
      bool userConfirmed = false;
      
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.security, color: Colors.cyan),
                  const SizedBox(width: 8),
                  const Text(
                    'Enable Accessibility Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'StealthSeal requires accessibility service to automatically show the lock screen when you open a protected app.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyan, width: 1),
                    ),
                    child: const Text(
                      '✓ Detects when locked apps are opened\n'
                      '✓ Shows PIN lock screen automatically\n'
                      '✓ Works in the background',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You will be redirected to Settings to enable it.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    debugPrint('❌ User dismissed accessibility dialog');
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Skip for Now',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    debugPrint('✅ User accepted - Opening accessibility settings');
                    userConfirmed = true;
                    Navigator.pop(dialogContext);
                    _channel.invokeMethod('requestAccessibilityService');
                  },
                  child: const Text(
                    'Enable Now',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }

      // Mark as prompted so we never show again
      await box.put('accessibility_prompt_shown', true);
      
      return userConfirmed;
    } catch (e) {
      debugPrint('❌ Accessibility request error: $e');
      return false;
    }
  }
}
