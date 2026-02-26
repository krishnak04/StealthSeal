import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/theme/theme_config.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  late Box _securityBox;

  @override
  void initState() {
    super.initState();
    _securityBox = Hive.box('securityBox');
  }

  Future<void> _testLock() async {
    final service = AppLockService();
    final isEnabled = await service.isAccessibilityServiceEnabled();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Accessibility Service: $isEnabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockedApps = List<String>.from(_securityBox.get('lockedApps', defaultValue: []) as List);
    final appNamesMap = (_securityBox.get('appNamesMap', defaultValue: {}) ?? {}) as Map;

    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Debug Information'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeConfig.surfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ThemeConfig.borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accessibility Service Status',
                  style: TextStyle(
                    color: ThemeConfig.accentColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _testLock,
                  child: const Text('Check Accessibility Service'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeConfig.surfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ThemeConfig.borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Locked Apps (${lockedApps.length})',
                  style: TextStyle(
                    color: ThemeConfig.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (lockedApps.isEmpty)
                  Text(
                    'No locked apps',
                    style: TextStyle(color: ThemeConfig.textSecondary(context)),
                  )
                else
                  ...lockedApps.map(
                    (package) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• $package',
                        style: TextStyle(color: ThemeConfig.textPrimary(context), fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeConfig.surfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ThemeConfig.borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Names Map (${appNamesMap.length})',
                  style: TextStyle(
                    color: ThemeConfig.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (appNamesMap.isEmpty)
                  Text(
                    'No apps loaded',
                    style: TextStyle(color: ThemeConfig.textSecondary(context)),
                  )
                else
                  ...appNamesMap.entries.take(5).map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${entry.value} (${entry.key})',
                            style: TextStyle(
                              color: ThemeConfig.textPrimary(context),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                if (appNamesMap.length > 5)
                  Text(
                    '... and ${appNamesMap.length - 5} more',
                    style: TextStyle(color: ThemeConfig.textSecondary(context), fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
