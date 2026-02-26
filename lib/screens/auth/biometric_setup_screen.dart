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

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Biometric Support Check
  // ---------------------------------------------------------------------------

  /// Queries the device for biometric hardware support and updates state.
  Future<void> _checkBiometricSupport() async {
    try {
      final isSupported = await BiometricService.isSupported();
      if (mounted) {
        setState(() {
          _isBiometricSupported = isSupported;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error checking biometric support: $error');
      if (mounted) {
        setState(() {
          _isBiometricSupported = false;
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Registration & Skip
  // ---------------------------------------------------------------------------

  /// Registers the user's biometric credential.
  ///
  /// Authenticates using the device sensor, then persists the enabled flag
  /// to Supabase and local storage. Navigates to the lock screen on success.
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
      final response = await BiometricService.authenticate();

      if (response['success'] != true) {
        if (mounted) {
          setState(() {
            _isRegistering = false;
            _statusMessage = response['message'] ?? 'Biometric authentication failed';
          });
        }
        return;
      }

      final userId = await UserIdentifierService.getUserId();
      debugPrint('Registering biometric for user: $userId');

      // Save biometric settings to Supabase
      final supabase = Supabase.instance.client;

      // Update by user ID
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
    } catch (error) {
      debugPrint('Error registering biometric: $error');
      if (mounted) {
        setState(() {
          _isRegistering = false;
          _statusMessage = 'Failed to register biometric';
        });
        _showError('Error: $error');
      }
    }
  }

  /// Skips biometric registration and navigates to the lock screen.
  ///
  /// Ensures the biometric flag is disabled both locally and in Supabase.
  Future<void> _skipBiometric() async {
    try {
      setState(() {
        _isRegistering = true;
        _statusMessage = 'Skipping biometric setup...';
      });

      // Ensure biometric is disabled
      BiometricService.disable();

      final userId = await UserIdentifierService.getUserId();
      debugPrint('Skipping biometric for user: $userId');

      // Update database to disable biometric
      final supabase = Supabase.instance.client;

      // Update by user ID
      await supabase.from('user_security').update({
        'biometric_enabled': false,
      }).eq('id', userId);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.lock);
    } catch (error) {
      debugPrint('Error skipping biometric setup: $error');
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
        _showError('Error: $error');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI Feedback
  // ---------------------------------------------------------------------------

  /// Shows a red [SnackBar] with the given error [message].
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
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
                  : SingleChildScrollView(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildIcon(),
                              const SizedBox(height: 24),
                              _buildTitle(),
                              const SizedBox(height: 12),
                              _buildSubtitle(),
                              const SizedBox(height: 32),
                              if (_statusMessage != null) _buildStatusMessage(),
                              _buildFeaturesList(),
                              const SizedBox(height: 40),
                              _buildButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Builders
  // ---------------------------------------------------------------------------

  /// Builds the circular fingerprint icon with a gradient glow.
  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.2),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        Icons.fingerprint,
        size: 80,
        color: _isBiometricSupported ? Colors.cyan : Colors.grey,
      ),
    );
  }

  /// Builds the screen title text.
  Widget _buildTitle() {
    return const Text(
      'Secure Your Account',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the descriptive subtitle based on device biometric support.
  Widget _buildSubtitle() {
    return Text(
      _isBiometricSupported
          ? 'Add biometric authentication for faster unlocking'
          : 'Biometric authentication not available on this device',
      style: const TextStyle(
        fontSize: 16,
        color: Colors.white70,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds a status banner indicating registration progress or result.
  Widget _buildStatusMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _biometricEnabled
              ? Colors.green.withOpacity(0.15)
              : Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _biometricEnabled
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          _statusMessage!,
          style: TextStyle(
            color: _biometricEnabled ? Colors.greenAccent : Colors.orangeAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Builds the list of biometric feature highlights.
  Widget _buildFeaturesList() {
    final features = [
      _FeatureData(
        Icons.bolt,
        'Faster Unlock',
        'Use your fingerprint or face to unlock quickly',
      ),
      _FeatureData(
        Icons.shield,
        'Extra Security',
        'Biometric data is stored securely on your device',
      ),
      _FeatureData(
        Icons.lock,
        'PIN Still Required',
        'Panic, time, and location locks still require PIN',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
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
        children: List.generate(
          features.length,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index < features.length - 1 ? 16 : 0),
            child: _buildFeatureItem(
              features[index].icon,
              features[index].title,
              features[index].description,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the action buttons (register, skip, or continue) based on
  /// the current biometric support and registration state.
  Widget _buildButtons() {
    if (_isBiometricSupported && !_biometricEnabled) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isRegistering ? null : _registerBiometric,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 8,
                shadowColor: Colors.cyan.withOpacity(0.5),
              ),
              child: _isRegistering
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: _isRegistering ? null : _skipBiometric,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
              ),
              child: const Text(
                'Skip for Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_biometricEnabled) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isRegistering
              ? null
              : () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.lock,
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 8,
            shadowColor: Colors.cyan.withOpacity(0.5),
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
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isRegistering ? null : _skipBiometric,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 8,
            shadowColor: Colors.cyan.withOpacity(0.5),
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
      );
    }
  }
  /// Builds a single feature row with an [icon], [title], and [description].
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.cyan,
            size: 24,
          ),
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
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  _FeatureData(this.icon, this.title, this.description);
}