import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';
import '../../utils/hive_keys.dart';

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
    _timeLockEnabled =
        _securityBox.get(HiveKeys.nightLockEnabled, defaultValue: false);

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
      await _syncTimeLocksToNative();
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
      await _syncTimeLocksToNative();
    }
  }

  Future<void> _toggleTimeLock(bool value) async {
    setState(() {
      _timeLockEnabled = value;
    });
    await _securityBox.put(HiveKeys.nightLockEnabled, value);
    await _syncTimeLocksToNative();
  }

  Future<void> _setQuickLock(int minutes) async {
    final now = DateTime.now();
    final endTime = now.add(Duration(minutes: minutes));
    
    setState(() {
      _startTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _endTime = TimeOfDay(hour: endTime.hour, minute: endTime.minute);
      _timeLockEnabled = true;
    });

    await _securityBox.put(HiveKeys.nightStartHour, now.hour);
    await _securityBox.put(HiveKeys.nightStartMinute, now.minute);
    await _securityBox.put(HiveKeys.nightEndHour, endTime.hour);
    await _securityBox.put(HiveKeys.nightEndMinute, endTime.minute);
    await _securityBox.put(HiveKeys.nightLockEnabled, true);

    await _syncTimeLocksToNative();
    
    debugPrint('🔒 Quick lock set:');
    debugPrint('   Start: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    debugPrint('   End: ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}');
    debugPrint('   Duration: $minutes minutes');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 App locked for $minutes minutes until ${_formatTime(_endTime)}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _syncTimeLocksToNative() async {
    try {
      
      final securityBox = Hive.box('securityBox');
      final realPin = securityBox.get('realPin', defaultValue: '') as String;
      final decoyPin = securityBox.get('decoyPin', defaultValue: '') as String;
      final unlockPattern = securityBox.get('unlockPattern', defaultValue: '4-digit') as String;

      final locationLockEnabled = securityBox.get('locationLockEnabled', defaultValue: false) as bool;
      final trustedLat = securityBox.get('trustedLat', defaultValue: 0.0) as double;
      final trustedLng = securityBox.get('trustedLng', defaultValue: 0.0) as double;
      final trustedRadius = securityBox.get('trustedRadius', defaultValue: 200.0) as double;
      
      const platform = MethodChannel('com.stealthseal.app/applock');
      await platform.invokeMethod('cachePins', {
        'real_pin': realPin,
        'decoy_pin': decoyPin,
        'unlock_pattern': unlockPattern,
        'location_lock_enabled': locationLockEnabled,
        'trusted_lat': trustedLat,
        'trusted_lng': trustedLng,
        'trusted_radius': trustedRadius,
        'night_lock_enabled': _timeLockEnabled,
        'night_start_hour': _startTime.hour,
        'night_start_minute': _startTime.minute,
        'night_end_hour': _endTime.hour,
        'night_end_minute': _endTime.minute,
      });
      debugPrint('✅ Time lock settings synced to native');
      debugPrint('   Time Lock: $_timeLockEnabled (${_startTime.hour}:${_startTime.minute} - ${_endTime.hour}:${_endTime.minute})');
      debugPrint('   Location Lock: $locationLockEnabled');
    } catch (error) {
      debugPrint('Warning: Failed to sync time lock settings to native: $error');
    }
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

                    Container(
                      margin: const EdgeInsets.only(top: 15),
                      decoration: BoxDecoration(
                        color:
                            ThemeConfig.accentColor(context).withValues(alpha: 0.1),
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
              const SizedBox(height: 20),

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
                    Text(
                      'Quick Lock',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lock app for a specific duration',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildQuickLockButton(context, '4 min', 4),
                        _buildQuickLockButton(context, '5 min', 5),
                        _buildQuickLockButton(context, '10 min', 10),
                        _buildQuickLockButton(context, '30 min', 30),
                        _buildQuickLockButton(context, '1 hour', 60),
                      ],
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

  Widget _buildQuickLockButton(BuildContext context, String label, int minutes) {
    return ElevatedButton(
      onPressed: () => _setQuickLock(minutes),
      style: ElevatedButton.styleFrom(
        backgroundColor: ThemeConfig.accentColor(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
