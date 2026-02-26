import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/hive_keys.dart';

class TimeLockScreen extends StatefulWidget {
  const TimeLockScreen({super.key});

  @override
  State<TimeLockScreen> createState() => _TimeLockScreenState();
}

class _TimeLockScreenState extends State<TimeLockScreen> {

  final securityBox = Hive.box('security');

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: securityBox.get(HiveKeys.nightStartHour, defaultValue: 22),
        minute: securityBox.get(HiveKeys.nightStartMinute, defaultValue: 0),
      ),
    );

    if (picked != null) {
      await securityBox.put(HiveKeys.nightStartHour, picked.hour);
      await securityBox.put(HiveKeys.nightStartMinute, picked.minute);
      setState(() {});
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: securityBox.get(HiveKeys.nightEndHour, defaultValue: 6),
        minute: securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0),
      ),
    );

    if (picked != null) {
      await securityBox.put(HiveKeys.nightEndHour, picked.hour);
      await securityBox.put(HiveKeys.nightEndMinute, picked.minute);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled =
        securityBox.get(HiveKeys.nightLockEnabled, defaultValue: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Time-Based Lock')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Night Lock'),
            value: isEnabled,
            onChanged: (value) async {
              await securityBox.put(HiveKeys.nightLockEnabled, value);
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Start Time'),
            subtitle: Text(
              '${securityBox.get(HiveKeys.nightStartHour, defaultValue: 22).toString().padLeft(2, '0')}:'
              '${securityBox.get(HiveKeys.nightStartMinute, defaultValue: 0).toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: isEnabled ? _pickStartTime : null,
          ),
          ListTile(
            title: const Text('End Time'),
            subtitle: Text(
              '${securityBox.get(HiveKeys.nightEndHour, defaultValue: 6).toString().padLeft(2, '0')}:'
              '${securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0).toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: isEnabled ? _pickEndTime : null,
          ),
        ],
      ),
    );
  }
}
