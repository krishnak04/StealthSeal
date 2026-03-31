import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';

class InstalledApp {
  final String label;
  final String packageName;
  final String? icon;

  InstalledApp({required this.label, required this.packageName, this.icon});
}

class StealthModeSettingsScreen extends StatefulWidget {
  const StealthModeSettingsScreen({super.key});

  @override
  State<StealthModeSettingsScreen> createState() =>
      _StealthModeSettingsScreenState();
}

class _StealthModeSettingsScreenState extends State<StealthModeSettingsScreen> {
  late Box _securityBox;
  late String _selectedMode;
  late String _selectedAppLabel;
  List<InstalledApp> _installedApps = [];
  bool _isLoadingApps = false;

  static const platform = MethodChannel('com.stealthseal.app/applock');
Future<void> setStealthMode(String mode) async {
  try {
    await platform.invokeMethod('setStealthDisguise', {
      "mode": mode,
    });
    print("Stealth mode changed to: $mode");
  } catch (e) {
    print("Error: $e");
  }
}

  @override
  void initState() {
    super.initState();
    _securityBox = Hive.box('securityBox');
    _loadSettings();
  }

  void _loadSettings() {
    _selectedMode = _securityBox.get('stealthMode', defaultValue: 'normal');
    _selectedAppLabel = _securityBox.get('selectedAppLabel', defaultValue: '');
  }

  Future<void> _fetchInstalledApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final result = await platform.invokeMethod('getInstalledApps');
      if (result is List) {
        setState(() {
          _installedApps = result.map((app) {
            return InstalledApp(
              label: app['name'] ?? 'Unknown',
              packageName: app['package'] ?? '',
            );
          }).toList();
          _isLoadingApps = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching apps: $e');
      setState(() => _isLoadingApps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load installed apps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setStealthMode(String mode) async {
    setState(() => _selectedMode = mode);
    _securityBox.put('stealthMode', mode);

    String message = mode == 'normal' 
        ? 'Switched to Normal Mode' 
        : 'Switched to App Disguise';

    if (mode == 'normal') {
      await _applyNormalMode();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00BCD4),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _applyNormalMode() async {
    try {
      await platform.invokeMethod('setStealthDisguise', {
        'mode': 'normal',
        'packageName': '',
      });
      debugPrint('Normal mode applied successfully');
    } catch (e) {
      debugPrint('Error applying normal mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error switching to Normal Mode'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectApp(InstalledApp app) {
    setState(() {
      _selectedMode = 'settings';
      _selectedAppLabel = app.label;
    });

    _securityBox.put('stealthMode', _selectedMode);
    _securityBox.put('selectedAppPackage', app.packageName);
    _securityBox.put('selectedAppLabel', app.label);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(' Shortcut created: "${app.label}"\nTap and pin it to home screen'),
        backgroundColor: const Color(0xFF00BCD4),
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildAppOption(BuildContext context, String appName, String packageName) {
    String mode = _getStealthModeFromPackage(packageName);
    return GestureDetector(
      onTap: () {
        _selectAppByName(appName, packageName);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ThemeConfig.backgroundColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ThemeConfig.borderColor(context),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.apps,
              color: ThemeConfig.accentColor(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              appName,
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Radio<String>(
              value: mode,
              groupValue: _selectedMode,
              activeColor: ThemeConfig.accentColor(context),
              fillColor: WidgetStateProperty.all(
                ThemeConfig.accentColor(context),
              ),
              onChanged: (value) {
                _selectAppByName(appName, packageName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAppByName(String appName, String packageName) async {
  String mode = _getStealthModeFromPackage(packageName);

  setState(() {
    _selectedMode = mode;
    _selectedAppLabel = appName;
  });

  _securityBox.put('stealthMode', mode);
  _securityBox.put('selectedAppPackage', packageName);
  _securityBox.put('selectedAppLabel', appName);

  
  await _applyStealthDisguise(mode, packageName);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(' Shortcut created: "$appName"\nTap and pin it to home screen'),
      backgroundColor: const Color(0xFF00BCD4),
      duration: const Duration(seconds: 3),
    ),
  );
}

  String _getStealthModeFromPackage(String packageName) {
    switch (packageName) {
      case 'com.android.settings':
        return 'settings';
      case 'com.android.vending':
        return 'playstore';
      case 'com.google.android.youtube':
        return 'youtube';
      default:
        return 'settings';
    }
  }

  Future<void> _applyStealthDisguise(String mode, String packageName) async {
    try {
    await platform.invokeMethod('setStealthDisguise', {
  'mode': mode,
  'packageName': packageName,
});
      debugPrint('Stealth disguise applied for $mode');
    } catch (e) {
      debugPrint('Error applying stealth disguise: $e');
    }
  }

  void _applyStealthDisguiseSync(String mode, String packageName) {
    // Fire and forget - don't wait for the platform call
    platform.invokeMethod('setStealthDisguise', {
      'mode': mode,
      'packageName': packageName,
    }).then((_) {
      debugPrint('Stealth disguise applied for $mode');
    }).catchError((e) {
      debugPrint('Error applying stealth disguise: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error applying stealth disguise'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    });
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
          'Stealth Mode',
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
              
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB74D),
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stealth mode can make it harder to find this app',
                        style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: () => _setStealthMode('normal'),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeConfig.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == 'normal'
                          ? ThemeConfig.accentColor(context)
                          : ThemeConfig.borderColor(context),
                      width: _selectedMode == 'normal' ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: ThemeConfig.accentColor(context),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Normal Mode',
                            style: TextStyle(
                              color: ThemeConfig.textPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'App visible in launcher',
                            style: TextStyle(
                              color: ThemeConfig.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Radio<String>(
                        value: 'normal',
                        groupValue: _selectedMode,
                        activeColor: ThemeConfig.accentColor(context),
                        fillColor: WidgetStateProperty.all(
                          ThemeConfig.accentColor(context),
                        ),
                        onChanged: (value) => _setStealthMode('normal'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.accentColor(context).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.app_shortcut,
                          color: ThemeConfig.accentColor(context),
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Disguise',
                              style: TextStyle(
                                color: ThemeConfig.textPrimary(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedMode != 'normal' && _selectedAppLabel.isNotEmpty
                                  ? 'Disguised as: $_selectedAppLabel'
                                  : 'Select an app to disguise as',
                              style: TextStyle(
                                color: ThemeConfig.textSecondary(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        _buildAppOption(context, 'Settings', 'com.android.settings'),
                        _buildAppOption(context, 'Play Store', 'com.android.vending'),
                        _buildAppOption(context, 'YouTube', 'com.google.android.youtube'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.accentColor(context).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: ThemeConfig.accentColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'App Disguise creates a fake shortcut with the app\'s icon. Tap it to open StealthSeal, then pin it to home screen',
                        style: TextStyle(
                          color: ThemeConfig.accentColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeConfig.backgroundColor(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select App to Disguise As',
                style: TextStyle(
                  color: ThemeConfig.textPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingApps)
                SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ThemeConfig.accentColor(context),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 400,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: _installedApps.length,
                    itemBuilder: (context, index) {
                      final app = _installedApps[index];
                      return ListTile(
                        title: Text(
                          app.label,
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          app.packageName,
                          style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => _selectApp(app),
                        trailing: Icon(
                          Icons.arrow_forward,
                          color: ThemeConfig.accentColor(context),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
