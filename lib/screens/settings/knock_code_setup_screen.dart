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

  String _enteredPin = '';
  String _newRealKnockCode = '';
  String _newDecoyKnockCode = '';

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

  void _onKnockCodeCompleted(String code) {
    if (_isSaving) return;

    switch (_step) {
      case KnockCodeSetupStep.currentPin:
        // Not used for knock code
        break;

      case KnockCodeSetupStep.newRealKnockCode:
        _newRealKnockCode = code;
        setState(() {
          _step = KnockCodeSetupStep.confirmRealKnockCode;
          _statusMessage = '';
        });
        break;

      case KnockCodeSetupStep.confirmRealKnockCode:
        if (code != _newRealKnockCode) {
          _showError('Knock codes do not match. Try again.');
          setState(() {
            _step = KnockCodeSetupStep.newRealKnockCode;
            _newRealKnockCode = '';
          });
        } else {
          setState(() {
            _step = KnockCodeSetupStep.newDecoyKnockCode;
            _statusMessage = '';
          });
        }
        break;

      case KnockCodeSetupStep.newDecoyKnockCode:
        if (code == _newRealKnockCode) {
          _showError('Decoy knock code must differ from real knock code.');
          return;
        }
        _newDecoyKnockCode = code;
        setState(() {
          _step = KnockCodeSetupStep.confirmDecoyKnockCode;
          _statusMessage = '';
        });
        break;

      case KnockCodeSetupStep.confirmDecoyKnockCode:
        if (code != _newDecoyKnockCode) {
          _showError('Knock codes do not match. Try again.');
          setState(() {
            _step = KnockCodeSetupStep.newDecoyKnockCode;
            _newDecoyKnockCode = '';
          });
        } else {
          _saveKnockCodes();
        }
        break;
    }
  }

  void _showError(String message) {
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

  Future<void> _saveKnockCodes() async {
    setState(() => _isSaving = true);

    try {
      final userId = await UserIdentifierService.getUserId();

      // Save to Hive
      final securityBox = Hive.box('securityBox');
      await securityBox.put('realPin', _newRealKnockCode);
      await securityBox.put('decoyPin', _newDecoyKnockCode);
      await securityBox.put('unlockPattern', 'knock-code');
      debugPrint('Knock codes saved to Hive');

      // Cache to native SharedPreferences
      try {
        const platform = MethodChannel('com.stealthseal.app/applock');
        await platform.invokeMethod('cachePins', {
          'real_pin': _newRealKnockCode,
          'decoy_pin': _newDecoyKnockCode,
        });
        debugPrint('Knock codes cached to native');
      } catch (error) {
        debugPrint('Warning: Failed to cache knock codes: $error');
      }

      // Sync to Supabase
      try {
        await Supabase.instance.client
            .from('user_security')
            .upsert(
              {
                'id': userId,
                'real_pin': _newRealKnockCode,
                'decoy_pin': _newDecoyKnockCode,
              },
              onConflict: 'id',
            );
        debugPrint('Knock codes synced to Supabase');
      } catch (supabaseError) {
        debugPrint('WARNING: Supabase sync failed: $supabaseError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Warning: Knock codes saved locally but cloud sync failed. '
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
      debugPrint('Error saving knock codes: $error');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save knock codes. Please try again.'),
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
              'Knock Code Set!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your real knock code and decoy knock code have been saved.',
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
      case KnockCodeSetupStep.currentPin:
        return 'Verify Identity';
      case KnockCodeSetupStep.newRealKnockCode:
        return 'Set Real Knock Code';
      case KnockCodeSetupStep.confirmRealKnockCode:
        return 'Confirm Real Knock Code';
      case KnockCodeSetupStep.newDecoyKnockCode:
        return 'Set Decoy Knock Code';
      case KnockCodeSetupStep.confirmDecoyKnockCode:
        return 'Confirm Decoy Knock Code';
    }
  }

  String get _subtitle {
    switch (_step) {
      case KnockCodeSetupStep.currentPin:
        return 'Verify your current PIN/pattern first';
      case KnockCodeSetupStep.newRealKnockCode:
        return 'Tap 4-6 zones in any pattern\nfor your real knock code';
      case KnockCodeSetupStep.confirmRealKnockCode:
        return 'Repeat the same pattern';
      case KnockCodeSetupStep.newDecoyKnockCode:
        return 'Tap 4-6 zones for your decoy\nknock code (must be different)';
      case KnockCodeSetupStep.confirmDecoyKnockCode:
        return 'Repeat the same pattern';
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

                          // Show knock code widget
                          if (_isSaving)
                            const CircularProgressIndicator(color: Colors.white)
                          else
                            SizedBox(
                              height: 300,
                              child: KnockCodeWidget(
                                onKnockCodeCompleted: _onKnockCodeCompleted,
                                onKnockCodeTooShort: () {
                                  setState(() {
                                    _statusMessage = 'Tap at least 4 zones';
                                    _statusColor = Colors.orangeAccent;
                                  });
                                },
                                dividerColor: const Color(0xFF555566),
                                selectedColor: Colors.white,
                              ),
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
}
