import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/services/user_identifier_service.dart';
import '../../widgets/knock_code_widget.dart';
import '../../widgets/pattern_lock_widget.dart';

enum KnockCodeSetupStep {
  currentPin,
  newRealKnockCode,
  confirmRealKnockCode,
  newDecoyKnockCode,
  confirmDecoyKnockCode,
}

class KnockCodeSetupScreen extends StatefulWidget {
  const KnockCodeSetupScreen({super.key});

  @override
  State<KnockCodeSetupScreen> createState() => _KnockCodeSetupScreenState();
}

class _KnockCodeSetupScreenState extends State<KnockCodeSetupScreen> {
  KnockCodeSetupStep _step = KnockCodeSetupStep.currentPin;

  String _newRealKnockCode = '';
  String _newDecoyKnockCode = '';
  String _currentInputTaps = ''; // Track current taps for visual feedback
  String _enteredPin = ''; // Track PIN entry during current PIN verification

  String? _currentRealPin;
  String? _currentDecoyPin;
  String _currentUnlockPattern = '4-digit';
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
      _currentDecoyPin = securityBox.get('decoyPin', defaultValue: '') as String;
      _currentUnlockPattern = securityBox.get('unlockPattern', defaultValue: '4-digit') as String;

      debugPrint('Knock code setup - Loaded pattern type: $_currentUnlockPattern');

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

  void _onKnockCodeCompleted(String code) {
    if (_isSaving) return;

    // Update current input taps for visual feedback
    setState(() {
      _currentInputTaps = code;
    });

    switch (_step) {
      case KnockCodeSetupStep.currentPin:
        // Only verify if currently in knock code mode (changing knock code)
        if (_currentUnlockPattern == 'knock-code') {
          debugPrint('Verifying current knock code: "$code" against real: "$_currentRealPin", decoy: "$_currentDecoyPin"');

          if (code == _currentRealPin || code == _currentDecoyPin) {
            debugPrint('✓ Current knock code verified successfully');
            setState(() {
              _step = KnockCodeSetupStep.newRealKnockCode;
              _statusMessage = '';
              _statusColor = Colors.white70;
              _currentInputTaps = ''; // Reset for new step
            });
          } else {
            debugPrint('✗ Current knock code verification failed');
            _showError('Wrong knock code. Try again.');
          }
        } else {
          // First-time setup: skip verification
          debugPrint('✓ First-time knock code setup (auto-skip verification)');
          setState(() {
            _step = KnockCodeSetupStep.newRealKnockCode;
            _statusMessage = '';
            _statusColor = Colors.white70;
            _currentInputTaps = ''; // Reset for new step
          });
        }
        break;

      case KnockCodeSetupStep.newRealKnockCode:
        debugPrint('✓ Real knock code set: "$code"');
        setState(() {
          _newRealKnockCode = code;
          _step = KnockCodeSetupStep.confirmRealKnockCode;
          _statusMessage = 'Now confirm your real knock code';
          _statusColor = Colors.white70;
          _currentInputTaps = ''; // Reset for new step
        });
        break;

      case KnockCodeSetupStep.confirmRealKnockCode:
        if (code == _newRealKnockCode) {
          debugPrint('✓ Real knock code confirmed successfully');
          setState(() {
            _step = KnockCodeSetupStep.newDecoyKnockCode;
            _statusMessage = 'Now set your decoy knock code';
            _statusColor = Colors.white70;
            _currentInputTaps = ''; // Reset for new step
          });
        } else {
          debugPrint('✗ Real knock code confirmation failed');
          setState(() {
            _statusMessage = 'Knock codes do not match';
            _statusColor = Colors.redAccent;
            _currentInputTaps = ''; // Reset for retry
          });
        }
        break;

      case KnockCodeSetupStep.newDecoyKnockCode:
        debugPrint('✓ Decoy knock code set: "$code"');
        setState(() {
          _newDecoyKnockCode = code;
          _step = KnockCodeSetupStep.confirmDecoyKnockCode;
          _statusMessage = 'Now confirm your decoy knock code';
          _statusColor = Colors.white70;
          _currentInputTaps = ''; // Reset for new step
        });
        break;

      case KnockCodeSetupStep.confirmDecoyKnockCode:
        if (code == _newDecoyKnockCode) {
          debugPrint('✓ Decoy knock code confirmed successfully');
          _saveKnockCodes();
        } else {
          debugPrint('✗ Decoy knock code confirmation failed');
          setState(() {
            _statusMessage = 'Knock codes do not match';
            _statusColor = Colors.redAccent;
            _currentInputTaps = ''; // Reset for retry
          });
        }
        break;
    }
  }

  Future<void> _saveKnockCodes() async {
    setState(() => _isSaving = true);

    try {
      final securityBox = Hive.box('securityBox');
      await securityBox.put('realPin', _newRealKnockCode);
      await securityBox.put('decoyPin', _newDecoyKnockCode);
      await securityBox.put('unlockPattern', 'knock-code');

      final userId = await UserIdentifierService.getUserId();
      await Supabase.instance.client.from('user_security').upsert(
        {
          'id': userId,
          'real_pin': _newRealKnockCode,
          'decoy_pin': _newDecoyKnockCode,
        },
        onConflict: 'id',
      );

      debugPrint('✓ Knock codes saved successfully to Hive and Supabase');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Knock code setup complete!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      debugPrint('✗ Error saving knock codes: $error');
      _showError('Failed to save knock codes. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _statusMessage = message;
      _statusColor = Colors.redAccent;
    });
  }

  int _getTappedCount() {
    return _currentInputTaps.length;
  }

  void _onKeyPress(String value) {
    if (_isSaving || _isLoading) return;
    final maxLen = _currentRealPin?.length ?? 4;
    if (_enteredPin.length >= maxLen) return;

    setState(() {
      _enteredPin += value;
    });

    // Auto-validate when input reaches the required length
    if (_enteredPin.length == maxLen) {
      _verifyCurrentPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onPatternCompleted(String pattern) {
    // Only used for verifying current pattern when switching from pattern mode
    if (_step != KnockCodeSetupStep.currentPin || _currentUnlockPattern != 'pattern') return;

    if (pattern == _currentRealPin || pattern == _currentDecoyPin) {
      setState(() {
        _step = KnockCodeSetupStep.newRealKnockCode;
        _statusMessage = '';
        _statusColor = Colors.white70;
        _currentInputTaps = '';
      });
    } else {
      _showError('Wrong pattern. Try again.');
    }
  }

  void _verifyCurrentPin() {
    if (_enteredPin == _currentRealPin || _enteredPin == _currentDecoyPin) {
      setState(() {
        _step = KnockCodeSetupStep.newRealKnockCode;
        _statusMessage = '';
        _statusColor = Colors.white70;
        _enteredPin = '';
        _currentInputTaps = '';
      });
    } else {
      _showError('Wrong PIN. Try again.');
      setState(() {
        _enteredPin = '';
      });
    }
  }

  String get _title {
    switch (_step) {
      case KnockCodeSetupStep.currentPin:
        // Check if there are existing PINs to verify
        final hasExistingCredentials = _currentRealPin != null && _currentRealPin!.isNotEmpty &&
                                      _currentDecoyPin != null && _currentDecoyPin!.isNotEmpty;
        
        if (!hasExistingCredentials) {
          return 'Verify Current Knock Code';
        } else if (_currentUnlockPattern == 'pattern') {
          return 'Verify Current Pattern';
        } else if (_currentUnlockPattern == '6-digit') {
          return 'Verify Current 6-digit PIN';
        } else {
          return 'Verify Current Pattern';
        }
      case KnockCodeSetupStep.newRealKnockCode:
        return 'Set New Real Knock Code';
      case KnockCodeSetupStep.confirmRealKnockCode:
        return 'Confirm Real Knock Code';
      case KnockCodeSetupStep.newDecoyKnockCode:
        return 'Set New Decoy Knock Code';
      case KnockCodeSetupStep.confirmDecoyKnockCode:
        return 'Confirm Decoy Knock Code';
    }
  }

  String get _subtitle {
    switch (_step) {
      case KnockCodeSetupStep.currentPin:
        // Check if there are existing PINs to verify
        final hasExistingCredentials = _currentRealPin != null && _currentRealPin!.isNotEmpty &&
                                      _currentDecoyPin != null && _currentDecoyPin!.isNotEmpty;
        
        if (!hasExistingCredentials) {
          return 'Proceed to set knock code';
        } else if (_currentUnlockPattern == 'knock-code') {
          return 'Tap 4-6 zones for current knock code';
        } else if (_currentUnlockPattern == 'pattern') {
          return 'Draw your current pattern';
        } else if (_currentUnlockPattern == '6-digit') {
          return 'Enter your current 6-digit PIN';
        } else {
          return 'Enter your current 4-digit PIN';
        }
      case KnockCodeSetupStep.newRealKnockCode:
        return 'Tap 4-6 zones for real knock code';
      case KnockCodeSetupStep.confirmRealKnockCode:
        return 'Confirm by tapping the same zones';
      case KnockCodeSetupStep.newDecoyKnockCode:
        return 'Tap 4-6 zones for decoy knock code';
      case KnockCodeSetupStep.confirmDecoyKnockCode:
        return 'Confirm by tapping the same zones';
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
                  // Top bar with centered step indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_step.index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '—',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF555566),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '5',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Back button on the left
                      Positioned(
                        left: 0,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Visual tap sequence indicator (always show)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 24,
                              children: List.generate(
                                6,
                                (index) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: GridView.count(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 4,
                                        mainAxisSpacing: 4,
                                        children: List.generate(
                                          4,
                                          (dotIndex) => Container(
                                            decoration: BoxDecoration(
                                              color: (index * 4 + dotIndex) < _getTappedCount()
                                                  ? Colors.cyan
                                                  : const Color(0xFF444455),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getTappedCount() > index ? '${index + 1}' : '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Title and content (centered)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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

                                const SizedBox(height: 24),

                                // Show verification widget based on current unlock method
                                if (_isSaving)
                                  const CircularProgressIndicator(color: Colors.white)
                                else if (_step == KnockCodeSetupStep.currentPin && _currentUnlockPattern == 'pattern')
                                  // Show pattern grid for pattern verification
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                      maxHeight: 320,
                                    ),
                                    child: PatternLockWidget(
                                      onPatternCompleted: _onPatternCompleted,
                                      dotColor: const Color(0xFF555566),
                                      selectedColor: Colors.white,
                                    ),
                                  )
                                else if (_step == KnockCodeSetupStep.currentPin && 
                                         (_currentUnlockPattern == '4-digit' || _currentUnlockPattern == '6-digit'))
                                  // Show PIN input dots and keypad
                                  Column(
                                    children: [
                                      // PIN dots
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(
                                          _currentRealPin?.length ?? 4,
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
                                                color: i < _enteredPin.length ? Colors.white : Colors.white54,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      // Keypad
                                      _buildKeypad(),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    height: 250,
                                    child: KnockCodeWidget(
                                      key: ValueKey(_step), // Force widget recreation on step change
                                      onKnockCodeCompleted: _onKnockCodeCompleted,
                                      onKnockCodeTooShort: () {
                                        setState(() {
                                          _statusMessage = 'Tap at least 4 zones';
                                          _statusColor = Colors.orangeAccent;
                                        });
                                      },
                                      onTapUpdate: (tapSequence) {
                                        // Update visual indicator in real-time
                                        setState(() {
                                          _currentInputTaps = tapSequence;
                                        });
                                      },
                                      dividerColor: const Color(0xFF555566),
                                      selectedColor: Colors.white,
                                      submitButtonLabel: 'Next',
                                      clearButtonLabel: 'Reset',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
