import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/services/user_identifier_service.dart';
import '../../widgets/knock_code_widget.dart';

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

  String get _title {
    switch (_step) {
      case KnockCodeSetupStep.currentPin:
        return 'Verify Current Knock Code';
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
        return 'Enter your current knock code';
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
                          // Visual tap sequence indicator (at the top)
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

                                // Show knock code widget
                                if (_isSaving)
                                  const CircularProgressIndicator(color: Colors.white)
                                else
                                  SizedBox(
                                    height: 250,
                                    child: KnockCodeWidget(
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
}
