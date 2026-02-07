import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/intruder_logs_screen.dart';
import '../security/app_lock_management_screen.dart';
import '../../core/security/panic_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/time_lock_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/security/location_lock_service.dart';
import '../../core/security/biometric_service.dart';
import '../../core/services/user_identifier_service.dart';

class RealDashboard extends StatefulWidget {
  const RealDashboard({super.key});

  @override
  State<RealDashboard> createState() => _RealDashboardState();
}

class _RealDashboardState extends State<RealDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Start animation
    _animationController.forward();

    // 🔐 Enforce Night Lock immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TimeLockService.isNightLockActive()) {
        Navigator.pushReplacementNamed(context, AppRoutes.lock);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAnimatedAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0a0e27).withOpacity(0.95),
              const Color(0xFF1a1a3e).withOpacity(0.95),
              const Color(0xFF0f0f2e).withOpacity(0.95),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 90, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 24),
                  _buildSecurityStatusCard(),
                  const SizedBox(height: 24),
                  _buildQuickActionsCard(context),
                  const SizedBox(height: 24),
                  _buildEmergencyCard(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎯 Animated AppBar
  PreferredSizeWidget _buildAnimatedAppBar() {
    return AppBar(
      elevation: 8,
      backgroundColor: Colors.black.withOpacity(0.7),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.cyan.withOpacity(0.1),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: Colors.cyan.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: const Icon(Icons.shield, color: Colors.cyan),
              );
            },
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: const Text(
                  'StealthSeal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        _buildAnimatedIconButton(Icons.camera_alt_outlined, 0),
        _buildAnimatedIconButton(Icons.settings_outlined, 1),
        _buildAnimatedIconButton(Icons.lock_outline, 2, onTap: () {
          Navigator.pushReplacementNamed(context, AppRoutes.lock);
        }),
      ],
    );
  }

  Widget _buildAnimatedIconButton(IconData icon, int index,
      {VoidCallback? onTap}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: IconButton(
            icon: Icon(icon, color: Colors.cyan),
            onPressed: onTap ?? () {},
          ),
        );
      },
    );
  }

  // 👋 Welcome Card with Animation
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.15),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Text(
                  'Your security dashboard is active and monitoring',
                  style: TextStyle(
                    color: Colors.cyan.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🔐 Security Status Card with Animated Indicators
  Widget _buildSecurityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnimatedStatusItem('0', 'Apps Locked', Colors.cyan, 0),
              _buildAnimatedStatusItem(
                getIntruderCount().toString(),
                'Intruders',
                Colors.redAccent,
                1,
              ),
              if (TimeLockService.isNightLockActive())
                _buildAnimatedStatusItem(
                  'ON',
                  'Night Lock',
                  Colors.orangeAccent,
                  2,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatusItem(
      String value, String label, Color color, int delay) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (delay * 150)),
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Opacity(
            opacity: animValue,
            child: Column(
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
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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

  // ⚡ Quick Actions Card
  Widget _buildQuickActionsCard(BuildContext context) {
    final actions = [
      // ✅ BIOMETRIC SWITCH
      _ActionItemData(
        icon: Icons.fingerprint,
        label: 'Biometric Unlock',
        description: 'Fingerprint or face ID',
        color: Colors.purple,
        isSwitch: true,
        onToggle: (value) async {
          if (value) {
            final supported = await BiometricService.isSupported();
            if (!supported) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometric not supported on this device'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
              return;
            }

            BiometricService.enable();

            try {
              final userId = await UserIdentifierService.getUserId();
              final supabase = Supabase.instance.client;
              await supabase.from('user_security').update({
                'biometric_enabled': true,
              }).eq('id', userId);
              debugPrint('✅ Biometric enabled in database for user: $userId');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(' Biometric unlocking enabled'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } catch (e) {
              debugPrint('❌ Error updating biometric in database: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          } else {
            BiometricService.disable();

            try {
              final userId = await UserIdentifierService.getUserId();
              final supabase = Supabase.instance.client;
              await supabase.from('user_security').update({
                'biometric_enabled': false,
              }).eq('id', userId);
              debugPrint('✅ Biometric disabled in database for user: $userId');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(' Biometric unlocking disabled'),
                    backgroundColor: Color.fromARGB(255, 255, 21, 0),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } catch (e) {
              debugPrint('❌ Error updating biometric in database: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          }
          setState(() {});
        },
      ),
      _ActionItemData(
        icon: Icons.apps,
        label: 'Manage App Locks',
        description: 'Manage protected apps',
        color: Colors.cyan,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AppLockManagementScreen(),
            ),
          );
        },
      ),
      _ActionItemData(
        icon: Icons.schedule,
        label: 'Time-Based Lock',
        description: 'Night mode protection',
        color: Colors.orangeAccent,
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.timeLockService);
        },
      ),
      _ActionItemData(
        icon: Icons.camera_alt,
        label: 'Intruder Logs',
        description: 'View captured images',
        color: Colors.redAccent,
        badge: getIntruderCount().toString(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const IntruderLogsScreen(),
            ),
          );
        },
      ),
      _ActionItemData(
        icon: Icons.location_on,
        label: 'Trusted Location',
        description: 'Set safe zone',
        color: Colors.greenAccent,
        onTap: () async {
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            LocationLockService.setTrustedLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              radius: 200,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Trusted location set (200m radius)'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Location error: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.05),
            Colors.cyan.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: actions[index].isSwitch
                    ? _buildAnimatedSwitchTile(actions[index])
                    : _buildAnimatedActionTile(actions[index]),
              );
            },
          ),
        ],
      ),
    );
  }

Widget _buildAnimatedSwitchTile(_ActionItemData action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            action.color.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: action.color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        tileColor: Colors.transparent,
        title: Text(
          action.label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          action.description,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        value: BiometricService.isEnabled(),
        activeColor: action.color,
        inactiveThumbColor: Colors.grey,
        onChanged: action.onToggle,
      ),
    );
  }

  Widget _buildAnimatedActionTile(_ActionItemData action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              action.color.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: action.color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    action.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
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
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  // 🚨 Emergency Card
  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.12),
            Colors.orange.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text(
                'Emergency Panic',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAnimatedPanicButton(context),
          const SizedBox(height: 12),
          Text(
            'Instantly locks all apps and displays security overlay. Only real PIN allows unlock.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPanicButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey.shade900,
              title: const Text('Confirm Panic Mode',
                  style: TextStyle(color: Colors.white)),
              content: const Text(
                'Activate panic mode? Your app will lock immediately and only respond to the real PIN.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.cyan)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () {
                    PanicService.activate();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(' Panic Mode Activated!'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Activate',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shadowColor: Colors.red.withOpacity(0.5),
        ),
        icon: const Icon(Icons.warning, color: Colors.white),
        label: const Text(
          'Activate Panic Lock',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }}

// Reusable data class for action items
class _ActionItemData {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;
  final Function(bool)? onToggle;
  final bool isSwitch;

  _ActionItemData({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    this.badge,
    this.onTap,
    this.onToggle,
    this.isSwitch = false,
  });
}