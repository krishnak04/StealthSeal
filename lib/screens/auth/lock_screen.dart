import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/intruder_service.dart';
import '../../widgets/pin_keypad.dart';
import '../../core/security/panic_service.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/time_lock_service.dart';
import '../../core/security/location_lock_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String enteredPin = '';
  String? realPin;
  String? decoyPin;
  bool _isLoading = true;
  int failedAttempts = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (PanicService.isActive()) {
        debugPrint('Panic Lock Active');
      }
      if (TimeLockService.isNightLockActive()) {
        debugPrint('Time Lock Active');
      }
      if (await LocationLockService.isOutsideTrustedLocation()) {
        debugPrint('Location Lock Active');
      }
    });

    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('user_security')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        if (data != null) {
          realPin = data['real_pin'];
          decoyPin = data['decoy_pin'];
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading PINs: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onKeyPress(String value) {
    if (_isLoading || realPin == null) return;
    if (enteredPin.length >= 4) return;

    setState(() => enteredPin += value);

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
    if (realPin == null || decoyPin == null) return;

    // 📍 LOCATION LOCK
    if (await LocationLockService.isOutsideTrustedLocation()) {
      _handleRestrictedUnlock('Location Lock active. Enter real PIN.');
      return;
    }

    // ⏰ TIME LOCK
    if (TimeLockService.isNightLockActive()) {
      _handleRestrictedUnlock('Time Lock active. Enter real PIN.');
      return;
    }

    // 🚨 PANIC LOCK
    if (PanicService.isActive()) {
      _handleRestrictedUnlock(
        'Panic Lock active. Enter real PIN.',
        deactivatePanic: true,
      );
      return;
    }

    // 🔐 NORMAL MODE
    if (enteredPin == realPin) {
      failedAttempts = 0;
      Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
    } else if (enteredPin == decoyPin) {
      failedAttempts = 0;
      Navigator.pushReplacementNamed(context, AppRoutes.fakeDashboard);
    } else {
      await _handleWrongPin();
    }

    setState(() => enteredPin = '');
  }

  Future<void> _handleRestrictedUnlock(
    String message, {
    bool deactivatePanic = false,
  }) async {
    if (enteredPin == realPin) {
      if (deactivatePanic) {
        PanicService.deactivate();
      }
      Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    setState(() => enteredPin = '');
  }

  Future<void> _handleWrongPin() async {
    failedAttempts++;

    // Show Toast immediately for wrong PIN
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failedAttempts >= 3
              ? 'Unauthorized access. Intruder captured.'
              : 'Wrong PIN (${3 - failedAttempts} attempts left)',
        ),
        backgroundColor:
            failedAttempts >= 3 ? Colors.white : Colors.orangeAccent,
        duration: const Duration(seconds: 1),
      ),
    );

    // Capture intruder in background if needed (doesn't block Toast)
    if (failedAttempts >= 3) {
      failedAttempts = 0;
      await IntruderService.captureIntruderSelfie(
        enteredPin: enteredPin,
      );
    }
  }

  // ✅ BIOMETRIC AUTH
  Future<void> _authenticateWithBiometrics() async {
    try {
      final ok = await BiometricService.authenticate();
      if (!ok || !mounted) return;

      if (PanicService.isActive() ||
          TimeLockService.isNightLockActive() ||
          await LocationLockService.isOutsideTrustedLocation()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN required due to security lock'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
    } catch (e) {
      debugPrint('Biometric error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (PanicService.isActive())
                      _lockBanner('PANIC LOCK ACTIVE', Colors.redAccent),
                    if (TimeLockService.isNightLockActive())
                      _lockBanner('TIME LOCK ACTIVE', Colors.orangeAccent),
                    FutureBuilder<bool>(
                      future:
                          LocationLockService.isOutsideTrustedLocation(),
                      builder: (_, snap) => snap.data == true
                          ? _lockBanner(
                              'LOCATION LOCK ACTIVE', Colors.greenAccent)
                          : const SizedBox.shrink(),
                    ),

                    const Text(
                      'Enter the PIN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Unlock to access StealthSeal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Icon(Icons.lock, size: 60, color: Colors.cyan),
                    const SizedBox(height: 30),
                    _pinDots(),
                    const SizedBox(height: 16),
                    _biometricButton(),
                    const SizedBox(height: 30),

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

  Widget _lockBanner(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _pinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < enteredPin.length
                ? Colors.cyan
                : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _biometricButton() {
    return FutureBuilder<bool>(
      future: BiometricService.isSupported(),
      builder: (_, snap) {
        if (snap.data == true &&
            BiometricService.isEnabled() &&
            !PanicService.isActive() &&
            !TimeLockService.isNightLockActive()) {
          return IconButton(
            icon: const Icon(Icons.fingerprint, size: 36),
            color: Colors.cyan,
            onPressed: _authenticateWithBiometrics,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
