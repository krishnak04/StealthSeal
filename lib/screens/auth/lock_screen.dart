import 'package:flutter/material.dart';
import 'package:stealthseal/screens/dashboard/real_dashboard.dart';
import '../../widgets/pin_keypad.dart';
import '../../core/routes/app_routes.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/security/intruder_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String enteredPin = '';
  late String? realPin;
  late String? decoyPin;
  int failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('user_security')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    setState(() {
      realPin = response['real_pin'];
      decoyPin = response['decoy_pin'];
    });
  }

  void _onKeyPress(String value) {
    if (enteredPin.length >= 4) return;

    setState(() {
      enteredPin += value;
    });

    if (enteredPin.length == 4) {
      // Just call the existing method
      _validatePin();
    }
  }

  void _onDelete() {
    if (enteredPin.isEmpty) return;

    setState(() {
      enteredPin = enteredPin.substring(0, enteredPin.length - 1);
    });
  }

  // Your primary validation method (unchanged logic)
  void _validatePin() async {
  if (realPin == null || decoyPin == null) return;

  if (enteredPin == realPin) {
    failedAttempts = 0;
    Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
  } 
  else if (enteredPin == decoyPin) {
    failedAttempts = 0;
    Navigator.pushReplacementNamed(context, AppRoutes.fakeDashboard);
  } 
  else {
    failedAttempts++;

    if (failedAttempts >= 3) {
      failedAttempts = 0;
      await IntruderService.captureIntruderSelfie();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intruder detected. Selfie captured.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong PIN (${3 - failedAttempts} attempts left)'),
        ),
      );
    }
  }

  setState(() {
    enteredPin = '';
  });
}


  void _showError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
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
            const Icon(Icons.lock, size: 60, color: Colors.cyan),
            const SizedBox(height: 16),
            const Text(
              'Enter PIN',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock to access your apps',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),

            // PIN DOTS
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
                    color: index < enteredPin.length
                        ? Colors.cyan
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // KEYPAD
            PinKeypad(onKeyPressed: _onKeyPress, onDelete: _onDelete),
          ],
        ),
      ),
    );
  }
}
