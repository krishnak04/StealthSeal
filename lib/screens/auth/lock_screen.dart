import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stealthseal/screens/dashboard/real_dashboard.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/intruder_service.dart';
import '../../widgets/pin_keypad.dart';
import '../../core/security/panic_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String enteredPin = '';
  String? realPin;
  String? decoyPin;
  bool _isLoading = true; // Added loading state
  int failedAttempts = 0;

  @override
  void initState() {
    super.initState();

    // If panic is active, ensure lock screen is enforced
    // Check after build to be safe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PanicService.isActive()) {
        // Stay on lock screen or show restricted UI
        debugPrint("Panic Mode Active");
      }
    });

    _loadPins(); // Supabase PIN loading
  }

  Future<void> _loadPins() async {
    try {
      final supabase = Supabase.instance.client;

      // Use maybeSingle() to avoid crashes if no row exists
      final data = await supabase
          .from('user_security')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (data != null) {
            realPin = data['real_pin'];
            decoyPin = data['decoy_pin'];
          } else {
            // Handle case where no PIN is set up yet (optional: nav to setup)
            debugPrint('No security PINs found in database.');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading PINs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading security settings')),
        );
      }
    }
  }

  void _onKeyPress(String value) {
    debugPrint('Key Pressed: $value');
    // Prevent typing if loading or if PINs failed to load
    if (_isLoading || realPin == null) return;
    if (enteredPin.length >= 4) return;

    setState(() {
      enteredPin += value;
    });

    if (enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onDelete() {
    if (enteredPin.isEmpty) return;

    setState(() {
      enteredPin = enteredPin.substring(0, enteredPin.length - 1);
    });
  }

  Future<void> _validatePin() async {
    // 1. Check consistency
    if (realPin == null || decoyPin == null) return;

    // 🚨 PANIC MODE CHECK
    if (PanicService.isActive()) {
      if (enteredPin == realPin) {
        // ✅ DEACTIVATE PANIC LOCK
        PanicService.deactivate();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Panic Lock deactivated'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          AppRoutes.realDashboard,
        );
      } else {
        // ❌ BLOCK ALL OTHER PINS
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Panic Lock active. Enter real PIN.'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Always reset PIN in panic mode
      setState(() => enteredPin = '');
      return;
    }

    // 🔐 NORMAL MODE VALIDATION
    if (enteredPin == realPin) {
      failedAttempts = 0;
      Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
    } else if (enteredPin == decoyPin) {
      failedAttempts = 0;
      Navigator.pushReplacementNamed(context, AppRoutes.fakeDashboard);
    } else {
      // 3. Handle Failure
      failedAttempts++;
      debugPrint('Failed Attempt: $failedAttempts');

      if (failedAttempts >= 3) {
        failedAttempts = 0; // Reset after capturing to avoid loop

        // Run capture in background or await depending on preference
        await IntruderService.captureIntruderSelfie();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthorized access. Intruder selfie captured.'),
            backgroundColor: Colors.white,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wrong PIN (${3 - failedAttempts} attempts left)'),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }

    // 4. Reset Input
    setState(() {
      enteredPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 🚫 Disable back button
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // PANIC MODE INDICATOR
                    if (PanicService.isActive())
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'PANIC LOCK ACTIVE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 18,
                          ),
                        ),
                      ),

                    const Icon(Icons.lock, size: 60, color: Colors.cyan),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter PIN',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unlock to access your apps',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 30),

                    // PIN DOTS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < enteredPin.length
                                ? Colors.cyan
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // KEYPAD
                    PinKeypad(
                      onKeyPressed: _onKeyPress,
                      onDelete: _onDelete,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}