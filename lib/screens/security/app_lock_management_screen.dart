import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:hive/hive.dart';

class AppLockManagementScreen extends StatefulWidget {
  const AppLockManagementScreen({super.key});

  @override
  State<AppLockManagementScreen> createState() => _AppLockManagementScreenState();
}

class _AppLockManagementScreenState extends State<AppLockManagementScreen> {
  late Future<List<Application>> _appsFuture;
  List<String> _lockedApps = [];
  Set<String> _animatingApps = {};

  @override
  void initState() {
    super.initState();
    _loadLockedApps();
    _appsFuture = DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false,
    );
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
      body: FutureBuilder<List<Application>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.cyan),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading apps: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No apps found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final apps = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final isLocked = _lockedApps.contains(app.packageName);
              final isAnimating = _animatingApps.contains(app.packageName);

              return AnimatedBuilder(
                animation: AlwaysStoppedAnimation(0),
                builder: (context, child) {
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
                                  ),
                                  child: app is ApplicationWithIcon
                                      ? Image.memory(
                                          app.icon,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.apps,
                                          color: Colors.cyan,
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
                                  maxLines: 2,
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
              );
            },
          );
        },
      ),
    );
  }
}
