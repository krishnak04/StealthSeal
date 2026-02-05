import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/hive_keys.dart';

class TimeLockScreen extends StatefulWidget {
  const TimeLockScreen({super.key});

  @override
  State<TimeLockScreen> createState() => _TimeLockScreenState();
}

class _TimeLockScreenState extends State<TimeLockScreen> {
  final box = Hive.box('security');

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: box.get(HiveKeys.nightStartHour, defaultValue: 22),
        minute: box.get(HiveKeys.nightStartMinute, defaultValue: 0),
      ),
    );

    if (picked != null) {
      await box.put(HiveKeys.nightStartHour, picked.hour);
      await box.put(HiveKeys.nightStartMinute, picked.minute);
      setState(() {});
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: box.get(HiveKeys.nightEndHour, defaultValue: 6),
        minute: box.get(HiveKeys.nightEndMinute, defaultValue: 0),
      ),
    );

    if (picked != null) {
      await box.put(HiveKeys.nightEndHour, picked.hour);
      await box.put(HiveKeys.nightEndMinute, picked.minute);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = box.get(HiveKeys.nightLockEnabled, defaultValue: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Time-Based Lock')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Night Lock'),
            value: enabled,
            onChanged: (value) async {
              await box.put(HiveKeys.nightLockEnabled, value);
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Start Time'),
            subtitle: Text(
              '${box.get(HiveKeys.nightStartHour, defaultValue: 22).toString().padLeft(2, '0')}:'
              '${box.get(HiveKeys.nightStartMinute, defaultValue: 0).toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: enabled ? _pickStartTime : null,
          ),
          ListTile(
            title: const Text('End Time'),
            subtitle: Text(
              '${box.get(HiveKeys.nightEndHour, defaultValue: 6).toString().padLeft(2, '0')}:'
              '${box.get(HiveKeys.nightEndMinute, defaultValue: 0).toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: enabled ? _pickEndTime : null,
          ),
        ],
      ),
    );
  }
}