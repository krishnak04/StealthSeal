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
  bool _accessibilityEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkAccessibilityService();
  }

  /// Check if accessibility service is enabled
  Future<void> _checkAccessibilityService() async {
    final service = AppLockService();
    final isEnabled = await service.isAccessibilityServiceEnabled();

    if (mounted) {
      setState(() {
        _accessibilityEnabled = isEnabled;
      });
    }

    if (!isEnabled) {
      if (mounted) {
        debugPrint('⚠️ Accessibility service not enabled!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enable Accessibility Service for App Lock to work. Go to Settings > Accessibility > StealthSeal',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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
                style:
                    TextStyle(color: ThemeConfig.textSecondary(dialogContext)),
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
            icon:
                Icon(Icons.bug_report, color: ThemeConfig.textPrimary(context)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.debug),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: ThemeConfig.textPrimary(context)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
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
            /// ⚠️ ACCESSIBILITY WARNING
            if (!_accessibilityEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enable Accessibility Service in Settings for App Lock to work',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                    onTap: () {},
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
              icon: Icon(Icons.warning_rounded, size: 20, color: Colors.white),
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

class _AppLockOverlay extends StatefulWidget {
  final String appName;

  const _AppLockOverlay({
    required this.appName,
  });

  @override
  State<_AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<_AppLockOverlay> {
  String _enteredPin = '';
  String? _realPin;
  String? _decoyPin;
  int _failedAttempts = 0;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  /// Load PINs from Hive
  void _loadPins() {
    final box = Hive.box('securityBox');
    setState(() {
      _realPin = box.get('realPin', defaultValue: null) as String?;
      _decoyPin = box.get('decoyPin', defaultValue: null) as String?;
    });
  }

  /// Handle PIN entry
  void _handlePinEntry(String pin) {
    if (_realPin == null || _decoyPin == null) {
      debugPrint('❌ PINs not configured!');
      return;
    }

    setState(() {
      if (pin == _realPin) {
        // ✅ Correct PIN - close overlay and allow app to open
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App unlocked successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (pin == _decoyPin) {
        // ⚠️ Decoy PIN entered
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Decoy mode activated'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // ❌ Wrong PIN
        _failedAttempts++;
        _showError = true;
        _enteredPin = '';

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _showError = false);
          }
        });
      }
    });
  }

  void _addDigit(String digit) {
    if (_enteredPin.length < 6) {
      setState(() => _enteredPin += digit);
    }
  }

  void _removeDigit() {
    if (_enteredPin.isNotEmpty) {
      setState(
          () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: ThemeConfig.surfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// 🔒 Lock Icon
                Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: ThemeConfig.accentColor(context),
                ),
                const SizedBox(height: 16),

                /// App Name
                Text(
                  "${widget.appName} is Locked",
                  style: TextStyle(
                    color: ThemeConfig.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                /// Instructions
                Text(
                  "Enter your PIN to unlock",
                  style: TextStyle(
                    color: ThemeConfig.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                /// PIN Display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      6,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          width: 40,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _showError
                                ? Colors.red.shade100
                                : index < _enteredPin.length
                                    ? ThemeConfig.accentColor(context)
                                    : ThemeConfig.borderColor(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _showError
                                  ? Colors.red
                                  : ThemeConfig.borderColor(context),
                            ),
                          ),
                          child: index < _enteredPin.length
                              ? Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                /// Error Message
                if (_showError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      "Incorrect PIN",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                /// Numeric Keypad
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: List.generate(12, (index) {
                    if (index < 9) {
                      return _buildKeypadButton(
                        label: '${index + 1}',
                        onPressed: () => _addDigit('${index + 1}'),
                      );
                    } else if (index == 9) {
                      return _buildKeypadButton(
                        label: '0',
                        onPressed: () => _addDigit('0'),
                      );
                    } else if (index == 10) {
                      return _buildKeypadButton(
                        label: '←',
                        onPressed: _removeDigit,
                        isSpecial: true,
                      );
                    } else {
                      return _buildKeypadButton(
                        label: '✓',
                        onPressed: () => _handlePinEntry(_enteredPin),
                        isSpecial: true,
                      );
                    }
                  }),
                ),

                const SizedBox(height: 16),

                /// Failed Attempts Warning
                if (_failedAttempts >= 3)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      'Multiple failed attempts detected',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build keypad button
  Widget _buildKeypadButton({
    required String label,
    required VoidCallback onPressed,
    bool isSpecial = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSpecial
            ? ThemeConfig.accentColor(context)
            : ThemeConfig.backgroundColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSpecial
              ? ThemeConfig.accentColor(context)
              : ThemeConfig.borderColor(context),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color:
                    isSpecial ? Colors.white : ThemeConfig.textPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
