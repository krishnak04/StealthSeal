import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/theme_config.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() =>
      _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState extends State<PermissionsSettingsScreen> {

  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _storageStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _photosStatus = PermissionStatus.denied;
  PermissionStatus _accessibilityStatus = PermissionStatus.denied;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final camera = await Permission.camera.status;
    final storage = await Permission.storage.status;
    final location = await Permission.location.status;
    final photos = await Permission.photos.status;

    final accessibility = await Permission.sensors.status;

    if (mounted) {
      setState(() {
        _cameraStatus = camera;
        _storageStatus = storage;
        _locationStatus = location;
        _photosStatus = photos;
        _accessibilityStatus = accessibility;
        _isInitializing = false;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _cameraStatus = status);
    _showPermissionResult(status, 'Camera');
  }

  Future<void> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    setState(() => _storageStatus = status);
    _showPermissionResult(status, 'Storage');
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() => _locationStatus = status);
    _showPermissionResult(status, 'Location');
  }

  Future<void> _requestPhotosPermission() async {
    final status = await Permission.photos.request();
    setState(() => _photosStatus = status);
    _showPermissionResult(status, 'Photos');
  }

  Future<void> _requestAccessibilityPermission() async {

    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() => _accessibilityStatus = status);
    _showPermissionResult(status, 'Accessibility');
  }

  void _showPermissionResult(PermissionStatus status, String permission) {
    String message = '';
    if (status.isGranted) {
      message = '$permission permission granted';
    } else if (status.isDenied) {
      message = '$permission permission denied';
    } else if (status.isPermanentlyDenied) {
      message = '$permission permission denied. Open settings to allow.';
      openAppSettings();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: status.isGranted
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFF6B5B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getStatusText(PermissionStatus status) {
    if (status.isGranted) {
      return 'Granted';
    } else if (status.isDenied) {
      return 'Grant';
    } else if (status.isPermanentlyDenied) {
      return 'Settings';
    }
    return 'Unknown';
  }

  bool _isGranted(PermissionStatus status) {
    return status.isGranted;
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
          'Permissions',
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPermissionCard(
                icon: Icons.camera_alt,
                iconColor: const Color(0xFFFF6B5B),
                title: 'Camera',
                description: 'Required for intruder detection photos',
                status: _cameraStatus,
                onTap: _requestCameraPermission,
              ),
              const SizedBox(height: 12),
              _buildPermissionCard(
                icon: Icons.folder,
                iconColor: ThemeConfig.accentColor(context),
                title: 'Storage',
                description: 'Store intruder photos and app settings',
                status: _storageStatus,
                onTap: _requestStoragePermission,
              ),
              const SizedBox(height: 12),
              _buildPermissionCard(
                icon: Icons.location_on,
                iconColor: const Color(0xFF4CAF50),
                title: 'Location',
                description: 'Enable location-based locking',
                status: _locationStatus,
                onTap: _requestLocationPermission,
              ),
              const SizedBox(height: 12),
              _buildPermissionCard(
                icon: Icons.photo_library,
                iconColor: ThemeConfig.accentColor(context),
                title: 'Photos',
                description: 'Access and store intruder photos',
                status: _photosStatus,
                onTap: _requestPhotosPermission,
              ),
              const SizedBox(height: 12),
              _buildPermissionCard(
                icon: Icons.accessibility,
                iconColor: const Color(0xFF4CAF50),
                title: 'Accessibility',
                description: 'Required for app locking functionality',
                status: _accessibilityStatus,
                onTap: _requestAccessibilityPermission,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isGranted(status) ? null : onTap,
      child: Container(
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
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: ThemeConfig.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_isGranted(status))
              Text(
                _getStatusText(status),
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.accentColor(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  _getStatusText(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
