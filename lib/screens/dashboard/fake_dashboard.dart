import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/routes/app_routes.dart';
import '../security/app_lock_pin_screen.dart';

class FakeDashboard extends StatefulWidget {
  const FakeDashboard({super.key});

  @override
  State<FakeDashboard> createState() => _FakeDashboardState();
}

class _FakeDashboardState extends State<FakeDashboard> with WidgetsBindingObserver {
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFirstLoad = true;

    // 🔒 Start monitoring locked apps in real-time (even in fake dashboard)
    _initializeAppLockMonitoring();
  }

  /// Initialize app lock monitoring service
  void _initializeAppLockMonitoring() {
    final appLockService = AppLockService();

    // Set callback for when a locked app is detected
    appLockService.setOnLockedAppDetectedCallback((packageName) {
      if (mounted) {
        debugPrint('🔒 Locked app detected from fake dashboard: $packageName - Showing PIN screen');
        // Show the app lock PIN verification screen
        final box = Hive.box('securityBox');
        final appNamesMap =
            (box.get('appNamesMap', defaultValue: {}) ?? {}) as Map;
        final appName =
            appNamesMap[packageName]?.toString() ?? packageName.split('.').last;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppLockPinScreen(
              packageName: packageName,
              appName: appName,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clear app lock callback when leaving the fake dashboard
    AppLockService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Force lock when app resumes (user returns from background)
    if (state == AppLifecycleState.resumed) {
      // Skip check on first load
      if (_isFirstLoad) {
        _isFirstLoad = false;
        return;
      }
      
      // Always force re-lock for security - return to lock screen
      Navigator.pushReplacementNamed(context, AppRoutes.lock);
    }
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        appBar: _buildAppBar(context),
        backgroundColor: ThemeConfig.backgroundColor(context),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(context),
              const SizedBox(height: 24),
              _buildStatsCard(context),
              const SizedBox(height: 24),
              _buildFakeActionsCard(context),
              const SizedBox(height: 24),
              _buildSecurityInfoCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: ThemeConfig.appBarBackground(context),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, color: ThemeConfig.accentColor(context), size: 24),
          const SizedBox(width: 12),
          Text(
            'StealthSeal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeConfig.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  // Welcome Card
  Widget _buildWelcomeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeConfig.accentColor(context).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ThemeConfig.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All systems operating normally',
            style: TextStyle(
              color: ThemeConfig.textSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Stats Card
  Widget _buildStatsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeConfig.accentColor(context).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ThemeConfig.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, '12', 'Last Backup', Colors.green),
              _buildStatItem(context, '98%', 'Storage Free', Colors.blue),
              _buildStatItem(context, '✓', 'Status', ThemeConfig.accentColor(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: ThemeConfig.textSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Fake Actions Card
  Widget _buildFakeActionsCard(BuildContext context) {
    final actions = [
      _FakeActionData(
        icon: Icons.apps,
        label: 'Installed Apps',
        description: '147 apps',
        color: Colors.cyan,
      ),
      _FakeActionData(
        icon: Icons.storage,
        label: 'Storage Management',
        description: '512 GB available',
        color: Colors.orange,
      ),
      _FakeActionData(
        icon: Icons.notifications_active,
        label: 'Notifications',
        description: '23 unread',
        color: Colors.pink,
        badge: '23',
      ),
      _FakeActionData(
        icon: Icons.settings,
        label: 'Settings',
        description: 'System preferences',
        color: Colors.purple,
      ),
      _FakeActionData(
        icon: Icons.backup,
        label: 'Backup & Sync',
        description: 'Last backup: 2 hours ago',
        color: Colors.green,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeConfig.accentColor(context).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ThemeConfig.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              return _buildFakeActionTile(context, actions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFakeActionTile(BuildContext context, _FakeActionData action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeConfig.inputBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: action.color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(action.icon, color: action.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label,
                  style: TextStyle(
                    color: ThemeConfig.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  action.description,
                  style: TextStyle(
                    color: ThemeConfig.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (action.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ThemeConfig.errorColor(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                action.badge!,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: action.color.withOpacity(0.6)),
        ],
      ),
    );
  }

  // Security Info Card (for decoy)
  Widget _buildSecurityInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeConfig.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Secure',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.textPrimary(context),
                  ),
                ),
                Text(
                  'All security checks passed',
                  style: TextStyle(
                    color: ThemeConfig.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}

class _FakeActionData {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final String? badge;

  _FakeActionData({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    this.badge,
  });}