import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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
    _securityBox = Hive.box('securityBox');
    _loadSettings();
  }

  void _loadSettings() {
    _timeLockEnabled =
        _securityBox.get('nightLockEnabled', defaultValue: false);

    final startHour = _securityBox.get('nightStartHour', defaultValue: 22);
    final startMinute = _securityBox.get('nightStartMinute', defaultValue: 0);
    _startTime = TimeOfDay(hour: startHour, minute: startMinute);

    final endHour = _securityBox.get('nightEndHour', defaultValue: 6);
    final endMinute = _securityBox.get('nightEndMinute', defaultValue: 0);
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
      await _securityBox.put('nightStartHour', picked.hour);
      await _securityBox.put('nightStartMinute', picked.minute);
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
      await _securityBox.put('nightEndHour', picked.hour);
      await _securityBox.put('nightEndMinute', picked.minute);
    }
  }

  Future<void> _toggleTimeLock(bool value) async {
    setState(() {
      _timeLockEnabled = value;
    });
    await _securityBox.put('nightLockEnabled', value);
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable Time Lock Card
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ThemeConfig.borderColor(context),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(18),
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Automatically lock apps during specific hours',
                          style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _timeLockEnabled,
                      onChanged: _toggleTimeLock,
                      activeThumbColor: ThemeConfig.accentColor(context),
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: ThemeConfig.borderColor(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Time Settings Card
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ThemeConfig.borderColor(context),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lock Start Time
                    Text(
                      'Lock Start Time',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _timeLockEnabled
                          ? () => _selectStartTime(context)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeConfig.inputBackground(context),
                          border: Border.all(
                            color: ThemeConfig.borderColor(context),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 10,
                        ),
                        child: Text(
                          _formatTime(_startTime),
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Apps will lock at this time',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Lock End Time
                    Text(
                      'Lock End Time',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _timeLockEnabled
                          ? () => _selectEndTime(context)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeConfig.inputBackground(context),
                          border: Border.all(
                            color: ThemeConfig.borderColor(context),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 10,
                        ),
                        child: Text(
                          _formatTime(_endTime),
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Apps will unlock at this time',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),

                    // Active Period
                    Container(
                      margin: const EdgeInsets.only(top: 15),
                      decoration: BoxDecoration(
                        color:
                            ThemeConfig.accentColor(context).withOpacity(0.1),
                        border: Border.all(
                          color: ThemeConfig.accentColor(context),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: ThemeConfig.accentColor(context),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Active period: ${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
                            style: TextStyle(
                              color: ThemeConfig.accentColor(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
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
