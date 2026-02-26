import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../security/intruder_logs_screen.dart';
import '../security/app_lock_management_screen.dart';
import '../security/app_lock_pin_screen.dart';
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
  /// Tracks whether the Android accessibility service is currently enabled.
  bool _accessibilityEnabled = true;

  @override
  void initState() {
    super.initState();
    _setupAppLockCallback();
    _checkAccessibilityService();
  }

  // ─── Accessibility & App Lock Setup ────────────────────────────────

  /// Verifies accessibility service status and warns the user if disabled.
  Future<void> _checkAccessibilityService() async {
    final appLockService = AppLockService();
    final isServiceEnabled = await appLockService.isAccessibilityServiceEnabled();

    if (mounted) {
      setState(() {
        _accessibilityEnabled = isServiceEnabled;
      });
    }

    if (!isServiceEnabled && mounted) {
      debugPrint('Accessibility service not enabled !');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Enable Accessibility Service for App Lock to work. '
            'Go to Settings > Accessibility > StealthSeal',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color.fromARGB(255, 214, 77, 77),
        ),
      );
    }
  }

  /// Registers a callback so the app lock service can trigger the PIN
  /// screen when a locked app is opened.
  void _setupAppLockCallback() {
    final appLockService = AppLockService();

    appLockService.setOnLockedAppDetectedCallback((packageName) {
      if (mounted) {
        _showAppLockPinScreen(packageName);
      }
    });
  }

  /// Navigates to the PIN verification screen for a locked app.
  ///
  /// Resolves a human-readable app name from Hive's cached name map,
  /// falling back to the last segment of the package name.
  void _showAppLockPinScreen(String packageName) {
    if (!Hive.isBoxOpen('securityBox')) return;

    final securityBox = Hive.box('securityBox');
    final cachedAppNames =
        (securityBox.get('appNamesMap', defaultValue: {}) ?? {}) as Map;

    final displayName =
        cachedAppNames[packageName]?.toString() ?? packageName.split('.').last;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppLockPinScreen(
          packageName: packageName,
          appName: displayName,
        ),
      ),
    );
  }

  // ─── Panic Lock ─────────────────────────────────────────────────────

  /// Shows a confirmation dialog before activating panic mode.
  ///
  /// On confirmation, enables panic lock and redirects to the lock screen.
  void _showPanicDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final primaryTextColor = ThemeConfig.textPrimary(dialogContext);
        final secondaryTextColor = ThemeConfig.textSecondary(dialogContext);
        final dangerColor = ThemeConfig.errorColor(dialogContext);

        return AlertDialog(
          backgroundColor: ThemeConfig.surfaceColor(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Activate Panic Lock?",
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Are you sure you want to instantly lock all apps "
            "and trigger the security overlay?",
            style: TextStyle(color: secondaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: TextStyle(color: secondaryTextColor),
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
                style: TextStyle(color: dangerColor),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Data Helpers ───────────────────────────────────────────────────

  /// Returns the number of intruder selfie logs stored in Hive.
  int getIntruderCount() {
    if (!Hive.isBoxOpen('securityBox')) return 0;
    final securityBox = Hive.box('securityBox');
    final List intruderLogs = securityBox.get('intruderLogs', defaultValue: []);
    return intruderLogs.length;
  }

  /// Returns the number of apps currently locked by the user.
  int getLockedAppsCount() {
    if (!Hive.isBoxOpen('securityBox')) return 0;
    final securityBox = Hive.box('securityBox');
    final List lockedAppsList = securityBox.get('lockedApps', defaultValue: []);
    return lockedAppsList.length;
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalIntruders = getIntruderCount();
    final totalLockedApps = getLockedAppsCount();

    final accent = ThemeConfig.accentColor(context);
    final textPrimary = ThemeConfig.textPrimary(context);

    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        centerTitle: false,
        title: Text(
          "StealthSeal",
          style: TextStyle(
            color: accent,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Refresh dashboard counts
          IconButton(
            icon: Icon(Icons.refresh, color: textPrimary),
            onPressed: () => setState(() {}),
          ),
          // Navigate to settings
          IconButton(
            icon: Icon(Icons.settings, color: textPrimary),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
          ),
          // Manual lock
          IconButton(
            icon: Icon(Icons.lock, color: textPrimary),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.lock),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Security Status Card ──
            _buildSecurityStatusCard(
              context,
              lockedAppsCount: totalLockedApps,
              intruderCount: totalIntruders,
            ),

            const SizedBox(height: 24),

            // ── Quick Actions Card ──
            _buildQuickActionsCard(context, totalIntruders),

            const SizedBox(height: 24),

            // ── Emergency Panic Card ──
            _buildEmergencyCard(context),
          ],
        ),
      ),
    );
  }

  // ─── Section Builders ──────────────────────────────────────────────

  /// Security overview showing locked-app and intruder counts.
  Widget _buildSecurityStatusCard(
    BuildContext context, {
    required int lockedAppsCount,
    required int intruderCount,
  }) {
    final accent = ThemeConfig.accentColor(context);
    final secondaryText = ThemeConfig.textSecondary(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.shield, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Security Status",
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Locked apps stat
              Column(
                children: [
                  Text(
                    "$lockedAppsCount",
                    style: TextStyle(
                      color: accent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Apps Locked",
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              // Intruders stat
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
                      color: secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Quick action shortcuts: Manage locks, view intruder logs, settings.
  Widget _buildQuickActionsCard(BuildContext context, int intruderCount) {
    final hasBadge = intruderCount > 0 ? intruderCount.toString() : null;

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
            badge: hasBadge,
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
    );
  }

  // ─── Reusable Widgets ──────────────────────────────────────────────

  /// A tappable row with an icon, label, and optional notification badge.
  ///
  /// When [badge] is provided, a red pill is shown instead of the arrow.
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
            // Show count badge or a simple chevron
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
              Icon(
                Icons.arrow_forward_ios,
                color: ThemeConfig.textSecondary(context),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  /// Full-width emergency card with a destructive "Panic Lock" button.
  Widget _buildEmergencyCard(BuildContext context) {
    final dangerColor = ThemeConfig.errorColor(context);

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

          // Panic button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showPanicDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(
                Icons.warning_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Activate Panic Lock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Explanation text
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