import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/services/user_identifier_service.dart';
import '../../widgets/pattern_lock_widget.dart';

enum PatternSetupStep {
  currentPin,
  newRealPattern,
  confirmRealPattern,
  newDecoyPattern,
  confirmDecoyPattern,
}

class PatternSetupScreen extends StatefulWidget {
  const PatternSetupScreen({super.key});

  @override
  State<PatternSetupScreen> createState() => _PatternSetupScreenState();
}

class _PatternSetupScreenState extends State<PatternSetupScreen> {
  PatternSetupStep _step = PatternSetupStep.currentPin;

  String _enteredPin = '';
  String _newRealPattern = '';
  String _newDecoyPattern = '';

  String? _currentRealPin;
  String? _currentDecoyPin;
  bool _isSaving = false;
  bool _isLoading = true;
  String _statusMessage = '';
  Color _statusColor = Colors.white70;

  @override
  void initState() {
    super.initState();
    _loadCurrentPins();
  }

  Future<void> _loadCurrentPins() async {
    try {
      final securityBox = Hive.box('securityBox');
      _currentRealPin = securityBox.get('realPin', defaultValue: '') as String;
      _currentDecoyPin =
          securityBox.get('decoyPin', defaultValue: '') as String;

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

  int get _currentPinMaxLength {
    final realLen = _currentRealPin?.length ?? 4;
    final decoyLen = _currentDecoyPin?.length ?? 4;
    return realLen > decoyLen ? realLen : decoyLen;
  }

  // Called from PinKeypad during currentPin step
  void _onKeyPress(String value) {
    if (_isSaving || _isLoading) return;
    if (_step != PatternSetupStep.currentPin) return;

    final maxLen = _currentPinMaxLength;
    if (_enteredPin.length >= maxLen) return;

    setState(() {
      _enteredPin += value;
      _statusMessage = '';
    });

    if (_enteredPin.length == maxLen) {
      _verifyCurrentPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _statusMessage = '';
    });
  }

  void _verifyCurrentPin() {
    if (_enteredPin == _currentRealPin || _enteredPin == _currentDecoyPin) {
      setState(() {
        _step = PatternSetupStep.newRealPattern;
        _enteredPin = '';
        _statusMessage = '';
      });
    } else {
      setState(() {
        _enteredPin = '';
        _statusMessage = 'Wrong PIN. Try again.';
        _statusColor = Colors.redAccent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wrong PIN. Try again.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPatternCompleted(String pattern) {
    if (_isSaving) return;

    switch (_step) {
      case PatternSetupStep.currentPin:
        // Should not happen; current PIN uses keypad
        break;

      case PatternSetupStep.newRealPattern:
        if (pattern.length < 4) {
          _showPatternError('Connect at least 4 dots');
          return;
        }
        _newRealPattern = pattern;
        setState(() {
          _step = PatternSetupStep.confirmRealPattern;
          _statusMessage = '';
        });
        break;

      case PatternSetupStep.confirmRealPattern:
        if (pattern != _newRealPattern) {
          _showPatternError('Patterns do not match. Try again.');
          setState(() {
            _step = PatternSetupStep.newRealPattern;
            _newRealPattern = '';
          });
        } else {
          setState(() {
            _step = PatternSetupStep.newDecoyPattern;
            _statusMessage = '';
          });
        }
        break;

      case PatternSetupStep.newDecoyPattern:
        if (pattern.length < 4) {
          _showPatternError('Connect at least 4 dots');
          return;
        }
        if (pattern == _newRealPattern) {
          _showPatternError('Decoy pattern must differ from real pattern.');
          return;
        }
        _newDecoyPattern = pattern;
        setState(() {
          _step = PatternSetupStep.confirmDecoyPattern;
          _statusMessage = '';
        });
        break;

      case PatternSetupStep.confirmDecoyPattern:
        if (pattern != _newDecoyPattern) {
          _showPatternError('Patterns do not match. Try again.');
          setState(() {
            _step = PatternSetupStep.newDecoyPattern;
            _newDecoyPattern = '';
          });
        } else {
          _savePattern();
        }
        break;
    }
  }

  void _showPatternError(String message) {
    setState(() {
      _statusMessage = message;
      _statusColor = Colors.redAccent;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _savePattern() async {
    setState(() => _isSaving = true);

    try {
      final userId = await UserIdentifierService.getUserId();

      // Save to Hive
      final securityBox = Hive.box('securityBox');
      await securityBox.put('realPin', _newRealPattern);
      await securityBox.put('decoyPin', _newDecoyPattern);
      await securityBox.put('unlockPattern', 'pattern');
      debugPrint('Pattern PINs saved to Hive');

      // Cache to native SharedPreferences
      try {
        const platform = MethodChannel('com.stealthseal.app/applock');
        await platform.invokeMethod('cachePins', {
          'real_pin': _newRealPattern,
          'decoy_pin': _newDecoyPattern,
        });
        debugPrint('Pattern PINs cached to native');
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
                'real_pin': _newRealPattern,
                'decoy_pin': _newDecoyPattern,
              },
              onConflict: 'id',
            );
        debugPrint('Pattern PINs synced to Supabase');
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
      debugPrint('Error saving pattern: $error');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save pattern. Please try again.'),
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
              'Pattern Lock Set!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your real pattern and decoy pattern have been saved.',
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
                    Navigator.pop(context, true);
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
      case PatternSetupStep.currentPin:
        return 'Enter Current PIN';
      case PatternSetupStep.newRealPattern:
        return 'Draw Real Pattern';
      case PatternSetupStep.confirmRealPattern:
        return 'Confirm Real Pattern';
      case PatternSetupStep.newDecoyPattern:
        return 'Draw Decoy Pattern';
      case PatternSetupStep.confirmDecoyPattern:
        return 'Confirm Decoy Pattern';
    }
  }

  String get _subtitle {
    switch (_step) {
      case PatternSetupStep.currentPin:
        return 'Verify your identity first';
      case PatternSetupStep.newRealPattern:
        return 'Draw your real unlock pattern\nConnect at least 4 dots';
      case PatternSetupStep.confirmRealPattern:
        return 'Draw the same pattern again';
      case PatternSetupStep.newDecoyPattern:
        return 'Draw your decoy unlock pattern\nConnect at least 4 dots';
      case PatternSetupStep.confirmDecoyPattern:
        return 'Draw the same pattern again';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1a1a2e) : const Color(0xFF2d2d2d),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: ThemeConfig.accentColor(context),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
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
                          // Step indicator (after current PIN step)
                          if (_step != PatternSetupStep.currentPin)
                            _buildStepIndicator(),

                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            _subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),

                          // Status message
                          if (_statusMessage.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: _statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),

                          // Show either PIN keypad or Pattern grid
                          if (_step == PatternSetupStep.currentPin)
                            _buildCurrentPinInput()
                          else if (_isSaving)
                            const CircularProgressIndicator(
                                color: Colors.white)
                          else
                            PatternLockWidget(
                              onPatternCompleted: _onPatternCompleted,
                              dotColor: const Color(0xFF555566),
                              selectedColor: Colors.white,
                            ),

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
    final steps = [
      'Real Pattern',
      'Confirm',
      'Decoy Pattern',
      'Confirm'
    ];
    final currentIndex = _step.index - 1;

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

  Widget _buildCurrentPinInput() {
    return Column(
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _currentPinMaxLength,
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
                  color: i < _enteredPin.length
                      ? Colors.white
                      : Colors.white54,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Keypad
        _buildKeypad(),
      ],
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
              const SizedBox(width: 75, height: 75),
              _buildKey('0', onTap: () => _onKeyPress('0')),
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
              ? const Icon(Icons.backspace_outlined,
                  color: Colors.white, size: 24)
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
