import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../security/intruder_logs_screen.dart';
import '../../core/security/panic_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/time_lock_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/security/location_lock_service.dart';
import '../../core/security/biometric_service.dart';

class RealDashboard extends StatefulWidget {
  const RealDashboard({super.key});

  @override
  State<RealDashboard> createState() => _RealDashboardState();
}

class _RealDashboardState extends State<RealDashboard> {
  @override
  void initState() {
    super.initState();

    // 🔐 Enforce Night Lock immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TimeLockService.isNightLockActive()) {
        Navigator.pushReplacementNamed(context, AppRoutes.lock);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.shield, color: Colors.cyan),
            SizedBox(width: 8),
            Text('StealthSeal'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.lock);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _securityStatusCard(),
            const SizedBox(height: 20),
            _quickActionsCard(context),
            const SizedBox(height: 20),
            _emergencyCard(context),
          ],
        ),
      ),
    );
  }

  // 🔐 Security Status Card
  Widget _securityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.2),
            Colors.black,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statusItem('0', 'Apps Locked', Colors.cyan),
          _statusItem(
            getIntruderCount().toString(),
            'Intruders',
            Colors.redAccent,
          ),
          if (TimeLockService.isNightLockActive())
            _statusItem('ON', 'Night Lock', Colors.orangeAccent),
        ],
      ),
    );
  }

  int getIntruderCount() {
    if (!Hive.isBoxOpen('securityBox')) return 0;

    final box = Hive.box('securityBox');
    final List logs = box.get('intruderLogs', defaultValue: []);
    return logs.length;
  }

  Widget _statusItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  // ⚡ Quick Actions
  Widget _quickActionsCard(BuildContext context) {
    return _cardContainer(
      title: 'Quick Actions',
      children: [
        // ✅ BIOMETRIC SWITCH
        SwitchListTile(
          title: const Text(
            'Enable Biometric Unlock',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Use fingerprint or face to unlock',
            style: TextStyle(color: Colors.white70),
          ),
          value: BiometricService.isEnabled(),
          onChanged: (value) async {
            if (value) {
              final supported = await BiometricService.isSupported();
              if (!supported) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Biometric not supported on this device'),
                    ),
                  );
                }
                return;
              }
              BiometricService.enable();
            } else {
              BiometricService.disable();
            }

            setState(() {});
          },
        ),

        _actionTile(
          icon: Icons.apps,
          label: 'Manage App Locks',
          iconColor: Colors.cyan,
          onTap: () {},
        ),

        // ✅ CORRECT NIGHT LOCK ENTRY
        _actionTile(
          icon: Icons.schedule,
          label: 'Time-Based Lock',
          iconColor: Colors.orangeAccent,
          onTap: () {
          Navigator.pushNamed(context, AppRoutes.timeLockService);

          },
        ),

        _actionTile(
          icon: Icons.camera_alt,
          label: 'Intruder Logs',
          iconColor: Colors.redAccent,
          badge: getIntruderCount().toString(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const IntruderLogsScreen(),
              ),
            );
          },
        ),

        _actionTile(
          icon: Icons.settings,
          label: 'Settings',
          iconColor: Colors.grey,
          onTap: () {},
        ),

        // 📍 LOCATION LOCK
        _actionTile(
          icon: Icons.location_on,
          label: 'Set Trusted Location',
          iconColor: Colors.greenAccent,
          onTap: () async {
            try {
              final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );

              LocationLockService.setTrustedLocation(
                latitude: position.latitude,
                longitude: position.longitude,
                radius: 200,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Trusted location set (200m radius)'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location error: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  // 🚨 Emergency
  Widget _emergencyCard(BuildContext context) {
    return _cardContainer(
      title: 'Emergency',
      children: [
        ElevatedButton.icon(
          onPressed: () {
            PanicService.activate();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Panic Mode Activated!'),
                backgroundColor: Colors.red,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.warning, color: Colors.white),
          label: const Text(
            'Activate Panic Lock',
            style: TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Instantly locks all apps and displays security overlay',
          style: TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 🧱 Card Container
  Widget _cardContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // 🔘 Action Tile
  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Text(badge, style: const TextStyle(fontSize: 12)),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
