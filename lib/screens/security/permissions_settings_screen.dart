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
  late PermissionStatus _cameraStatus;
  late PermissionStatus _storageStatus;
  late PermissionStatus _locationStatus;
  late PermissionStatus _photosStatus;

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

    setState(() {
      _cameraStatus = camera;
      _storageStatus = storage;
      _locationStatus = location;
      _photosStatus = photos;
    });
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

  void _showPermissionResult(PermissionStatus status, String permission) {
    String message = '';
    if (status.isGranted) {
      message = '$permission permission granted';
    } else if (status.isDenied) {
      message = '$permission permission denied';
    } else if (status.isPermanentlyDenied) {
      message = '$permission permission denied. Open settings to allow.';
    }

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Camera Permission
              _buildPermissionCard(
                icon: Icons.camera_alt,
                iconColor: const Color(0xFFFF6B5B),
                title: 'Camera',
                description: 'Required for intruder detection photos',
                status: _cameraStatus,
                onTap: _requestCameraPermission,
              ),
              const SizedBox(height: 12),

              // Storage Permission
              _buildPermissionCard(
                icon: Icons.folder,
                iconColor: ThemeConfig.accentColor(context),
                title: 'Storage',
                description: 'Store intruder photos and app settings',
                status: _storageStatus,
                onTap: _requestStoragePermission,
              ),
              const SizedBox(height: 12),

              // Location Permission
              _buildPermissionCard(
                icon: Icons.location_on,
                iconColor: const Color(0xFF4CAF50),
                title: 'Location',
                description: 'Enable location-based locking',
                status: _locationStatus,
                onTap: _requestLocationPermission,
              ),
              const SizedBox(height: 12),

              // Photos Permission
              _buildPermissionCard(
                icon: Icons.photo_library,
                iconColor: ThemeConfig.accentColor(context),
                title: 'Photos',
                description: 'Access and store intruder photos',
                status: _photosStatus,
                onTap: _requestPhotosPermission,
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
    return Container(
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
          // Icon
          Icon(
            icon,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(width: 16),

          // Title and Description
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

          // Status Button/Text
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
            GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.accentColor(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: const Text(
                  'Grant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
