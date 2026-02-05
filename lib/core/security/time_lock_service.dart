import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/hive_keys.dart';

class TimeLockService {
  static bool isNightLockActive() {
    final box = Hive.box('security');

    final bool enabled =
        box.get(HiveKeys.nightLockEnabled, defaultValue: false);

    if (!enabled) return false;

    final int startHour =
        box.get(HiveKeys.nightStartHour, defaultValue: 22);
    final int startMinute =
        box.get(HiveKeys.nightStartMinute, defaultValue: 0);

    final int endHour =
        box.get(HiveKeys.nightEndHour, defaultValue: 6);
    final int endMinute =
        box.get(HiveKeys.nightEndMinute, defaultValue: 0);

    final now = TimeOfDay.now();

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Handles midnight crossing (10 PM → 6 AM)
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }
}
