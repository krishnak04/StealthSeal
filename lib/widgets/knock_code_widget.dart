import 'package:flutter/material.dart';

/// A knock code widget that divides the screen into zones for tapping.
/// Users tap zones in sequence to create a knock code.
class KnockCodeWidget extends StatefulWidget {
  /// Called when knock code is completed (4-6 taps)
  final ValueChanged<String> onKnockCodeCompleted;

  /// Called when user taps fewer than minimum required zones
  final VoidCallback? onKnockCodeTooShort;

  /// Color of zone dividers (cross lines)
  final Color dividerColor;

  /// Color of tapped zones
  final Color selectedColor;

  /// Minimum number of taps required (default 4)
  final int minTaps;

  /// Maximum number of taps allowed (default 6)
  final int maxTaps;

  const KnockCodeWidget({
    super.key,
    required this.onKnockCodeCompleted,
    this.onKnockCodeTooShort,
    this.dividerColor = const Color(0xFF666677),
    this.selectedColor = Colors.cyan,
    this.minTaps = 4,
    this.maxTaps = 6,
  });

  @override
  State<KnockCodeWidget> createState() => _KnockCodeWidgetState();
}

class _KnockCodeWidgetState extends State<KnockCodeWidget> {
  final List<int> _tappedZones = [];
  late double _screenWidth;
  late double _screenHeight;

  // 4 zones: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
  late Rect _zone0, _zone1, _zone2, _zone3;

  @override
  void initState() {
    super.initState();
  }

  void _computeZones(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;

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
  }

  void _resetKnockCode() {
    if (mounted) {
      setState(() {
        _tappedZones.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final gridHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.7
            : 280.0;

        _computeZones(width, gridHeight);

        return Column(
          children: [
            Expanded(
              flex: 7,
              child: GestureDetector(
                onTapUp: _handleTap,
                child: CustomPaint(
                  painter: _KnockCodePainter(
                    zone0: _zone0,
                    zone1: _zone1,
                    zone2: _zone2,
                    zone3: _zone3,
                    tappedZones: _tappedZones,
                    dividerColor: widget.dividerColor,
                    selectedColor: widget.selectedColor,
                  ),
                  size: Size(width, gridHeight),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tap count display
                    Text(
                      'Taps: ${_tappedZones.length} / ${widget.maxTaps}',
                      style: TextStyle(
                        color: widget.selectedColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Clear button
                        ElevatedButton.icon(
                          onPressed: _handleReset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Clear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[600],
                            disabledBackgroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                        // Submit button
                        ElevatedButton.icon(
                          onPressed: _tappedZones.length >= widget.minTaps
                              ? _handleSubmit
                              : null,
                          icon: const Icon(Icons.check),
                          label: const Text('Submit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.selectedColor,
                            disabledBackgroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_tappedZones.length < widget.minTaps)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Tap at least ${widget.minTaps} zones',
                          style: TextStyle(
                            color: Colors.orange[300],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KnockCodePainter extends CustomPainter {
  final Rect zone0, zone1, zone2, zone3;
  final List<int> tappedZones;
  final Color dividerColor;
  final Color selectedColor;

  _KnockCodePainter({
    required this.zone0,
    required this.zone1,
    required this.zone2,
    required this.zone3,
    required this.tappedZones,
    required this.dividerColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw vertical divider
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      Paint()
        ..color = dividerColor
        ..strokeWidth = 3.5,
    );

    // Draw horizontal divider
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = dividerColor
        ..strokeWidth = 3.5,
    );

    // Draw zone backgrounds - tapped zones highlighted
    final zones = [zone0, zone1, zone2, zone3];
    for (int i = 0; i < zones.length; i++) {
      final zone = zones[i];
      if (tappedZones.contains(i)) {
        canvas.drawRect(
          zone,
          Paint()..color = selectedColor.withValues(alpha: 0.25),
        );
      }
    }

    // Draw tap order numbers in zones
    for (int i = 0; i < tappedZones.length; i++) {
      final zoneIndex = tappedZones[i];
      final zone = zones[zoneIndex];
      final center = zone.center;

      // Draw circular background for number
      canvas.drawCircle(
        center,
        24,
        Paint()
          ..color = selectedColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill,
      );

      // Draw border
      canvas.drawCircle(
        center,
        24,
        Paint()
          ..color = selectedColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Draw number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: selectedColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KnockCodePainter oldDelegate) {
    return oldDelegate.tappedZones != tappedZones;
  }
}
