import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/security/intruder_service.dart';
import '../../core/services/user_identifier_service.dart';
import '../../widgets/pin_keypad.dart';

/// Full-screen PIN entry screen shown when a locked app is opened.
/// Looks and feels exactly like the main StealthSeal lock screen.
class AppLockPinScreen extends StatefulWidget {
  final String packageName;
  final String appName;

  const AppLockPinScreen({
    super.key,
    required this.packageName,
    required this.appName,
  });

  @override
  State<AppLockPinScreen> createState() => _AppLockPinScreenState();
}

class _AppLockPinScreenState extends State<AppLockPinScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.stealthseal.app/applock');

  String _enteredPin = '';
  String? _realPin;
  String? _decoyPin;
  int _failedAttempts = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  // ─── PIN Loading ───

  /// Load PINs from Supabase (same source as main lock screen)
  Future<void> _loadPins() async {
    try {
      final userId = await UserIdentifierService.getUserId();
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('user_security')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _realPin = data['real_pin'] as String?;
          _decoyPin = data['decoy_pin'] as String?;
          _isLoading = false;
        });
        debugPrint(
            'App Lock PIN Screen - PINs loaded from Supabase: real=${_realPin != null}, decoy=${_decoyPin != null}');
      } else {
        debugPrint('No PIN data found in Supabase for user: $userId');
        setState(() => _isLoading = false);
      }
    } catch (error) {
      debugPrint('Error loading PINs: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── PIN Input ───

  /// Handles a digit key press on the PIN keypad.
  void _onKeyPress(String value) {
    if (_isLoading || _realPin == null) return;
    if (_enteredPin.length >= 4) return;

    setState(() => _enteredPin += value);

    if (_enteredPin.length == 4) {
      _validatePin();
    }
  }

  /// Deletes the last digit from the entered PIN.
  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  // ─── PIN Validation ───

  /// Validates the entered PIN against stored real and decoy PINs.
  Future<void> _validatePin() async {
    if (_realPin == null || _decoyPin == null) return;

    if (_enteredPin == _realPin || _enteredPin == _decoyPin) {
      // Correct PIN - unlock the app
      _failedAttempts = 0;
      debugPrint('App unlocked: ${widget.packageName}');

      // Temporarily remove from locked apps so it can open
      _temporarilyUnlockApp(widget.packageName);

      // Launch the app
      try {
        await _channel.invokeMethod('launchApp', {
          'packageName': widget.packageName,
        });
        debugPrint('Launched app: ${widget.packageName}');
      } catch (error) {
        debugPrint('Error launching app: $error');
      }

      // Go back to dashboard
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      // Wrong PIN
      _failedAttempts++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _failedAttempts >= 3
                  ? 'Unauthorized access. Intruder captured.'
                  : 'Wrong PIN (${3 - _failedAttempts} attempts left)',
            ),
            backgroundColor: _failedAttempts >= 3
                ? ThemeConfig.errorColor(context)
                : ThemeConfig.accentColor(context).withOpacity(0.8),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Capture intruder on 3+ failed attempts
      if (_failedAttempts >= 3) {
        _failedAttempts = 0;
        await IntruderService.captureIntruderSelfie(
          enteredPin: _enteredPin,
        );
      }

      if (mounted) {
        setState(() => _enteredPin = '');
      }
    }
  }

  // ─── Temporary Unlock ───

  /// Temporarily unlocks an app for 5 seconds so the user can open it.
  void _temporarilyUnlockApp(String packageName) {
    final securityBox = Hive.box('securityBox');
    final List<String> temporarilyUnlockedApps = List<String>.from(
        securityBox.get('tempUnlockedApps', defaultValue: []) as List);
    if (!temporarilyUnlockedApps.contains(packageName)) {
      temporarilyUnlockedApps.add(packageName);
      securityBox.put('tempUnlockedApps', temporarilyUnlockedApps);
    }

    // Also sync to native SharedPreferences so AccessibilityService knows
    _syncTempUnlockedToNative(temporarilyUnlockedApps);

    // Re-lock after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      final securityBox = Hive.box('securityBox');
      final List<String> currentTempApps = List<String>.from(
          securityBox.get('tempUnlockedApps', defaultValue: []) as List);
      currentTempApps.remove(packageName);
      securityBox.put('tempUnlockedApps', currentTempApps);
      _syncTempUnlockedToNative(currentTempApps);
      debugPrint('Re-locked app after timeout: $packageName');
    });
  }

  /// Syncs the temporarily unlocked apps list to Android SharedPreferences.
  Future<void> _syncTempUnlockedToNative(List<String> apps) async {
    try {
      await _channel.invokeMethod('setTempUnlockedApps', {
        'apps': apps.join(','),
      });
    } catch (error) {
      debugPrint('Could not sync temp unlocked apps: $error');
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button bypass
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.light
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                      Colors.white,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0a0e27).withOpacity(0.98),
                      const Color(0xFF1a1a3e).withOpacity(0.98),
                      const Color(0xFF0f0f2e).withOpacity(0.98),
                    ],
                  ),
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Lock Icon
                        _buildLockIcon(),
                        const SizedBox(height: 20),

                        // App Name
                        Text(
                          '${widget.appName} is Locked',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeConfig.textPrimary(context),
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Enter StealthSeal PIN to unlock',
                          style: TextStyle(
                            fontSize: 14,
                            color: ThemeConfig.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // PIN Dots
                        _buildPinDots(),
                        const SizedBox(height: 30),

                        // Keypad
                        PinKeypad(
                          onKeyPressed: _onKeyPress,
                          onDelete: _onDelete,
                        ),
                        const SizedBox(height: 20),

                        // Failed attempts warning
                        if (_failedAttempts >= 2)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.warning_amber,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Multiple failed attempts detected',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ─── UI Components ───

  /// Lock icon with glow effect (same style as main lock screen)
  Widget _buildLockIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            ThemeConfig.accentColor(context).withOpacity(0.3),
            ThemeConfig.accentColor(context).withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: ThemeConfig.accentColor(context).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeConfig.accentColor(context).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        Icons.lock_rounded,
        size: 40,
        color: ThemeConfig.accentColor(context),
      ),
    );
  }

  /// PIN dots display (same style as main lock screen)
  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? ThemeConfig.accentColor(context)
                : Colors.transparent,
            border: Border.all(
              color: ThemeConfig.accentColor(context).withOpacity(0.5),
              width: 2,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: ThemeConfig.accentColor(context).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}
