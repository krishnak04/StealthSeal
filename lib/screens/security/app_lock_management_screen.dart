import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppData {
  final String packageName;
  final String appName;
  final IconData icon;

  AppData({
    required this.packageName,
    required this.appName,
    required this.icon,
  });
}

class AppLockManagementScreen extends StatefulWidget {
  const AppLockManagementScreen({super.key});

  @override
  State<AppLockManagementScreen> createState() => _AppLockManagementScreenState();
}

class _AppLockManagementScreenState extends State<AppLockManagementScreen> {
  List<String> _lockedApps = [];
  Set<String> _animatingApps = {};

  // Common apps that users might want to lock
  final List<AppData> commonApps = [
    AppData(packageName: 'com.whatsapp', appName: 'WhatsApp', icon: Icons.chat),
    AppData(packageName: 'com.facebook.katana', appName: 'Facebook', icon: Icons.people),
    AppData(packageName: 'com.instagram.android', appName: 'Instagram', icon: Icons.image),
    AppData(packageName: 'com.google.android.gm', appName: 'Gmail', icon: Icons.mail),
    AppData(packageName: 'com.android.chrome', appName: 'Chrome', icon: Icons.language),
    AppData(packageName: 'com.google.android.apps.maps', appName: 'Google Maps', icon: Icons.location_on),
    AppData(packageName: 'com.spotify.music', appName: 'Spotify', icon: Icons.music_note),
    AppData(packageName: 'com.netflix.mediaclient', appName: 'Netflix', icon: Icons.play_circle),
    AppData(packageName: 'com.amazon.mShop.android', appName: 'Amazon Shopping', icon: Icons.shopping_bag),
    AppData(packageName: 'com.PayPal.Android', appName: 'PayPal', icon: Icons.payment),
    AppData(packageName: 'com.twitter.android', appName: 'X (Twitter)', icon: Icons.favorite),
    AppData(packageName: 'com.linkedin.android', appName: 'LinkedIn', icon: Icons.work),
    AppData(packageName: 'com.viber.voip', appName: 'Viber', icon: Icons.phone),
    AppData(packageName: 'org.telegram.messenger', appName: 'Telegram', icon: Icons.message),
    AppData(packageName: 'com.google.android.banking', appName: 'Google Pay', icon: Icons.credit_card),
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
      _animatingApps.add(packageName);
    });

    // Simulate animation duration
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      if (_lockedApps.contains(packageName)) {
        _lockedApps.remove(packageName);
      } else {
        _lockedApps.add(packageName);
      }
      _animatingApps.remove(packageName);
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
            color: Colors.cyan,
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        itemCount: commonApps.length,
        itemBuilder: (context, index) {
          final app = commonApps[index];
          final isLocked = _lockedApps.contains(app.packageName);
          final isAnimating = _animatingApps.contains(app.packageName);

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: isAnimating ? 0 : 1,
              end: isAnimating ? 0.95 : 1,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: isLocked ? Colors.redAccent : Colors.cyan.withOpacity(0.2),
                    end: isAnimating 
                        ? Colors.yellow 
                        : (isLocked ? Colors.redAccent : Colors.cyan.withOpacity(0.2)),
                  ),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  builder: (context, borderColor, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor ?? Colors.cyan.withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          if (isLocked)
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          if (isAnimating)
                            BoxShadow(
                              color: Colors.yellow.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade800,
                            border: Border.all(
                              color: Colors.cyan.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            app.icon,
                            color: isLocked ? Colors.redAccent : Colors.cyan,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          app.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          app.packageName,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: isLocked ? 1 : 0,
                            end: isAnimating ? 0.5 : (isLocked ? 1 : 0),
                          ),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, rotation, child) {
                            return Transform.rotate(
                              angle: rotation * 3.14159,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? Colors.redAccent.withOpacity(0.2)
                                      : Colors.cyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isLocked ? Colors.redAccent : Colors.cyan,
                                    width: 1.5,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isLocked ? Icons.lock : Icons.lock_open,
                                    color: isLocked ? Colors.redAccent : Colors.cyan,
                                    size: 20,
                                  ),
                                  onPressed: isAnimating
                                      ? null
                                      : () => _toggleAppLock(app.packageName),
                                ),
                              ),
                            );
                          },
                        ),
                        onTap: isAnimating
                            ? null
                            : () => _toggleAppLock(app.packageName),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
