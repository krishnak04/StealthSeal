import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/services/user_identifier_service.dart';

enum SixDigitStep {
  currentPin,
  newRealPin,
  confirmRealPin,
  newDecoyPin,
  confirmDecoyPin,
}

class SixDigitPinScreen extends StatefulWidget {
  final int targetPinLength;

  const SixDigitPinScreen({super.key, this.targetPinLength = 6});

  @override
  State<SixDigitPinScreen> createState() => _SixDigitPinScreenState();
}

class _SixDigitPinScreenState extends State<SixDigitPinScreen>
    with SingleTickerProviderStateMixin {
  SixDigitStep _step = SixDigitStep.currentPin;

  String _enteredPin = '';
  String _newRealPin = '';
  String _confirmRealPin = '';
  String _newDecoyPin = '';

  String? _currentRealPin;
  String? _currentDecoyPin;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _showError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
    _loadCurrentPins();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPins() async {
    try {
      final securityBox = Hive.box('securityBox');
      _currentRealPin = securityBox.get('realPin', defaultValue: '') as String;
      _currentDecoyPin = securityBox.get('decoyPin', defaultValue: '') as String;

      if (_currentRealPin!.isEmpty || _currentDecoyPin!.isEmpty) {
        final userId = await UserIdentifierService.getUserId();
        final response = await Supabase.instance.client
            .from('user_security')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          _currentRealPin = response['real_pin'] ?? '';
          _currentDecoyPin = response['decoy_pin'] ?? '';
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      debugPrint('Error loading current pins: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _targetLen => widget.targetPinLength;

  int get _currentPinMaxLength {
    // Determine max length of the current PINs (could be 4 or 6)
    final realLen = _currentRealPin?.length ?? 4;
    final decoyLen = _currentDecoyPin?.length ?? 4;
    return realLen > decoyLen ? realLen : decoyLen;
  }

  void _onKeyPress(String value) {
    if (_isSaving || _isLoading) return;
    final maxLen = _step == SixDigitStep.currentPin ? _currentPinMaxLength : _targetLen;
    if (_enteredPin.length >= maxLen) return;

    setState(() {
      _enteredPin += value;
      _showError = false;
    });

    // Auto-validate when input reaches the required length
    if (_enteredPin.length == maxLen) {
      _processStep();
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _showError = false;
    });
  }

  void _processStep() {
    switch (_step) {
      case SixDigitStep.currentPin:
        if (_enteredPin == _currentRealPin ||
            _enteredPin == _currentDecoyPin) {
          setState(() {
            _step = SixDigitStep.newRealPin;
            _enteredPin = '';
          });
        } else {
          _triggerError('Wrong PIN. Try again.');
        }
        break;

      case SixDigitStep.newRealPin:
        _newRealPin = _enteredPin;
        setState(() {
          _step = SixDigitStep.confirmRealPin;
          _enteredPin = '';
        });
        break;

      case SixDigitStep.confirmRealPin:
        _confirmRealPin = _enteredPin;
        if (_confirmRealPin != _newRealPin) {
          _triggerError('PINs do not match. Try again.');
          setState(() {
            _step = SixDigitStep.newRealPin;
            _newRealPin = '';
            _confirmRealPin = '';
          });
        } else {
          setState(() {
            _step = SixDigitStep.newDecoyPin;
            _enteredPin = '';
          });
        }
        break;

      case SixDigitStep.newDecoyPin:
        _newDecoyPin = _enteredPin;
        if (_newDecoyPin == _newRealPin) {
          _triggerError('Decoy PIN must differ from real PIN.');
          setState(() {
            _newDecoyPin = '';
          });
        } else {
          setState(() {
            _step = SixDigitStep.confirmDecoyPin;
            _enteredPin = '';
          });
        }
        break;

      case SixDigitStep.confirmDecoyPin:
        if (_enteredPin != _newDecoyPin) {
          _triggerError('PINs do not match. Try again.');
          setState(() {
            _step = SixDigitStep.newDecoyPin;
            _newDecoyPin = '';
          });
        } else {
          _saveNewPins();
        }
        break;
    }
  }

  void _triggerError(String message) {
    _shakeController.forward();
    setState(() {
      _enteredPin = '';
      _showError = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveNewPins() async {
    setState(() => _isSaving = true);

    try {
      final userId = await UserIdentifierService.getUserId();

      // Save to Hive
      final securityBox = Hive.box('securityBox');
      await securityBox.put('realPin', _newRealPin);
      await securityBox.put('decoyPin', _newDecoyPin);
      await securityBox.put('unlockPattern', '$_targetLen-digit');
      debugPrint('$_targetLen-digit PINs saved to Hive');

      // Cache to native SharedPreferences
      try {
        const platform = MethodChannel('com.stealthseal.app/applock');
        await platform.invokeMethod('cachePins', {
          'real_pin': _newRealPin,
          'decoy_pin': _newDecoyPin,
        });
        debugPrint('$_targetLen-digit PINs cached to native');
      } catch (error) {
        debugPrint('Warning: Failed to cache PINs: $error');
      }

      // Sync to Supabase (upsert to handle missing rows)
      try {
        await Supabase.instance.client
            .from('user_security')
            .upsert(
              {
                'id': userId,
                'real_pin': _newRealPin,
                'decoy_pin': _newDecoyPin,
              },
              onConflict: 'id',
            );
        debugPrint('$_targetLen-digit PINs synced to Supabase');
      } catch (supabaseError) {
        debugPrint('WARNING: Supabase sync failed: $supabaseError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Warning: PINs saved locally but cloud sync failed. '
                'Check Supabase RLS policies.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (!mounted) return;

      _showSuccessDialog();
    } catch (error) {
      debugPrint('Error saving $_targetLen-digit PINs: $error');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save PINs. Please try again.'),
            backgroundColor: ThemeConfig.errorColor(context),
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.cardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text(
              'PIN Changed to $_targetLen-digit!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your real PIN and decoy PIN have been updated to $_targetLen digits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeConfig.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    Navigator.pop(context, true); // Return true to indicate success
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.accentColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: ThemeConfig.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (_step) {
      case SixDigitStep.currentPin:
        return 'Enter Current PIN';
      case SixDigitStep.newRealPin:
        return 'Set New Real PIN';
      case SixDigitStep.confirmRealPin:
        return 'Confirm Real PIN';
      case SixDigitStep.newDecoyPin:
        return 'Set New Decoy PIN';
      case SixDigitStep.confirmDecoyPin:
        return 'Confirm Decoy PIN';
    }
  }

  String get _subtitle {
    switch (_step) {
      case SixDigitStep.currentPin:
        return 'Enter your current PIN';
      case SixDigitStep.newRealPin:
        return 'Enter a $_targetLen-digit real PIN';
      case SixDigitStep.confirmRealPin:
        return 'Re-enter your real PIN';
      case SixDigitStep.newDecoyPin:
        return 'Enter a $_targetLen-digit decoy PIN';
      case SixDigitStep.confirmDecoyPin:
        return 'Re-enter your decoy PIN';
    }
  }

  int get _dotCount {
    return _step == SixDigitStep.currentPin ? _currentPinMaxLength : _targetLen;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1a1a2e) : const Color(0xFF2d2d2d),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: ThemeConfig.accentColor(context),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Top bar with back button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Step indicator
                          if (_step != SixDigitStep.currentPin)
                            _buildStepIndicator(),

                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _subtitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // PIN dots
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  _shakeAnimation.value *
                                      (_shakeController.isAnimating
                                          ? ((_shakeController.value * 10).toInt() % 2 == 0
                                              ? 1
                                              : -1)
                                          : 0),
                                  0,
                                ),
                                child: child,
                              );
                            },
                            child: _buildPinDots(),
                          ),

                          const Spacer(),

                          // Numeric keypad
                          _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : _buildKeypad(),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Real PIN', 'Confirm', 'Decoy PIN', 'Confirm'];
    final currentIndex = _step.index - 1; // Subtract 1 because currentPin is step 0

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final isActive = i <= currentIndex;
        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.white : Colors.white24,
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 24,
                height: 2,
                color: i < currentIndex ? Colors.white : Colors.white24,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _dotCount,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _enteredPin.length
                ? Colors.white
                : Colors.transparent,
            border: Border.all(
              color: _showError
                  ? Colors.redAccent
                  : (i < _enteredPin.length ? Colors.white : Colors.white54),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map((e) => _buildKey(e, onTap: () => _onKeyPress(e)))
                  .toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Empty space on the left
              const SizedBox(width: 75, height: 75),
              // 0 key
              _buildKey('0', onTap: () => _onKeyPress('0')),
              // Backspace key
              _buildKey('⌫', onTap: _onDelete, isIcon: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String text, {VoidCallback? onTap, bool isIcon = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Center(
          child: isIcon
              ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 24)
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
