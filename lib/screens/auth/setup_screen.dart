import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/pin_keypad.dart';
import '../../core/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import '../../core/services/user_identifier_service.dart';

enum SetupStep { realPin, confirmRealPin, decoyPin, confirmDecoyPin }

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  SetupStep step = SetupStep.realPin;

  String realPin = '';
  String confirmRealPin = '';
  String decoyPin = '';
  String confirmDecoyPin = '';

  bool _isSaving = false;

  void _onKeyPress(String value) {
    if (_isSaving) return;

    setState(() {
      switch (step) {
        case SetupStep.realPin:
          if (realPin.length < 4) {
            realPin += value;
            if (realPin.length == 4) {
              step = SetupStep.confirmRealPin;
            }
          }
          break;

        case SetupStep.confirmRealPin:
          if (confirmRealPin.length < 4) {
            confirmRealPin += value;
            if (confirmRealPin.length == 4) {
              if (confirmRealPin != realPin) {
                _showError('Real PINs do not match');
                confirmRealPin = '';
              } else {
                step = SetupStep.decoyPin;
              }
            }
          }
          break;

        case SetupStep.decoyPin:
          if (decoyPin.length < 4) {
            decoyPin += value;
            if (decoyPin.length == 4) {
              step = SetupStep.confirmDecoyPin;
            }
          }
          break;

        case SetupStep.confirmDecoyPin:
          if (confirmDecoyPin.length < 4) {
            confirmDecoyPin += value;
            if (confirmDecoyPin.length == 4) {
              if (confirmDecoyPin != decoyPin) {
                _showError('Decoy PINs do not match');
                confirmDecoyPin = '';
              } else {
                _finishSetup();
              }
            }
          }
          break;
      }
    });
  }

  void _onDelete() {
    if (_isSaving) return;

    setState(() {
      switch (step) {
        case SetupStep.realPin:
          if (realPin.isNotEmpty) {
            realPin = realPin.substring(0, realPin.length - 1);
          }
          break;

        case SetupStep.confirmRealPin:
          if (confirmRealPin.isNotEmpty) {
            confirmRealPin = confirmRealPin.substring(
              0,
              confirmRealPin.length - 1,
            );
          }
          break;

        case SetupStep.decoyPin:
          if (decoyPin.isNotEmpty) {
            decoyPin = decoyPin.substring(0, decoyPin.length - 1);
          }
          break;

        case SetupStep.confirmDecoyPin:
          if (confirmDecoyPin.isNotEmpty) {
            confirmDecoyPin = confirmDecoyPin.substring(
              0,
              confirmDecoyPin.length - 1,
            );
          }
          break;
      }
    });
  }

  Future<void> _finishSetup() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final userId = await UserIdentifierService.getUserId();
      debugPrint('Saving PINs for user: $userId');

      // Step 1: Save to Hive FIRST (guaranteed local storage)
      final securityBox = Hive.box('securityBox');
      securityBox.put('realPin', realPin);
      securityBox.put('decoyPin', decoyPin);
      securityBox.put('isPinSetupDone', true);
      debugPrint('PINs saved locally to Hive');

      // Step 2: Cache to native SharedPreferences (for app lock)
      try {
        const platform = MethodChannel('com.stealthseal.app/applock');
        await platform.invokeMethod('cachePins', {
          'real_pin': realPin,
          'decoy_pin': decoyPin,
        });
        debugPrint('PINs cached to native SharedPreferences');
      } catch (error) {
        debugPrint('Warning: Failed to cache PINs: $error');
      }

      // Step 3: Sync to Supabase (best-effort, non-blocking on failure)
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('user_security').upsert({
          'id': userId,
          'real_pin': realPin,
          'decoy_pin': decoyPin,
          'biometric_enabled': false,
        }).timeout(const Duration(seconds: 8));
        debugPrint('PINs synced to Supabase successfully');
      } catch (supabaseError) {
        debugPrint('Warning: Supabase sync failed (will retry later): $supabaseError');
        // PINs are safely stored in Hive, so we continue
      }

      if (!mounted) return;

      _showSuccessDialog();
    } catch (error) {
      debugPrint('Error saving PINs: $error');
      if (mounted) {
        _showError('Failed to save settings. Please try again.');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'PIN Set Successfully! ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your real PIN and decoy PIN have been saved securely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
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
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.biometricSetup,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.black,
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
    ));
  }

  String get title {
    switch (step) {
      case SetupStep.realPin:
        return 'Set Your Real PIN';
      case SetupStep.confirmRealPin:
        return 'Confirm Real PIN';
      case SetupStep.decoyPin:
        return 'Set Your Decoy PIN';
      case SetupStep.confirmDecoyPin:
        return 'Confirm Decoy PIN';
    }
  }

  String get subtitle {
    switch (step) {
      case SetupStep.realPin:
        return 'This PIN unlocks your real dashboard';
      case SetupStep.confirmRealPin:
        return 'Re-enter your real PIN to confirm';
      case SetupStep.decoyPin:
        return 'This PIN shows a fake dashboard';
      case SetupStep.confirmDecoyPin:
        return 'Re-enter your decoy PIN to confirm';
    }
  }

  String get currentPin {
    switch (step) {
      case SetupStep.realPin:
        return realPin;
      case SetupStep.confirmRealPin:
        return confirmRealPin;
      case SetupStep.decoyPin:
        return decoyPin;
      case SetupStep.confirmDecoyPin:
        return confirmDecoyPin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 60, color: Colors.cyan),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < currentPin.length
                        ? Colors.cyan
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            _isSaving
                ? const CircularProgressIndicator(color: Colors.cyan)
                : PinKeypad(onKeyPressed: _onKeyPress, onDelete: _onDelete),
          ],
        ),
      ),
    );
  }
}
