import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/hive_keys.dart';

/// Determines whether the night-lock window is currently active.
///
/// Uses a configurable start/end time range stored in Hive.
/// When active, only the real PIN can unlock the app.
class TimeLockService {
  /// Checks if the current time falls within the night-lock window.
  ///
  /// Returns `true` if night lock is enabled and the current time
  /// is between the configured start and end times.
  /// Correctly handles midnight crossing (e.g., 10 PM to 6 AM).
  static bool isNightLockActive() {
    final securityBox = Hive.box('security');

    final bool isEnabled =
        securityBox.get(HiveKeys.nightLockEnabled, defaultValue: false);

    if (!isEnabled) return false;

    // --- Load configured lock window boundaries ---
    final int startHour =
        securityBox.get(HiveKeys.nightStartHour, defaultValue: 22);
    final int startMinute =
        securityBox.get(HiveKeys.nightStartMinute, defaultValue: 0);

    final int endHour =
        securityBox.get(HiveKeys.nightEndHour, defaultValue: 6);
    final int endMinute =
        securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0);

    // --- Convert to minutes since midnight for comparison ---
    final now = TimeOfDay.now();

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Handles midnight crossing (e.g., 10 PM to 6 AM)
    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes &&
          currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes ||
          currentMinutes <= endMinutes;
    }
  }
}
