import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/user_identifier_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _navigateToScreen(String routeName) async {
    debugPrint('🚀 Navigating to: $routeName');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  Future<void> _checkUserStatus() async {
    try {
      debugPrint('⏳ Starting user status check...');
      setState(() => _status = 'Checking registration...');

      // Wait 2 seconds for splash display
      await Future.delayed(const Duration(seconds: 2));

      // 🆔 Get user ID
      final userId = await UserIdentifierService.getUserId();
      debugPrint('👤 User ID: $userId');

      final supabase = Supabase.instance.client;
      debugPrint('📡 Connected to Supabase');

      setState(() => _status = 'Querying database...');
      debugPrint('🔍 Checking if user is registered...');

      // ✅ Query by specific user ID (not global broadcast)
      final existingUser = await supabase
          .from('user_security')
          .select()
          .eq('id', userId) // Query for THIS user only
          .maybeSingle();

      debugPrint('📊 Database response: $existingUser');

      if (!mounted) {
        debugPrint('⚠️ Widget unmounted, skipping navigation');
        return;
      }

      // If user has PINs saved, go to lock screen; otherwise go to setup
      if (existingUser != null) {
        debugPrint('✅ User registered - Navigating to Lock Screen');
        setState(() => _status = 'Redirecting to login...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _navigateToScreen(AppRoutes.lock);
      } else {
        debugPrint('🆕 New user - Navigating to Setup Screen');
        setState(() => _status = 'Starting registration...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _navigateToScreen(AppRoutes.setup);
      }
    } catch (e) {
      debugPrint('❌ Error checking user status: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      setState(() => _status = 'Error: $e\n\nDefaulting to setup...');

      // On error, wait 3 seconds then default to setup screen
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        debugPrint('⚠️ Defaulting to Setup Screen due to error');
        await _navigateToScreen(AppRoutes.setup);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/stealthseal_splash.json',
              width: 180,
              repeat: true,
            ),
            const SizedBox(height: 20),
            Text(
              'StealthSeal',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Privacy Guardian',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
