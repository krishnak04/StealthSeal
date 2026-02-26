import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/hive_keys.dart';

class TimeLockService {
  static bool isNightLockActive() {
    final securityBox = Hive.box('security');

    final bool isEnabled =
        securityBox.get(HiveKeys.nightLockEnabled, defaultValue: false);

    if (!isEnabled) return false;

    final int startHour =
        securityBox.get(HiveKeys.nightStartHour, defaultValue: 22);
    final int startMinute =
        securityBox.get(HiveKeys.nightStartMinute, defaultValue: 0);

    final int endHour =
        securityBox.get(HiveKeys.nightEndHour, defaultValue: 6);
    final int endMinute =
        securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0);

    final now = TimeOfDay.now();

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes &&
          currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes ||
          currentMinutes <= endMinutes;
    }
  }
}
