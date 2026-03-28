import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/intruder_service.dart';
import '../../widgets/pin_keypad.dart';
import '../../widgets/pattern_lock_widget.dart';
import '../../core/security/panic_service.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/time_lock_service.dart';
import '../../core/security/location_lock_service.dart';
import '../../core/services/user_identifier_service.dart';
import '../../core/theme/theme_config.dart';
import '../../utils/hive_keys.dart';

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
  bool _biometricEnabled = false;
  bool _biometricSupported = false;
  int _pinLength = 4;
  String _unlockMode = '4-digit'; // '4-digit', '6-digit', or 'pattern'
  
  // Time lock countdown timer
  Timer? _countdownTimer;
  String _timeRemaining = '00:00:00';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (PanicService.isActive()) {
        debugPrint('Panic Lock Active');
      }
      if (TimeLockService.isNightLockActive()) {
        debugPrint('Time Lock Active - Starting countdown timer');
        _updateTimeRemaining();
        _startCountdownTimer();
      }
      if (await LocationLockService.isOutsideTrustedLocation()) {
        debugPrint('Location Lock Active');
      }
    });

    _loadPins();
  }

  void _updateTimeRemaining() {
    final securityBox = Hive.box('security');
    
    final startHourValue = securityBox.get(HiveKeys.nightStartHour, defaultValue: 0);
    final startMinuteValue = securityBox.get(HiveKeys.nightStartMinute, defaultValue: 0);
    final endHourValue = securityBox.get(HiveKeys.nightEndHour, defaultValue: 6);
    final endMinuteValue = securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0);
    
    final startHour = (startHourValue is int) ? startHourValue : (startHourValue as num).toInt();
    final startMinute = (startMinuteValue is int) ? startMinuteValue : (startMinuteValue as num).toInt();
    final endHour = (endHourValue is int) ? endHourValue : (endHourValue as num).toInt();
    final endMinute = (endMinuteValue is int) ? endMinuteValue : (endMinuteValue as num).toInt();
    
    debugPrint('🕐 Timer Debug - Start: $startHour:${startMinute.toString().padLeft(2, '0')}, End: $endHour:${endMinute.toString().padLeft(2, '0')}');
    
    final now = DateTime.now();
    final currentSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    final startSeconds = startHour * 3600 + startMinute * 60;
    final endSeconds = endHour * 3600 + endMinute * 60;
    
    debugPrint('🕐 Current: ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (${currentSeconds}s)');
    debugPrint('🕐 Start: ${(startSeconds~/3600)}:${((startSeconds%3600)~/60).toString().padLeft(2, '0')} ($startSeconds s)');
    debugPrint('🕐 End: ${(endSeconds~/3600)}:${((endSeconds%3600)~/60).toString().padLeft(2, '0')} ($endSeconds s)');
    
    int secondsRemaining = 0;
    
    // Handle same-day quick lock (e.g., 14:05 to 14:10)
    if (endSeconds > startSeconds && currentSeconds >= startSeconds && currentSeconds < endSeconds) {
      debugPrint('✅ Same-day lock: Current is between start and end');
      secondsRemaining = endSeconds - currentSeconds;
    }
    // Handle overnight lock (e.g., 22:00 to 06:00)
    else if (endSeconds < startSeconds) {
      debugPrint('🌙 Overnight lock detected');
      if (currentSeconds >= startSeconds) {
        debugPrint('✅ After start time (towards midnight)');
        secondsRemaining = (24 * 3600) - currentSeconds + endSeconds;
      } else if (currentSeconds < endSeconds) {
        debugPrint('✅ After midnight, before end time');
        secondsRemaining = endSeconds - currentSeconds;
      }
    }
    else {
      debugPrint('⚠️ No lock condition met - endSeconds: $endSeconds, startSeconds: $startSeconds, currentSeconds: $currentSeconds');
    }
    
    debugPrint('🕐 Seconds remaining: $secondsRemaining');
    
    // Ensure non-negative value
    if (secondsRemaining < 0) {
      secondsRemaining = 0;
    }
    
    final hoursRemaining = (secondsRemaining ~/ 3600).toInt();
    final minsRemaining = ((secondsRemaining % 3600) ~/ 60).toInt();
    final secsRemaining = (secondsRemaining % 60).toInt();
    
    debugPrint('✨ Display time: ${hoursRemaining.toString().padLeft(2, '0')}:${minsRemaining.toString().padLeft(2, '0')}:${secsRemaining.toString().padLeft(2, '0')}');
    
    if (mounted) {
      setState(() {
        _timeRemaining = '${hoursRemaining.toString().padLeft(2, '0')}:${minsRemaining.toString().padLeft(2, '0')}:${secsRemaining.toString().padLeft(2, '0')}';
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TimeLockService.isNightLockActive()) {
        _updateTimeRemaining();
      } else {
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPins() async {
    try {
      final userId = await UserIdentifierService.getUserId();
      debugPrint('Loading PINs and security flags for user: $userId');

      // Load from Hive first as fallback
      final securityBox = Hive.box('securityBox');
      final localRealPin = securityBox.get('realPin', defaultValue: '') as String;
      final localDecoyPin = securityBox.get('decoyPin', defaultValue: '') as String;

      // Try Supabase but fall back to Hive if unreachable
      Map<String, dynamic>? data;
      try {
        final supabase = Supabase.instance.client;
        data = await supabase
            .from('user_security')
            .select()
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        debugPrint('Supabase data loaded: ${data != null}');
      } catch (supabaseError) {
        debugPrint('Supabase unreachable, using cached PINs: $supabaseError');
      }

      if (!mounted) return;

      final isSupported = await BiometricService.isSupported();

      bool biometricEnabled = false;
      if (data != null) {
        biometricEnabled = data['biometric_enabled'] as bool? ?? false;
        if (biometricEnabled) {
          BiometricService.enable();
          debugPrint('Biometric enabled from Supabase for user: $userId');
        } else {
          BiometricService.disable();
          debugPrint('Biometric disabled for user: $userId');
        }
      }

      // Load PIN length preference
      final pinPattern = Hive.box('securityBox').get('unlockPattern', defaultValue: '4-digit');
      final pinLen = pinPattern == '6-digit' ? 6 : 4;

      setState(() {
        _pinLength = pinLen;
        _unlockMode = pinPattern as String;
        if (data != null) {
          realPin = data['real_pin'];
          decoyPin = data['decoy_pin'];
          _biometricEnabled = biometricEnabled;
          _biometricSupported = isSupported;
          debugPrint(
              'PINs and security flags loaded from Supabase for user: $userId');

          // Update local cache with latest from server
          securityBox.put('realPin', data['real_pin'] ?? '');
          securityBox.put('decoyPin', data['decoy_pin'] ?? '');

          _cachePinsToNative(data['real_pin'], data['decoy_pin']);
        } else if (localRealPin.isNotEmpty && localDecoyPin.isNotEmpty) {
          // Offline fallback: use Hive-cached PINs
          realPin = localRealPin;
          decoyPin = localDecoyPin;
          _biometricEnabled = BiometricService.isEnabled();
          _biometricSupported = isSupported;
          debugPrint('PINs loaded from Hive cache (offline mode)');
        } else {
          debugPrint('No PIN data found anywhere for user: $userId');
          _biometricEnabled = false;
          _biometricSupported = isSupported;
        }
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading PINs: $error');
      // Last resort: try Hive
      try {
        final securityBox = Hive.box('securityBox');
        final localRealPin = securityBox.get('realPin', defaultValue: '') as String;
        final localDecoyPin = securityBox.get('decoyPin', defaultValue: '') as String;
        if (localRealPin.isNotEmpty && localDecoyPin.isNotEmpty && mounted) {
          setState(() {
            realPin = localRealPin;
            decoyPin = localDecoyPin;
            _biometricEnabled = BiometricService.isEnabled();
            _isLoading = false;
          });
          debugPrint('PINs loaded from Hive (error fallback)');
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cachePinsToNative(String? realPin, String? decoyPin) async {
    if (realPin == null || decoyPin == null) return;
    try {
      final securityBox = Hive.box('securityBox');
      final securityTimeBox = Hive.box('security');
      final unlockPattern = securityBox.get('unlockPattern', defaultValue: '4-digit');
      
      // Load location lock settings
      final locationLockEnabled = securityBox.get('locationLockEnabled', defaultValue: false) as bool;
      final trustedLat = securityBox.get('trustedLat', defaultValue: 0.0) as double;
      final trustedLng = securityBox.get('trustedLng', defaultValue: 0.0) as double;
      final trustedRadius = securityBox.get('trustedRadius', defaultValue: 200.0) as double;
      
      // Load time lock settings using correct HiveKeys
      final nightLockEnabled = securityTimeBox.get(HiveKeys.nightLockEnabled, defaultValue: false) as bool;
      final nightStartHour = securityTimeBox.get(HiveKeys.nightStartHour, defaultValue: 22) as int;
      final nightStartMinute = securityTimeBox.get(HiveKeys.nightStartMinute, defaultValue: 0) as int;
      final nightEndHour = securityTimeBox.get(HiveKeys.nightEndHour, defaultValue: 6) as int;
      final nightEndMinute = securityTimeBox.get(HiveKeys.nightEndMinute, defaultValue: 0) as int;
      
      const platform = MethodChannel('com.stealthseal.app/applock');
      await platform.invokeMethod('cachePins', {
        'real_pin': realPin,
        'decoy_pin': decoyPin,
        'unlock_pattern': unlockPattern,
        'location_lock_enabled': locationLockEnabled,
        'trusted_lat': trustedLat,
        'trusted_lng': trustedLng,
        'trusted_radius': trustedRadius,
        'night_lock_enabled': nightLockEnabled,
        'night_start_hour': nightStartHour,
        'night_start_minute': nightStartMinute,
        'night_end_hour': nightEndHour,
        'night_end_minute': nightEndMinute,
      });
      debugPrint('PINs, unlock pattern, location lock, and time lock settings cached to native SharedPreferences');
      debugPrint('  Location Lock: $locationLockEnabled (Trusted: $trustedLat, $trustedLng, Radius: $trustedRadius m)');
      debugPrint('  Time Lock: $nightLockEnabled ($nightStartHour:$nightStartMinute - $nightEndHour:$nightEndMinute)');
    } catch (error) {
      debugPrint('Warning: Failed to cache PINs to native: $error');
    }
  }

  void _onPatternCompleted(String pattern) {
    if (_isLoading || realPin == null) return;
    setState(() => enteredPin = pattern);
    _validatePin();
  }

  void _onKeyPress(String value) {
    if (_isLoading || realPin == null) return;
    if (enteredPin.length >= _pinLength) return;

    setState(() => enteredPin += value);

    if (enteredPin.length == _pinLength) {
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

    // Location Lock - COMPLETELY BLOCK ACCESS (highest priority - no PIN works outside trusted location)
    if (await LocationLockService.isOutsideTrustedLocation()) {
      if (!mounted) return;
      _handleLocationLockedBlock();
      return;
    }

    // Time Lock - COMPLETELY BLOCK ACCESS (no PIN can unlock)
    if (TimeLockService.isNightLockActive()) {
      if (!mounted) return;
      _handleTimeLockedBlock();
      return;
    }

    if (PanicService.isActive()) {
      if (!mounted) return;
      _handleRestrictedUnlock(
        'Panic Lock active. Enter real PIN.',
        deactivatePanic: true,
      );
      return;
    }

    if (enteredPin == realPin) {
      failedAttempts = 0;
      if (mounted) {
        setState(() => enteredPin = '');
        Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
      }
    } else if (enteredPin == decoyPin) {
      failedAttempts = 0;
      if (mounted) {
        setState(() => enteredPin = '');
        Navigator.pushReplacementNamed(context, AppRoutes.fakeDashboard);
      }
    } else {
      await _handleWrongPin();
    }
  }

  Future<void> _handleRestrictedUnlock(
    String message, {
    bool deactivatePanic = false,
  }) async {
    if (enteredPin == realPin) {
      if (deactivatePanic) {
        PanicService.deactivate();
      }
      if (mounted) {
        setState(() => enteredPin = '');
        Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ThemeConfig.errorColor(context),
          duration: const Duration(seconds: 2),
        ),
      );
      if (mounted) {
        setState(() => enteredPin = '');
      }
    }
  }

  Future<void> _handleLocationLockedBlock() async {
    // Location Lock is ACTIVE - completely block all access outside trusted location
    if (!await LocationLockService.isOutsideTrustedLocation()) {
      return;
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '📍 Location Lock Active. You are outside the trusted location. App cannot be unlocked here.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color.fromARGB(255, 255, 152, 0),
        duration: Duration(seconds: 3),
      ),
    );
    if (mounted) {
      setState(() => enteredPin = '');
    }
  }

  Future<void> _handleTimeLockedBlock() async {
    // Time Lock is ACTIVE - completely block all access
    if (!TimeLockService.isNightLockActive()) {
      return;
    }
    
    _updateTimeRemaining();
    _startCountdownTimer();

    if (!mounted) return;
    if (mounted) {
      setState(() => enteredPin = '');
    }
  }

  Future<void> _handleWrongPin() async {
    failedAttempts++;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failedAttempts >= 3
              ? 'Unauthorized access. Intruder captured.'
              : 'Wrong PIN (${3 - failedAttempts} attempts left)',
        ),
        backgroundColor: failedAttempts >= 3
            ? ThemeConfig.errorColor(context)
            : ThemeConfig.accentColor(context).withValues(alpha: 0.8),
        duration: const Duration(seconds: 1),
      ),
    );

    if (failedAttempts >= 3) {
      failedAttempts = 0;
      await IntruderService.captureIntruderSelfie(
        enteredPin: enteredPin,
      );
    }

    if (mounted) {
      setState(() => enteredPin = '');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      // Check Location Lock FIRST - complete block outside trusted location
      if (await LocationLockService.isOutsideTrustedLocation()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Location Lock Active. Biometric access blocked outside trusted location.'),
            backgroundColor: Color.fromARGB(255, 255, 152, 0),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check Time Lock FIRST - complete block
      if (TimeLockService.isNightLockActive()) {
        if (!mounted) return;
        
        final securityBox = Hive.box('security');
final endHour = securityBox.get(HiveKeys.nightEndHour, defaultValue: 6);
      final endMinute = securityBox.get(HiveKeys.nightEndMinute, defaultValue: 0);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Time Lock Active 🔒\nApp locked until $endHour:${endMinute.toString().padLeft(2, '0')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final response = await BiometricService.authenticate();

      if (!mounted) return;

      debugPrint('Biometric response: $response');

      if (response['success'] != true) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(response['message'] ?? 'Biometric authentication failed'),
            backgroundColor: ThemeConfig.accentColor(context).withValues(alpha: 0.8),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      if (PanicService.isActive()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PIN required due to panic mode'),
            backgroundColor: ThemeConfig.accentColor(context).withValues(alpha: 0.8),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
    } catch (error) {
      debugPrint('Biometric error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
                      const Color(0xFF0a0e27).withValues(alpha: 0.98),
                      const Color(0xFF1a1a3e).withValues(alpha: 0.98),
                      const Color(0xFF0f0f2e).withValues(alpha: 0.98),
                    ],
                  ),
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                )
              : SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            if (PanicService.isActive())
                              _buildLockBanner(
                                  'PANIC LOCK ACTIVE', Colors.redAccent),
                            if (TimeLockService.isNightLockActive())
                              _buildLockBanner(
                                  'TIME LOCK ACTIVE', Colors.orangeAccent),
                            FutureBuilder<bool>(
                              future:
                                  LocationLockService.isOutsideTrustedLocation(),
                              builder: (_, snap) => snap.data == true
                                  ? _buildLockBanner(
                                      'LOCATION LOCK ACTIVE - OUTSIDE TRUSTED ZONE', Colors.redAccent)
                                  : const SizedBox.shrink(),
                            ),

                            _buildLogo(),

                            Text(
                              _unlockMode == 'pattern'
                                  ? 'Draw Pattern'
                                  : (_biometricSupported && _biometricEnabled
                                      ? 'Enter the PIN'
                                      : 'Enter the PIN'),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.textPrimary(context),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unlock to access StealthSeal',
                              style: TextStyle(
                                fontSize: 14,
                                color: ThemeConfig.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 24),

                            if (_unlockMode == 'pattern') ...[
                              _buildBiometricButton(),
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                  maxHeight: 320,
                                ),
                                child: PatternLockWidget(
                                  onPatternCompleted: _onPatternCompleted,
                                  onPatternTooShort: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Connect at least 4 dots'),
                                        backgroundColor: ThemeConfig.accentColor(context).withValues(alpha: 0.8),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  dotColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF555566)
                                      : Colors.grey[400]!,
                                  selectedColor: ThemeConfig.accentColor(context),
                                ),
                              ),
                            ]
                            else ...[
                              _buildTimeRemainingWidget(),
                              _buildPinDots(),
                              const SizedBox(height: 16),

                              _buildBiometricButton(),
                              const SizedBox(height: 30),

                              PinKeypad(
                                onKeyPressed: _onKeyPress,
                                onDelete: _onDelete,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Builder(
      builder: (context) {
        final accentColor = ThemeConfig.accentColor(context);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.3),
                accentColor.withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.lock,
            size: 60,
            color: accentColor,
          ),
        );
      },
    );
  }

  Widget _buildLockBanner(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTimeRemainingWidget() {
    if (!TimeLockService.isNightLockActive()) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 181, 66, 68).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 181, 66, 68).withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 181, 66, 68).withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '⏱️ Unlock Time Remaining',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color.fromARGB(255, 181, 66, 68),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _timeRemaining,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'monospace',
              color: Color.fromARGB(255, 181, 66, 68),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots() {
    final accentColor = ThemeConfig.accentColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pinLength,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < enteredPin.length
                ? accentColor
                : (isDark
                    ? Colors.grey.shade700.withValues(alpha: 0.5)
                    : Colors.grey[300]!.withValues(alpha: 0.7)),
            border: Border.all(
              color: i < enteredPin.length
                  ? accentColor.withValues(alpha: 0.6)
                  : (isDark
                      ? Colors.grey.shade600.withValues(alpha: 0.3)
                      : Colors.grey[400]!.withValues(alpha: 0.3)),
              width: 2,
            ),
            boxShadow: i < enteredPin.length
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    if (_biometricSupported &&
        _biometricEnabled &&
        !PanicService.isActive() &&
        !TimeLockService.isNightLockActive()) {
      final accentColor = ThemeConfig.accentColor(context);

      return GestureDetector(
        onTap: _authenticateWithBiometrics,
        onLongPress: _showBiometricTroubleshooting,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.2),
                    accentColor.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.fingerprint, size: 40),
                color: accentColor,
                onPressed: _authenticateWithBiometrics,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to unlock\nLong-press for help',
              style: TextStyle(
                fontSize: 11,
                color: accentColor,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showBiometricTroubleshooting() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.cardColor(context),
        title: Text(
          'Biometric Authentication Help',
          style: TextStyle(color: ThemeConfig.accentColor(ctx)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _troubleshootingSection(
                'Tips for Using Biometric:',
                [
                  '✓ Make sure the screen is ON and display is not locked',
                  '✓ For Fingerprint: Press firmly on the sensor area',
                  '✓ For Face: Position your face clearly in view',
                  '✓ Ensure good lighting for face recognition',
                  '✓ Keep your face/finger clean and dry',
                  '✓ Try multiple times if one attempt fails',
                ],
                ctx,
              ),
              const SizedBox(height: 16),
              _troubleshootingSection(
                'If Still Not Working:',
                [
                  '✓ Go to phone Settings → Biometrics',
                  '✓ Delete and re-enroll your fingerprint',
                  '✓ Test biometric in device settings first',
                  '✓ Restart the app and try again',
                  '✓ Use PIN unlock as fallback',
                ],
                ctx,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _testBiometricSensor,
            child: Text(
              'Test Sensor',
              style: TextStyle(color: ThemeConfig.accentColor(ctx)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(color: ThemeConfig.accentColor(ctx)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testBiometricSensor() async {
    try {
      final available = await BiometricService.getAvailableBiometrics();
      final isSupported = await BiometricService.isSupported();
      final faceSupported = await BiometricService.isFaceSupported();
      final fingerprintSupported =
          await BiometricService.isFingerprintSupported();

      if (!mounted) return;

      String biometricInfo =
          'Device Support: ${isSupported ? 'YES ✓' : 'NO ✗'}\n\n';
      biometricInfo += 'Available Biometric Types:\n';

      if (available.isEmpty) {
        biometricInfo += ' No biometric sensors detected\n\n';
        biometricInfo += 'Action: Enroll biometric in device settings';
      } else {
        for (var bio in available) {
          biometricInfo += '✓ $bio\n';
        }
        biometricInfo += '\nDetailed Status:\n';
        biometricInfo +=
            'Face Recognition: ${faceSupported ? ' ENABLED' : ' NOT AVAILABLE'}\n';
        biometricInfo +=
            'Fingerprint: ${fingerprintSupported ? ' ENABLED' : ' NOT AVAILABLE'}\n';
        biometricInfo +=
            '\nStatus:  Your device supports biometric authentication';
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThemeConfig.cardColor(ctx),
          title: Text(
            'Biometric Sensor Info',
            style: TextStyle(color: ThemeConfig.accentColor(ctx)),
          ),
          content: Text(
            biometricInfo,
            style: TextStyle(
                color: ThemeConfig.textSecondary(ctx), fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: TextStyle(color: ThemeConfig.accentColor(ctx)),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      debugPrint('Error testing biometric sensor: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: ThemeConfig.errorColor(context),
        ),
      );
    }
  }

  Widget _troubleshootingSection(
      String title, List<String> items, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: ThemeConfig.accentColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              item,
              style: TextStyle(
                color: ThemeConfig.textSecondary(context),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}