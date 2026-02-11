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
  late AnimationController _controller;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Staggered card animations
    _cardAnimations = List.generate(
      5,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.1,
            (index * 0.1) + 0.4,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    _controller.forward();

    // 🔐 Enforce Night Lock immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TimeLockService.isNightLockActive()) {
        Navigator.pushReplacementNamed(context, AppRoutes.lock);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 90, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnimatedCard(0, _buildWelcomeCard()),
              const SizedBox(height: 24),
              _buildAnimatedCard(1, _buildSecurityStatusCard()),
              const SizedBox(height: 24),
              _buildAnimatedCard(2, _buildSecurityHealthCard()),
              const SizedBox(height: 24),
              _buildAnimatedCard(3, _buildQuickActionsCard(context)),
              const SizedBox(height: 24),
              _buildAnimatedCard(4, _buildEmergencyCard(context)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 AppBar
  PreferredSizeWidget _buildAppBar() {
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
          const Icon(Icons.shield, color: Colors.cyan),
          const SizedBox(width: 12),
          const Text(
            'StealthSeal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined, color: Colors.cyan),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.cyan),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.lock_outline, color: Colors.cyan),
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.lock);
          },
        ),
      ],
    );
  }



  // 👋 Welcome Card
  Widget _buildAnimatedCard(int index, Widget child) {
    return FadeTransition(
      opacity: _cardAnimations[index],
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - _cardAnimations[index].value)),
        child: child,
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.2),
            Colors.blue.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your security dashboard is active and monitoring',
            style: TextStyle(
              color: Colors.cyan.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text(
                  'All Systems Secure',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // �️ Security Health Card (New Feature)
  Widget _buildSecurityHealthCard() {
    final panicActive = PanicService.isActive();
    final nightLockActive = TimeLockService.isNightLockActive();
    final biometricEnabled = BiometricService.isEnabled();

    int securityScore = 0;
    if (biometricEnabled) securityScore += 25;
    if (nightLockActive) securityScore += 25;
    if (panicActive) securityScore += 25;
    securityScore += 25; // Base score

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.15),
            Colors.indigo.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurple.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Security Health',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$securityScore%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: securityScore / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(
                securityScore >= 75 ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHealthBadge('Biometric', biometricEnabled, Icons.fingerprint),
              _buildHealthBadge('Night Lock', nightLockActive, Icons.nights_stay),
              _buildHealthBadge('Panic Ready', panicActive, Icons.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String label, bool active, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (active ? Colors.green : Colors.grey).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (active ? Colors.green : Colors.grey).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // �🔐 Security Status Card
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
              _buildStatusItem('0', 'Apps Locked', Colors.cyan),
              _buildStatusItem(
                getIntruderCount().toString(),
                'Intruders',
                Colors.redAccent,
              ),
              if (TimeLockService.isNightLockActive())
                _buildStatusItem(
                  'ON',
                  'Night Lock',
                  Colors.orangeAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String value, String label, Color color) {
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
            Colors.blue.withOpacity(0.08),
            Colors.cyan.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
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
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              return actions[index].isSwitch
                  ? _buildSwitchTile(actions[index])
                  : _buildActionTile(actions[index]);
            },
          ),
        ],
      ),
    );
  }

Widget _buildSwitchTile(_ActionItemData action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            action.color.withOpacity(0.12),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: action.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: action.color.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
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

  Widget _buildActionTile(_ActionItemData action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              action.color.withOpacity(0.12),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: action.color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: action.color.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
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
            Colors.red.withOpacity(0.15),
            Colors.orange.withOpacity(0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_rounded, color: Colors.red.shade300, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Emergency Panic',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanicButton(context),
          const SizedBox(height: 14),
          Text(
            'Instantly locks all apps and displays security overlay. Only real PIN allows unlock.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanicButton(BuildContext context) {
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Colors.red,
                  width: 1.5,
                ),
              ),
              title: const Text('Confirm Panic Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )),
              content: const Text(
                'Activate panic mode? Your app will lock immediately and only respond to the real PIN.',
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    PanicService.activate();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          ' Panic Mode Activated!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        backgroundColor: Colors.red.shade600,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    );
                  },
                  child: const Text('Activate',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shadowColor: Colors.red.withOpacity(0.6),
        ),
        icon: const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Activate Panic Lock',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.3,
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