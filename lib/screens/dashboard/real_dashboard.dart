import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../security/intruder_logs_screen.dart';
import '../security/app_lock_management_screen.dart';
import '../../core/security/panic_service.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/theme_config.dart';

class RealDashboard extends StatefulWidget {
  const RealDashboard({super.key});

  @override
  State<RealDashboard> createState() => _RealDashboardState();
}

class _RealDashboardState extends State<RealDashboard> {
  @override
  void initState() {
    super.initState();
    _initializeAccessibilityLock();
  }

  /// ✅ Initialize Accessibility based App Lock
  void _initializeAccessibilityLock() {
    final service = AppLockService();

    service.initialize();

    service.setOnLockedAppDetectedCallback((packageName) {
      if (mounted) {
        _showAppLockDialog(packageName);
      }
    });
  }

  void _showAppLockDialog(String packageName) {
    final box = Hive.box('securityBox');
    final appNamesMap =
        (box.get('appNamesMap', defaultValue: {}) ?? {}) as Map;

    final appName =
        appNamesMap[packageName] ?? packageName.split('.').last;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AppLockOverlay(
        appName: appName,
      ),
    );
  }

  // ✅ Added missing _showPanicDialog method
  void _showPanicDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Activate Panic Lock?"),
          content: const Text(
              "Are you sure you want to instantly lock all apps and trigger the security overlay?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // Close dialog
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                PanicService.activate(); // Trigger the panic service
                Navigator.pushReplacementNamed(context, AppRoutes.lock); // Lock the app
              },
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.errorColor(context),
              ),
              child: const Text("Activate"),
            ),
          ],
        );
      },
    );
  }

  int getIntruderCount() {
    if (!Hive.isBoxOpen('securityBox')) return 0;
    final box = Hive.box('securityBox');
    final List logs = box.get('intruderLogs', defaultValue: []);
    return logs.length;
  }

  int getLockedAppsCount() {
    if (!Hive.isBoxOpen('securityBox')) return 0;
    final box = Hive.box('securityBox');
    final List locked = box.get('lockedApps', defaultValue: []);
    return locked.length;
  }

  @override
  Widget build(BuildContext context) {
    final intruderCount = getIntruderCount();
    final lockedCount = getLockedAppsCount();

    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor(context),
      appBar: AppBar(
        title: const Text("StealthSeal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.lock),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔵 SECURITY STATUS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeConfig.accentColor(context),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield,
                          color: ThemeConfig.accentColor(context)),
                      const SizedBox(width: 8),
                      const Text(
                        "Security Status",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            "$lockedCount",
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text("Apps Locked"),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            "$intruderCount",
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          ),
                          const Text("Intruders"),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// 🔵 QUICK ACTIONS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Quick Actions",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.apps),
                    title: const Text("Manage App Locks"),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppLockManagementScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text("Intruder Logs"),
                    trailing: intruderCount > 0
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Text(
                              intruderCount.toString(),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IntruderLogsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildEmergencyCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency',
            style: TextStyle(
              color: ThemeConfig.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showPanicDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.warning_rounded, size: 20),
              label: const Text(
                'Activate Panic Lock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Instantly locks all apps and displays security overlay',
              style: TextStyle(
                color: ThemeConfig.textSecondary(context),
                fontSize: 12,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLockOverlay extends StatelessWidget {
  final String appName;

  const _AppLockOverlay({
    required this.appName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("$appName Locked"),
      content: const Text("Access denied. Please verify your PIN."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Unlock"),
        ),
      ],
    );
  }
}