import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/hive_keys.dart';
import '../../core/theme/theme_config.dart';

class TimeLockSettingsScreen extends StatefulWidget {
  const TimeLockSettingsScreen({super.key});

  @override
  State<TimeLockSettingsScreen> createState() => _TimeLockSettingsScreenState();
}

class _TimeLockSettingsScreenState extends State<TimeLockSettingsScreen> {
  late Box _securityBox;
  late bool _timeLockEnabled;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _securityBox = Hive.box('security');
    _loadSettings();
  }

  void _loadSettings() {
    _timeLockEnabled = _securityBox.get(HiveKeys.nightLockEnabled, defaultValue: false);
    
    final startHour = _securityBox.get(HiveKeys.nightStartHour, defaultValue: 22);
    final startMinute = _securityBox.get(HiveKeys.nightStartMinute, defaultValue: 0);
    _startTime = TimeOfDay(hour: startHour, minute: startMinute);

    final endHour = _securityBox.get(HiveKeys.nightEndHour, defaultValue: 6);
    final endMinute = _securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0);
    _endTime = TimeOfDay(hour: endHour, minute: endMinute);
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
      await _securityBox.put(HiveKeys.nightStartHour, picked.hour);
      await _securityBox.put(HiveKeys.nightStartMinute, picked.minute);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
      await _securityBox.put(HiveKeys.nightEndHour, picked.hour);
      await _securityBox.put(HiveKeys.nightEndMinute, picked.minute);
    }
  }

  Future<void> _toggleTimeLock(bool value) async {
    setState(() {
      _timeLockEnabled = value;
    });
    await _securityBox.put(HiveKeys.nightLockEnabled, value);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeConfig.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Time-Based Locks',
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable Time Lock Toggle
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.borderColor(context),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Time Lock',
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automatically lock apps during specific hours',
                          style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _timeLockEnabled,
                        onChanged: _toggleTimeLock,
                        activeColor: ThemeConfig.accentColor(context),
                        inactiveThumbColor: Theme.of(context).brightness == Brightness.light 
                            ? Colors.grey[400]
                            : const Color(0xFF4A4F6B),
                        inactiveTrackColor: ThemeConfig.borderColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Lock Start Time
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.borderColor(context),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lock Start Time',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _timeLockEnabled ? () => _selectStartTime(context) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeConfig.inputBackground(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ThemeConfig.borderColor(context),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        child: Text(
                          _formatTime(_startTime),
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apps will lock at this time',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lock End Time
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.borderColor(context),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lock End Time',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _timeLockEnabled ? () => _selectEndTime(context) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeConfig.inputBackground(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ThemeConfig.borderColor(context),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        child: Text(
                          _formatTime(_endTime),
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apps will unlock at this time',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Active Period Status
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.infoBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.infoColor(context).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: ThemeConfig.infoColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Active period: ${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
                      style: TextStyle(
                        color: ThemeConfig.infoColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
