import 'package:flutter/material.dart';
import '../../widgets/pin_keypad.dart';
import '../../core/routes/app_routes.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String enteredPin = '';

  // TEMP (will come from storage later)
  final String realPin = '1234';
  final String decoyPin = '4321';

  void _onKeyPress(String value) {
    if (enteredPin.length >= 4) return;

    setState(() {
      enteredPin += value;
    });

    if (enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onDelete() {
    if (enteredPin.isEmpty) return;

    setState(() {
      enteredPin = enteredPin.substring(0, enteredPin.length - 1);
    });
  }

  void _validatePin() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (enteredPin == realPin) {
      Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
    } else if (enteredPin == decoyPin) {
      Navigator.pushReplacementNamed(context, AppRoutes.fakeDashboard);
    } else {
      _showError();
    }

    setState(() {
      enteredPin = '';
    });
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incorrect PIN')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 60, color: Colors.cyan),
            const SizedBox(height: 16),
            const Text(
              'Enter PIN',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
            PinKeypad(
              onKeyPressed: _onKeyPress,
              onDelete: _onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
