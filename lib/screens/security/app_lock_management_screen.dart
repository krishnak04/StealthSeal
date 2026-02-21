import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';

class AppLockManagementScreen extends StatefulWidget {
  const AppLockManagementScreen({super.key});

  @override
  State<AppLockManagementScreen> createState() =>
      _AppLockManagementScreenState();
}

class _AppLockManagementScreenState extends State<AppLockManagementScreen> {
  static const platform = MethodChannel('com.stealthseal.app/applock');

  List<String> _lockedApps = [];
  List<Map<String, dynamic>> _installedApps = [];

  bool _showLockedTab = false;
  bool _isLoading = true;

  // System-critical apps that should never be lockable
  static const _systemExcludedPackages = {
    'com.example.stealthseal',
    'com.android.systemui',
    'com.android.launcher',
    'com.android.launcher2',
    'com.android.launcher3',
    'com.google.android.apps.nexuslauncher',
    'com.sec.android.app.launcher',
    'com.mi.android.globallauncher',
    'com.oppo.launcher',
    'com.android.settings',
    'com.android.phone',
    'com.android.server.telecom',
    'com.android.incallui',
    'com.android.packageinstaller',
    'com.google.android.packageinstaller',
    'com.android.permissioncontroller',
    'com.android.inputmethod.latin',
    'com.google.android.inputmethod.latin',
    'com.samsung.android.honeyboard',
    'com.swiftkey.languageprovider',
    'com.touchtype.swiftkey',
    'com.google.android.gboard',
  };

  @override
  void initState() {
    super.initState();
    _loadLockedApps();
    _loadInstalledApps();
  }

  /// Load installed apps
  Future<void> _loadInstalledApps() async {
    try {
      debugPrint('📱 Requesting installed apps from native code...');
      final List<dynamic> result =
          await platform.invokeMethod('getInstalledApps');

      debugPrint('✅ Received ${result.length} apps from native');

      setState(() {
        _installedApps = result
            .map<Map<String, dynamic>>((app) => {
                  "name": app["name"],
                  "package": app["package"],
                  "icon": app["icon"],
                })
            .where((app) => !_systemExcludedPackages.contains(app["package"]))
            .toList();
        _isLoading = false;
      });

      debugPrint('📝 Loaded ${_installedApps.length} apps into UI');

      // Update appNamesMap in Hive for the Dashboard to use
      final box = Hive.box('securityBox');
      Map<String, String> appNamesMap = {};
      for (var app in _installedApps) {
        appNamesMap[app["package"]] = app["name"];
      }
      await box.put('appNamesMap', appNamesMap);
    } catch (e) {
      debugPrint('❌ ERROR loading installed apps: $e');
      setState(() {
        _installedApps = [];
        _isLoading = false;
      });
    }
  }

  /// Load locked apps from Hive
  void _loadLockedApps() {
    final box = Hive.box('securityBox');
    _lockedApps =
        List<String>.from(box.get('lockedApps', defaultValue: []) as List);
    // Remove any system-critical apps that may have been locked previously
    final before = _lockedApps.length;
    _lockedApps.removeWhere((pkg) => _systemExcludedPackages.contains(pkg));
    if (_lockedApps.length != before) {
      box.put('lockedApps', _lockedApps);
      debugPrint(
          '🛡️ Removed ${before - _lockedApps.length} system apps from locked list');
    }
  }

  /// Toggle lock
  Future<void> _toggleAppLock(String packageName) async {
    final box = Hive.box('securityBox');

    setState(() {
      if (_lockedApps.contains(packageName)) {
        _lockedApps.remove(packageName);
      } else {
        _lockedApps.add(packageName);
      }
    });

    await box.put('lockedApps', _lockedApps);

    // ✅ Sync with Android native SharedPreferences
    try {
      final lockedAppsStr = _lockedApps.join(',');
      await platform.invokeMethod('setLockedApps', {'apps': lockedAppsStr});
    } catch (e) {
      debugPrint('Error syncing locked apps: $e');
    }
  }

  List<Map<String, dynamic>> get _unlockApps =>
      _installedApps.where((a) => !_lockedApps.contains(a["package"])).toList();

  List<Map<String, dynamic>> get _lockedAppsList =>
      _installedApps.where((a) => _lockedApps.contains(a["package"])).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor(context),
      appBar: AppBar(
        title: const Text("Manage App Locks"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _installedApps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: ThemeConfig.textSecondary(context)),
                      const SizedBox(height: 16),
                      Text(
                        "No apps found",
                        style: TextStyle(
                          color: ThemeConfig.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Check the console for errors.\nMake sure QUERY_ALL_PACKAGES\npermission is granted.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 12),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 10),

                    /// Tabs
                    Row(
                      children: [
                        _buildTab(
                            "Unlock (${_unlockApps.length})", !_showLockedTab,
                            () {
                          setState(() => _showLockedTab = false);
                        }),
                        _buildTab("Locked (${_lockedAppsList.length})",
                            _showLockedTab, () {
                          setState(() => _showLockedTab = true);
                        }),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// App List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _showLockedTab
                            ? _lockedAppsList.length
                            : _unlockApps.length,
                        itemBuilder: (context, index) {
                          final app = _showLockedTab
                              ? _lockedAppsList[index]
                              : _unlockApps[index];

                          final isLocked = _lockedApps.contains(app["package"]);

                          return ListTile(
                            leading: _buildIcon(app["icon"]),
                            title: Text(
                              app["name"],
                              style: TextStyle(
                                  color: ThemeConfig.textPrimary(context)),
                            ),
                            subtitle: Text(
                              app["package"],
                              style: TextStyle(
                                  color: ThemeConfig.textSecondary(context),
                                  fontSize: 12),
                            ),
                            trailing: Icon(
                              isLocked ? Icons.lock : Icons.lock_open,
                              color:
                                  isLocked ? Colors.red : Colors.grey.shade600,
                            ),
                            onTap: () => _toggleAppLock(app["package"]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Tab Widget
  Widget _buildTab(String title, bool isActive, VoidCallback onTap) {
    final accentColor = ThemeConfig.accentColor(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? accentColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? accentColor : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Convert Base64 icon
  Widget _buildIcon(String base64Icon) {
    try {
      Uint8List bytes = base64Decode(base64Icon);
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.apps),
          ),
        ),
      );
    } catch (e) {
      return const Icon(Icons.apps);
    }
  }
}
