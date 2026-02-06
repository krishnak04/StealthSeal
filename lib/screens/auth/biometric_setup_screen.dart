import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/biometric_service.dart';
import '../../core/services/user_identifier_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isBiometricSupported = false;
  bool _isRegistering = false;
  bool _biometricEnabled = false;
  String? _statusMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final isSupported = await BiometricService.isSupported();
      if (mounted) {
        setState(() {
          _isBiometricSupported = isSupported;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
      if (mounted) {
        setState(() {
          _isBiometricSupported = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerBiometric() async {
    if (!_isBiometricSupported) {
      _showError('Biometric not supported on this device');
      return;
    }

    setState(() {
      _isRegistering = true;
      _statusMessage = 'Authenticating with biometric...';
    });

    try {
      // Attempt biometric authentication
      final isAuthenticated = await BiometricService.authenticate();

      if (!isAuthenticated) {
        if (mounted) {
          setState(() {
            _isRegistering = false;
            _statusMessage = 'Biometric authentication cancelled';
          });
        }
        return;
      }

      // 🆔 Get user ID
      final userId = await UserIdentifierService.getUserId();
      debugPrint('📱 Registering biometric for user: $userId');

      // Save biometric settings to Supabase
      final supabase = Supabase.instance.client;

      // ✅ Update by user ID (not auth user)
      await supabase.from('user_security').update({
        'biometric_enabled': true,
      }).eq('id', userId);

      // Enable biometric in local service
      BiometricService.enable();

      if (!mounted) return;

      setState(() {
        _isRegistering = false;
        _statusMessage = 'Biometric registered successfully! ✓';
        _biometricEnabled = true;
      });

      // Navigate to lock screen after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.lock);
      }
    } catch (e) {
      debugPrint('Error registering biometric: $e');
      if (mounted) {
        setState(() {
          _isRegistering = false;
          _statusMessage = 'Failed to register biometric';
        });
        _showError('Error: $e');
      }
    }
  }

  Future<void> _skipBiometric() async {
    try {
      setState(() {
        _isRegistering = true;
        _statusMessage = 'Skipping biometric setup...';
      });

      // Ensure biometric is disabled
      BiometricService.disable();

      // 🆔 Get user ID
      final userId = await UserIdentifierService.getUserId();
      debugPrint('⏭️ Skipping biometric for user: $userId');

      // Update database to disable biometric
      final supabase = Supabase.instance.client;

      // ✅ Update by user ID (not auth user)
      await supabase.from('user_security').update({
        'biometric_enabled': false,
      }).eq('id', userId);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.lock);
    } catch (e) {
      debugPrint('Error skipping biometric setup: $e');
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
        _showError('Error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              )
            : SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ICON
                        Icon(
                          Icons.fingerprint,
                          size: 80,
                          color: _isBiometricSupported
                              ? Colors.cyan
                              : Colors.grey,
                        ),
                        const SizedBox(height: 24),

                        // TITLE
                        Text(
                          'Secure Your Account',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // SUBTITLE
                        Text(
                          _isBiometricSupported
                              ? 'Add biometric authentication for faster unlocking'
                              : 'Biometric authentication not available on this device',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // STATUS MESSAGE
                        if (_statusMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _biometricEnabled
                                    ? Colors.green.shade900
                                    : Colors.orange.shade900,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  color: _biometricEnabled
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        // FEATURES LIST
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _featureItem(
                                Icons.bolt,
                                'Faster Unlock',
                                'Use your fingerprint or face to unlock quickly',
                              ),
                              const SizedBox(height: 16),
                              _featureItem(
                                Icons.shield,
                                'Extra Security',
                                'Biometric data is stored securely on your device',
                              ),
                              const SizedBox(height: 16),
                              _featureItem(
                                Icons.lock,
                                'PIN Still Required',
                                'Panic, time, and location locks still require PIN',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // REGISTER BUTTON
                        if (_isBiometricSupported && !_biometricEnabled)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isRegistering
                                      ? null
                                      : _registerBiometric,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isRegistering
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Register Biometric',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _isRegistering ? null : _skipBiometric,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text(
                                    'Skip for Now',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (_biometricEnabled)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isRegistering
                                  ? null
                                  : () => Navigator.pushReplacementNamed(
                                        context,
                                        AppRoutes.lock,
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue to Lock Screen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isRegistering
                                  ? null
                                  : _skipBiometric,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue to Lock Screen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
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

  Widget _featureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.cyan,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
