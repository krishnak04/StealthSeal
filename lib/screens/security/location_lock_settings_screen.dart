import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import '../../core/security/location_lock_service.dart';
import '../../core/theme/theme_config.dart';

class LocationLockSettingsScreen extends StatefulWidget {
  const LocationLockSettingsScreen({super.key});

  @override
  State<LocationLockSettingsScreen> createState() =>
      _LocationLockSettingsScreenState();
}

class _LocationLockSettingsScreenState
    extends State<LocationLockSettingsScreen> {
  late Box _securityBox;
  late bool _locationLockEnabled;
  late double _trustedLat;
  late double _trustedLng;
  late double _trustedRadius;
  late TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    _securityBox = Hive.box('securityBox');
    _loadSettings();
  }

  void _loadSettings() {
    _locationLockEnabled =
        _securityBox.get('locationLockEnabled', defaultValue: false);
    _trustedLat = _securityBox.get('trustedLat', defaultValue: 0.0);
    _trustedLng = _securityBox.get('trustedLng', defaultValue: 0.0);
    _trustedRadius = _securityBox.get('trustedRadius', defaultValue: 523.0);
    _radiusController =
        TextEditingController(text: _trustedRadius.toStringAsFixed(0));
  }

  void _toggleLocationLock(bool value) {
    setState(() => _locationLockEnabled = value);
    if (value) {
      LocationLockService.setTrustedLocation(
        latitude: _trustedLat,
        longitude: _trustedLng,
        radius: _trustedRadius,
      );
    } else {
      LocationLockService.disable();
    }
  }

  Future<void> _setCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _trustedLat = position.latitude;
        _trustedLng = position.longitude;
      });

      _securityBox.put('trustedLat', _trustedLat);
      _securityBox.put('trustedLng', _trustedLng);

      if (_locationLockEnabled) {
        LocationLockService.setTrustedLocation(
          latitude: _trustedLat,
          longitude: _trustedLng,
          radius: _trustedRadius,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Safe location updated successfully'),
            backgroundColor: const Color(0xFF00BCD4),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _updateRadius() {
    final value = double.tryParse(_radiusController.text) ?? _trustedRadius;
    setState(() => _trustedRadius = value);

    _securityBox.put('trustedRadius', _trustedRadius);
    if (_locationLockEnabled) {
      LocationLockService.setTrustedLocation(
        latitude: _trustedLat,
        longitude: _trustedLng,
        radius: _trustedRadius,
      );
    }
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeConfig.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Location-Based Locks',
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable Location Lock Toggle
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
                          'Enable Location Lock',
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lock apps when you leave a safe location',
                          style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _locationLockEnabled,
                      onChanged: _toggleLocationLock,
                      activeThumbColor: ThemeConfig.accentColor(context),
                      inactiveThumbColor: ThemeConfig.borderColor(context),
                      inactiveTrackColor: ThemeConfig.surfaceColor(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Map View Section
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.borderColor(context),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 50,
                      color: ThemeConfig.accentColor(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Map View',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_trustedLat.toStringAsFixed(4)}, Lng: ${_trustedLng.toStringAsFixed(4)}',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Safe Zone Radius
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
                      'Safe Zone Radius (meters)',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateRadius(),
                      enabled: _locationLockEnabled,
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ThemeConfig.inputBackground(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: ThemeConfig.borderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: ThemeConfig.borderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: ThemeConfig.accentColor(context),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Set Current Location Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.accentColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _locationLockEnabled ? _setCurrentLocation : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: _locationLockEnabled
                            ? Colors.white
                            : ThemeConfig.textSecondary(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Set Current Location',
                        style: TextStyle(
                          color: _locationLockEnabled
                              ? Colors.white
                              : ThemeConfig.textSecondary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info Box
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.accentColor(context).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: ThemeConfig.accentColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Apps will lock when you\'re ${_trustedRadius.toStringAsFixed(0)}m away from safe location',
                        style: TextStyle(
                          color: ThemeConfig.accentColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
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
