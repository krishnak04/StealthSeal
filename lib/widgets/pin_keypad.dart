import 'package:flutter/material.dart';

/// Reusable numeric keypad widget for PIN entry screens.
class PinKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDelete;

  const PinKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onDelete,
  });

  // ─── Key Builder ───

  /// Builds a single key button with the given label and tap handler.
  Widget _buildKey(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        width: 90,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 236, 234, 234),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map((e) => _buildKey(e, onTap: () => onKeyPressed(e)))
                  .toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('0', onTap: () => onKeyPressed('0')),
            _buildKey('⌫', onTap: onDelete),
          ],
        ),
      ],
    );
  }
}
