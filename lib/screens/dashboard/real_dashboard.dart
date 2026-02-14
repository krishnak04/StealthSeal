import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../security/intruder_logs_screen.dart';
import '../security/app_lock_management_screen.dart';
import '../../core/security/panic_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/time_lock_service.dart';
import '../../core/theme/theme_config.dart';

class RealDashboard extends StatefulWidget {
  const RealDashboard({super.key});

  @override
  State<RealDashboard> createState() => _RealDashboardState();
}

class _RealDashboardState extends State<RealDashboard> with WidgetsBindingObserver {
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't check locks on initial load - let the lock screen handle it
    // This prevents the issue where it locks immediately after unlocking
    _isFirstLoad = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check if panic lock or time lock was activated while dashboard was open
    if (state == AppLifecycleState.resumed) {
      // Skip check on first load
      if (_isFirstLoad) {
        _isFirstLoad = false;
        return;
      }
      
      if (PanicService.isActive() || TimeLockService.isNightLockActive()) {
        Navigator.pushReplacementNamed(context, AppRoutes.lock);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityStatusCard(),
            const SizedBox(height: 24),
            _buildQuickActionsCard(context),
            const SizedBox(height: 24),
            _buildEmergencyCard(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: ThemeConfig.appBarBackground(context),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, color: ThemeConfig.accentColor(context), size: 24),
          const SizedBox(width: 8),
          Text(
            'StealthSeal',
            style: TextStyle(
              color: ThemeConfig.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.home, color: ThemeConfig.accentColor(context)),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.settings, color: ThemeConfig.accentColor(context)),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
        IconButton(
          icon: Icon(Icons.lock, color: ThemeConfig.accentColor(context)),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.lock),
        ),
      ],
    );
  }

  Widget _buildSecurityStatusCard() {
    return Builder(
      builder: (context) {
        final intruderCount = getIntruderCount();
        final accentColor = ThemeConfig.accentColor(context);
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ThemeConfig.surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Security Status',
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                        '0',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Apps Locked',
                        style: TextStyle(
                          color: ThemeConfig.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$intruderCount',
                        style: TextStyle(
                          color: ThemeConfig.errorColor(context),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Intruders',
                        style: TextStyle(
                          color: ThemeConfig.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    final intruderCount = getIntruderCount();
    
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
            'Quick Actions',
            style: TextStyle(
              color: ThemeConfig.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionItem(
            icon: Icons.apps,
            label: 'Manage App Locks',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppLockManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            icon: Icons.camera_alt,
            label: 'Intruder Logs',
            badge: intruderCount > 0 ? intruderCount.toString() : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IntruderLogsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeConfig.inputBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: ThemeConfig.accentColor(context), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: ThemeConfig.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeConfig.errorColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: ThemeConfig.accentColor(context), size: 18),
            ],
          ),
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
          Text(
            'Instantly locks all apps and displays security overlay',
            style: TextStyle(
              color: ThemeConfig.textSecondary(context),
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPanicDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.cardColor(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThemeConfig.errorColor(ctx), width: 1.5),
        ),
        title: Text(
          'Confirm Panic Mode',
          style: TextStyle(color: ThemeConfig.textPrimary(ctx), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Activate panic mode? Your app will lock immediately and only respond to the real PIN.',
          style: TextStyle(color: ThemeConfig.textSecondary(ctx), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeConfig.accentColor(ctx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThemeConfig.errorColor(ctx)),
            onPressed: () {
              PanicService.activate();
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Panic Mode Activated! Locking app...'),
                    backgroundColor: ThemeConfig.errorColor(context),
                    duration: const Duration(seconds: 2),
                  ),
                );
                // Navigate to lock screen after short delay
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.lock);
                  }
                });
              }
            },
            child: const Text('Activate'),
          ),
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
}
