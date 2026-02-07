import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppData {
  final String packageName;
  final String appName;
  final IconData icon;
  final String appType; // "System application", "Third-party application", etc.

  AppData({
    required this.packageName,
    required this.appName,
    required this.icon,
    required this.appType,
  });
}

class AppLockManagementScreen extends StatefulWidget {
  const AppLockManagementScreen({super.key});

  @override
  State<AppLockManagementScreen> createState() => _AppLockManagementScreenState();
}

class _AppLockManagementScreenState extends State<AppLockManagementScreen> {
  List<String> _lockedApps = [];

  // Common apps that users might want to lock
  final List<AppData> commonApps = [
    AppData(packageName: 'com.android.settings', appName: 'Settings', icon: Icons.settings, appType: 'System application'),
    AppData(packageName: 'com.google.android.gm', appName: 'Gmail', icon: Icons.mail, appType: 'System application'),
    AppData(packageName: 'com.android.chrome', appName: 'Chrome', icon: Icons.language, appType: 'System application'),
    AppData(packageName: 'com.google.android.apps.docs.editors.docs', appName: 'Google Docs', icon: Icons.description, appType: 'Third-party application'),
    AppData(packageName: 'com.google.android.apps.docs.editors.sheets', appName: 'Google Sheets', icon: Icons.grid_on, appType: 'Third-party application'),
    AppData(packageName: 'com.google.android.apps.photos', appName: 'Photos', icon: Icons.photo, appType: 'System application'),
    AppData(packageName: 'com.whatsapp', appName: 'WhatsApp', icon: Icons.chat, appType: 'Third-party application'),
    AppData(packageName: 'com.facebook.katana', appName: 'Facebook', icon: Icons.people, appType: 'Third-party application'),
    AppData(packageName: 'com.instagram.android', appName: 'Instagram', icon: Icons.image, appType: 'Third-party application'),
    AppData(packageName: 'com.google.android.apps.maps', appName: 'Google Maps', icon: Icons.location_on, appType: 'System application'),
    AppData(packageName: 'com.spotify.music', appName: 'Spotify', icon: Icons.music_note, appType: 'Third-party application'),
    AppData(packageName: 'com.netflix.mediaclient', appName: 'Netflix', icon: Icons.play_circle, appType: 'Third-party application'),
    AppData(packageName: 'com.amazon.mShop.android', appName: 'Amazon Shopping', icon: Icons.shopping_bag, appType: 'Third-party application'),
    AppData(packageName: 'com.PayPal.Android', appName: 'PayPal', icon: Icons.payment, appType: 'Third-party application'),
    AppData(packageName: 'com.twitter.android', appName: 'X (Twitter)', icon: Icons.favorite, appType: 'Third-party application'),
    AppData(packageName: 'com.linkedin.android', appName: 'LinkedIn', icon: Icons.work, appType: 'Third-party application'),
    AppData(packageName: 'com.viber.voip', appName: 'Viber', icon: Icons.phone, appType: 'Third-party application'),
    AppData(packageName: 'org.telegram.messenger', appName: 'Telegram', icon: Icons.message, appType: 'Third-party application'),
    AppData(packageName: 'com.google.android.banking', appName: 'Google Pay', icon: Icons.credit_card, appType: 'System application'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLockedApps();
  }

  void _loadLockedApps() {
    final box = Hive.box('securityBox');
    setState(() {
      _lockedApps = List<String>.from(
        box.get('lockedApps', defaultValue: []) as List,
      );
    });
  }

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
    
    if (mounted) {
      final isLocked = _lockedApps.contains(packageName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isLocked ? Icons.lock : Icons.lock_open,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                isLocked ? '🔒 App locked' : '🔓 App unlocked',
              ),
            ],
          ),
          backgroundColor: isLocked ? Colors.redAccent : Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage App Locks',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0a0e27),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.cyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFF0a0e27),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        itemCount: commonApps.length,
        itemBuilder: (context, index) {
          final app = commonApps[index];
          final isLocked = _lockedApps.contains(app.packageName);

          return GestureDetector(
            onTap: () => _toggleAppLock(app.packageName),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLocked ? Colors.redAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // App Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade800,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      app.icon,
                      color: isLocked ? Colors.redAccent : Colors.cyan,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // App Name and Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          app.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.appType,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Lock Icon
                  Container(
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.redAccent.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isLocked ? Icons.lock : Icons.lock_open,
                      color: isLocked ? Colors.redAccent : Colors.white.withOpacity(0.5),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
