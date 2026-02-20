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
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: ThemeConfig.surfaceColor(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Activate Panic Lock?",
            style: TextStyle(
              color: ThemeConfig.textPrimary(dialogContext),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Are you sure you want to instantly lock all apps and trigger the security overlay?",
            style: TextStyle(color: ThemeConfig.textSecondary(dialogContext)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: TextStyle(color: ThemeConfig.textSecondary(dialogContext)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                PanicService.activate();
                Navigator.pushReplacementNamed(context, AppRoutes.lock);
              },
              child: Text(
                "Activate",
                style: TextStyle(color: ThemeConfig.errorColor(dialogContext)),
              ),
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
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "StealthSeal",
          style: TextStyle(
            color: ThemeConfig.accentColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: ThemeConfig.textPrimary(context)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.settings, color: ThemeConfig.textPrimary(context)),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
          ),
          IconButton(
            icon: Icon(Icons.lock, color: ThemeConfig.textPrimary(context)),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ThemeConfig.accentColor(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield,
                          color: ThemeConfig.accentColor(context), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Security Status",
                        style: TextStyle(
                          color: ThemeConfig.accentColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                            style: TextStyle(
                              color: ThemeConfig.accentColor(context),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Apps Locked",
                            style: TextStyle(
                              color: ThemeConfig.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            "$intruderCount",
                            style: TextStyle(
                              color: ThemeConfig.errorColor(context),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Intruders",
                            style: TextStyle(
                              color: ThemeConfig.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ThemeConfig.borderColor(context),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Actions",
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.apps,
                    label: "Manage App Locks",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppLockManagementScreen(),
                      ),
                    ),
                    context: context,
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    icon: Icons.warning_amber,
                    label: "Intruder Logs",
                    badge: intruderCount > 0 ? intruderCount.toString() : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IntruderLogsScreen(),
                      ),
                    ),
                    context: context,
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    icon: Icons.settings,
                    label: "Settings",
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
                    context: context,
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeConfig.surfaceColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ThemeConfig.borderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThemeConfig.accentColor(context), size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeConfig.errorColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(Icons.arrow_forward_ios,
                  color: ThemeConfig.textSecondary(context), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeConfig.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency',
            style: TextStyle(
              color: ThemeConfig.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.warning_rounded,
                  size: 20, color: Colors.white),
              label: Text(
                'Activate Panic Lock',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
      backgroundColor: ThemeConfig.surfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        "$appName Locked",
        style: TextStyle(
          color: ThemeConfig.textPrimary(context),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        "Access denied. Please verify your PIN.",
        style: TextStyle(color: ThemeConfig.textSecondary(context)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Unlock",
            style: TextStyle(color: ThemeConfig.accentColor(context)),
          ),
        ),
      ],
    );
  }
}