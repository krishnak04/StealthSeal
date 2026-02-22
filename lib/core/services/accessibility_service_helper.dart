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
                  Icon(Icons.verified_user, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Permission Required',
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
                  // Accessibility Service permission
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Accessibility Service',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            const Text(
                              'Detect when locked apps are opened',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: true,
                        onChanged: null,
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Display over other apps permission
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Display over other apps',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            const Text(
                              'Show PIN lock screen on top',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: true,
                        onChanged: null,
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    debugPrint('✅ User confirmed - Opening accessibility settings');
                    userConfirmed = true;
                    Navigator.pop(dialogContext);
                    _channel.invokeMethod('requestAccessibilityService');
                  },
                  icon: const Icon(Icons.settings, size: 20, color: Colors.white),
                  label: const Text(
                    'Go to set',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
