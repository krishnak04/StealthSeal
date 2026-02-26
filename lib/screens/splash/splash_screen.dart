import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:hive/hive.dart';
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
    _requestAccessibilityService();
    _checkUserStatus();
  }

  Future<void> _requestAccessibilityService() async {
    try {
      const platform = MethodChannel('com.stealthseal.app/applock');

      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled');

      if (isEnabled == true) {
        debugPrint('Accessibility service already enabled, skipping prompt');
        return;
      }

      final securityBox = Hive.box('securityBox');
      final alreadyPrompted =
          securityBox.get('accessibility_prompt_shown', defaultValue: false) as bool;
      if (alreadyPrompted) {
        debugPrint('Accessibility prompt already shown before, skipping');
        return;
      }

      debugPrint('Showing accessibility permission dialog...');
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Enable Accessibility Service'),
                content: const Text(
                  'StealthSeal needs accessibility permission to protect your apps.\n\n'
                  'This allows the app to detect when you open locked apps and show the PIN screen.\n\n'
                  'You can enable it in Settings > Accessibility > StealthSeal',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      securityBox.put('accessibility_prompt_shown', true);
                    },
                    child: const Text('Maybe Later'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      try {
                        platform.invokeMethod('openAccessibilitySettings');
                        debugPrint('User confirmed - Opening accessibility settings');
                      } catch (error) {
                        debugPrint('Warning: Error opening accessibility settings: $error');
                      }
                      securityBox.put('accessibility_prompt_shown', true);
                    },
                    child: const Text('Enable Now'),
                  ),
                ],
              );
            },
          );
        }
      }

      await securityBox.put('accessibility_prompt_shown', true);
    } catch (error) {
      debugPrint('Accessibility request error: $error');
    }
  }

  Future<void> _navigateToScreen(String routeName) async {
    debugPrint('Navigating to: $routeName');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  Future<void> _checkUserStatus() async {
    try {
      debugPrint('Starting user status check...');
      setState(() => _status = 'Checking registration...');

      await Future.delayed(const Duration(seconds: 2));

      final userId = await UserIdentifierService.getUserId();
      debugPrint('User ID: $userId');

      // Check local Hive cache first for offline resilience
      final securityBox = Hive.box('securityBox');
      final isPinSetupDone = securityBox.get('isPinSetupDone', defaultValue: false) as bool;
      final localRealPin = securityBox.get('realPin', defaultValue: '') as String;
      final localDecoyPin = securityBox.get('decoyPin', defaultValue: '') as String;
      final hasLocalPins = localRealPin.isNotEmpty && localDecoyPin.isNotEmpty;

      debugPrint('Local check: isPinSetupDone=$isPinSetupDone, hasLocalPins=$hasLocalPins');

      try {
        final supabase = Supabase.instance.client;
        debugPrint('Connected to Supabase');

        setState(() => _status = 'Querying database...');
        debugPrint('Checking if user is registered...');

        final existingUser = await supabase
            .from('user_security')
            .select()
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));

        debugPrint('Database response: $existingUser');

        if (!mounted) return;

        if (existingUser != null) {

          securityBox.put('realPin', existingUser['real_pin'] ?? '');
          securityBox.put('decoyPin', existingUser['decoy_pin'] ?? '');
          securityBox.put('isPinSetupDone', true);

          debugPrint('User registered - Navigating to Lock Screen');
          setState(() => _status = 'Redirecting to login...');
          await Future.delayed(const Duration(milliseconds: 500));
          await _navigateToScreen(AppRoutes.lock);
        } else {
          debugPrint('New user - Navigating to Setup Screen');
          setState(() => _status = 'Starting registration...');
          await Future.delayed(const Duration(milliseconds: 500));
          await _navigateToScreen(AppRoutes.setup);
        }
        return;
      } catch (supabaseError) {
        debugPrint('Supabase unreachable: $supabaseError');
      }

      if (!mounted) return;

      if (isPinSetupDone && hasLocalPins) {
        debugPrint('Using cached PINs — Navigating to Lock Screen (offline mode)');
        setState(() => _status = 'Offline mode — using cached data...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _navigateToScreen(AppRoutes.lock);
      } else {
        debugPrint('No cached PINs — Navigating to Setup Screen');
        setState(() => _status = 'Starting registration...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _navigateToScreen(AppRoutes.setup);
      }
    } catch (error) {
      debugPrint('Error checking user status: $error');
      debugPrint('Stack trace: ${StackTrace.current}');

      try {
        final securityBox = Hive.box('securityBox');
        final isPinSetupDone = securityBox.get('isPinSetupDone', defaultValue: false) as bool;
        final localRealPin = securityBox.get('realPin', defaultValue: '') as String;

        if (isPinSetupDone && localRealPin.isNotEmpty && mounted) {
          debugPrint('Fallback: cached PINs found — going to Lock Screen');
          setState(() => _status = 'Offline mode...');
          await Future.delayed(const Duration(milliseconds: 500));
          await _navigateToScreen(AppRoutes.lock);
          return;
        }
      } catch (_) {}

      setState(() => _status = 'Connection error. Starting setup...');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        debugPrint('Defaulting to Setup Screen due to error');
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
