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

class _BiometricSetupScreenState extends State<BiometricSetupScreen>
    with SingleTickerProviderStateMixin {
  bool _isBiometricSupported = false;
  bool _isRegistering = false;
  bool _biometricEnabled = false;
  String? _statusMessage;
  bool _isLoading = true;
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

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _checkBiometricSupport();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final isSupported = await BiometricService.isSupported();
      if (mounted) {
        setState(() {
          _isBiometricSupported = isSupported;
          _isLoading = false;
        });
        // Start animations after loading is complete
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
      if (mounted) {
        setState(() {
          _isBiometricSupported = false;
          _isLoading = false;
        });
        _animationController.forward();
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
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 👆 Animated Fingerprint Icon
                              _buildAnimatedIcon(),
                              const SizedBox(height: 24),

                              // 📝 Title
                              _buildAnimatedTitle(),
                              const SizedBox(height: 12),

                              // 📄 Subtitle
                              _buildAnimatedSubtitle(),
                              const SizedBox(height: 32),

                              // ✅ Status Message
                              if (_statusMessage != null)
                                _buildAnimatedStatusMessage(),

                              // 📋 Features List
                              _buildAnimatedFeaturesList(),
                              const SizedBox(height: 40),

                              // 🔘 Buttons
                              _buildAnimatedButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // 👆 Animated Icon with Pulse
  Widget _buildAnimatedIcon() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
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
          ),
        );
      },
    );
  }

  // 📝 Animated Title
  Widget _buildAnimatedTitle() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: const Text(
        'Secure Your Account',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // 📄 Animated Subtitle
  Widget _buildAnimatedSubtitle() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: Text(
        _isBiometricSupported
            ? 'Add biometric authentication for faster unlocking'
            : 'Biometric authentication not available on this device',
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white70,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ✅ Animated Status Message
  Widget _buildAnimatedStatusMessage() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
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
      ),
    );
  }

  // 📋 Animated Features List
  Widget _buildAnimatedFeaturesList() {
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
          (index) => TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 600 + (index * 150)),
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
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index < features.length - 1 ? 16 : 0,
              ),
              child: _buildFeatureItem(
                features[index].icon,
                features[index].title,
                features[index].description,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔘 Animated Buttons
  Widget _buildAnimatedButtons() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildButtons(),
    );
  }

  // 🔘 Button Logic
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