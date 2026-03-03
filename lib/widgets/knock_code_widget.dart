import 'package:flutter/material.dart';

/// A knock code widget that divides the screen into zones for tapping.
/// Users tap zones in sequence to create a knock code.
class KnockCodeWidget extends StatefulWidget {
  /// Called when knock code is completed (4-6 taps)
  final ValueChanged<String> onKnockCodeCompleted;

  /// Called when user taps fewer than minimum required zones
  final VoidCallback? onKnockCodeTooShort;

  /// Called on each tap with current tap sequence (for real-time UI updates)
  final ValueChanged<String>? onTapUpdate;

  /// Color of zone dividers (cross lines)
  final Color dividerColor;

  /// Color of tapped zones
  final Color selectedColor;

  /// Minimum number of taps required (default 4)
  final int minTaps;

  /// Maximum number of taps allowed (default 6)
  final int maxTaps;

  /// Custom label for submit button (default "Submit")
  final String submitButtonLabel;

  /// Custom label for clear button (default "Clear")
  final String clearButtonLabel;

  const KnockCodeWidget({
    super.key,
    required this.onKnockCodeCompleted,
    this.onKnockCodeTooShort,
    this.onTapUpdate,
    this.dividerColor = const Color(0xFF666677),
    this.selectedColor = Colors.cyan,
    this.minTaps = 4,
    this.maxTaps = 6,
    this.submitButtonLabel = 'Submit',
    this.clearButtonLabel = 'Clear',
  });

  @override
  State<KnockCodeWidget> createState() => _KnockCodeWidgetState();
}

class _KnockCodeWidgetState extends State<KnockCodeWidget> {
  final List<int> _tappedZones = [];

  // 4 zones: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
  late Rect _zone0, _zone1, _zone2, _zone3;

  @override
  void initState() {
    super.initState();
  }

  void _computeZones(double width, double height) {
    final centerX = width / 2;
    final centerY = height / 2;

    _zone0 = Rect.fromLTWH(0, 0, centerX, centerY);
    _zone1 = Rect.fromLTWH(centerX, 0, centerX, centerY);
    _zone2 = Rect.fromLTWH(0, centerY, centerX, centerY);
    _zone3 = Rect.fromLTWH(centerX, centerY, centerX, centerY);
  }

  int? _getZoneAtPosition(Offset position) {
    if (_zone0.contains(position)) return 0;
    if (_zone1.contains(position)) return 1;
    if (_zone2.contains(position)) return 2;
    if (_zone3.contains(position)) return 3;
    return null;
  }

  void _handleTap(TapUpDetails details) {
    if (_tappedZones.length >= widget.maxTaps) return;

    final zone = _getZoneAtPosition(details.localPosition);
    if (zone != null) {
      setState(() {
        _tappedZones.add(zone);
      });
      
      // Notify parent widget about each tap in real-time
      final currentCode = _tappedZones.join('');
      widget.onTapUpdate?.call(currentCode);
    }
  }

  void _handleSubmit() {
    if (_tappedZones.length < widget.minTaps) {
      widget.onKnockCodeTooShort?.call();
      return;
    }

    final code = _tappedZones.join('');
    widget.onKnockCodeCompleted(code);
  }

  void _handleReset() {
    setState(() {
      _tappedZones.clear();
    });
    
    // Notify about reset
    widget.onTapUpdate?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height * 0.7;

        _computeZones(width, height);

        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTapUp: _handleTap,
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: _KnockCodePainter(
                    tappedZones: _tappedZones,
                    dividerColor: widget.dividerColor,
                    selectedColor: widget.selectedColor,
                  ),
                  size: Size(width, height),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Taps: ${_tappedZones.length} / ${widget.maxTaps}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _tappedZones.length >= widget.minTaps
                        ? _handleSubmit
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      widget.submitButtonLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      widget.clearButtonLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KnockCodePainter extends CustomPainter {
  final List<int> tappedZones;
  final Color dividerColor;
  final Color selectedColor;

  _KnockCodePainter({
    required this.tappedZones,
    required this.dividerColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw dividers
    final dividerPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 2.0;

    // Vertical line
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      dividerPaint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      dividerPaint,
    );

    // Draw zone indicators (corners)
    final cornerRadius = 30.0;
    final cornerPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Top-left corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cornerRadius,cornerRadius), radius: cornerRadius),
      3.14159 ,
      3.14159 / 2,
      false,
      cornerPaint,
    );

    // Top-right corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - cornerRadius, cornerRadius), radius: cornerRadius),
      - 3.14159 / 2,
      3.14159 / 2,
      false,
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cornerRadius, size.height - cornerRadius), radius: cornerRadius),
      3.14159 / 2,
      3.14159 / 2,
      false,
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - cornerRadius, size.height - cornerRadius), radius: cornerRadius),
      3.14159 / 2,
      -3.14159 / 2,
      false,
      cornerPaint,
    );

    // Draw tapped zones
    final zoneColors = [
      Offset(centerX / 2, centerY / 2),       // zone 0: top-left
      Offset(centerX + centerX / 2, centerY / 2), // zone 1: top-right
      Offset(centerX / 2, centerY + centerY / 2), // zone 2: bottom-left
      Offset(centerX + centerX / 2, centerY + centerY / 2), // zone 3: bottom-right
    ];

    for (int i = 0; i < tappedZones.length; i++) {
      final zone = tappedZones[i];
      final position = zoneColors[zone];

      final highlightPaint = Paint()
        ..color = selectedColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, 20, highlightPaint);

      // Draw tap order
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_KnockCodePainter oldDelegate) => true;
}
