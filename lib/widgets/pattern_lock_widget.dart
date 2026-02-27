import 'package:flutter/material.dart';

/// A 3x3 pattern lock widget that allows users to draw a pattern
/// by connecting dots. Returns the pattern as a string of dot indices (0-8).
class PatternLockWidget extends StatefulWidget {
  /// Called when the user lifts their finger after drawing a pattern.
  /// The pattern is a string of dot indices, e.g., "0123" or "04826".
  final ValueChanged<String> onPatternCompleted;

  /// Called when the user draws fewer than the minimum required dots.
  final VoidCallback? onPatternTooShort;

  /// Size of each dot (radius)
  final double dotRadius;

  /// Color of unselected dots
  final Color dotColor;

  /// Color of selected dots and lines
  final Color selectedColor;

  /// Whether to show the drawn lines
  final bool showLines;

  /// Minimum number of dots required (default 4)
  final int minDots;

  const PatternLockWidget({
    super.key,
    required this.onPatternCompleted,
    this.onPatternTooShort,
    this.dotRadius = 12,
    this.dotColor = const Color(0xFF555566),
    this.selectedColor = Colors.white,
    this.showLines = true,
    this.minDots = 4,
  });

  @override
  State<PatternLockWidget> createState() => _PatternLockWidgetState();
}

class _PatternLockWidgetState extends State<PatternLockWidget> {
  final List<int> _selectedDots = [];
  Offset? _currentTouch;
  bool _isDragging = false;

  // Each dot's center position, recomputed when size changes
  List<Offset> _dotCenters = [];
  double _gridSize = 280;

  double get _cellSize => _gridSize / 3;

  @override
  void initState() {
    super.initState();
  }

  void _computeDotCenters(double gridSize) {
    _gridSize = gridSize;
    _dotCenters = [];
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        _dotCenters.add(Offset(
          col * _cellSize + _cellSize / 2,
          row * _cellSize + _cellSize / 2,
        ));
      }
    }
  }

  int? _getDotAtPosition(Offset position) {
    for (int i = 0; i < _dotCenters.length; i++) {
      final distance = (position - _dotCenters[i]).distance;
      if (distance < _cellSize * 0.45) {
        return i;
      }
    }
    return null;
  }

  void _handlePanStart(DragStartDetails details) {
    final localPos = details.localPosition;
    final dot = _getDotAtPosition(localPos);

    setState(() {
      _selectedDots.clear();
      _isDragging = true;
      _currentTouch = localPos;
      if (dot != null) {
        _selectedDots.add(dot);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final localPos = details.localPosition;
    final dot = _getDotAtPosition(localPos);

    setState(() {
      _currentTouch = localPos;
      if (dot != null && !_selectedDots.contains(dot)) {
        // Auto-connect intermediate dots (e.g., swiping from 0→2 selects 1)
        if (_selectedDots.isNotEmpty) {
          final lastDot = _selectedDots.last;
          final intermediate = _getIntermediateDot(lastDot, dot);
          if (intermediate != null && !_selectedDots.contains(intermediate)) {
            _selectedDots.add(intermediate);
          }
        }
        _selectedDots.add(dot);
      }
    });
  }

  /// Returns the intermediate dot between two dots if they are
  /// in the same row, column, or diagonal with a dot in between.
  int? _getIntermediateDot(int from, int to) {
    // Grid positions: row = index ~/ 3, col = index % 3
    final fromRow = from ~/ 3;
    final fromCol = from % 3;
    final toRow = to ~/ 3;
    final toCol = to % 3;

    final midRow = fromRow + toRow;
    final midCol = fromCol + toCol;

    // Check if mid-point falls exactly on a dot (both coordinates even)
    if (midRow % 2 == 0 && midCol % 2 == 0) {
      final midDot = (midRow ~/ 2) * 3 + (midCol ~/ 2);
      if (midDot >= 0 && midDot < 9 && midDot != from && midDot != to) {
        return midDot;
      }
    }
    return null;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    if (_selectedDots.length >= widget.minDots) {
      final pattern = _selectedDots.join('');
      widget.onPatternCompleted(pattern);
    } else if (_selectedDots.isNotEmpty) {
      // Provide feedback that the pattern is too short
      widget.onPatternTooShort?.call();
    }

    // Clear after a short delay so user can see the pattern
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _selectedDots.clear();
          _currentTouch = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to adapt to available width, capped at 320
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 280.0;
        final gridSize = availableWidth.clamp(200.0, 320.0);

        // Recompute dot centers if size changed
        if (gridSize != _gridSize || _dotCenters.isEmpty) {
          _computeDotCenters(gridSize);
        }

        return Center(
          child: SizedBox(
            width: gridSize,
            height: gridSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: CustomPaint(
                painter: _PatternPainter(
                  dotCenters: _dotCenters,
                  selectedDots: _selectedDots,
                  currentTouch: _isDragging ? _currentTouch : null,
                  dotRadius: widget.dotRadius,
                  dotColor: widget.dotColor,
                  selectedColor: widget.selectedColor,
                  showLines: widget.showLines,
                ),
                size: Size(gridSize, gridSize),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<Offset> dotCenters;
  final List<int> selectedDots;
  final Offset? currentTouch;
  final double dotRadius;
  final Color dotColor;
  final Color selectedColor;
  final bool showLines;

  _PatternPainter({
    required this.dotCenters,
    required this.selectedDots,
    required this.currentTouch,
    required this.dotRadius,
    required this.dotColor,
    required this.selectedColor,
    required this.showLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connecting lines
    if (showLines && selectedDots.length > 1) {
      final linePaint = Paint()
        ..color = selectedColor.withValues(alpha: 0.4)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < selectedDots.length - 1; i++) {
        canvas.drawLine(
          dotCenters[selectedDots[i]],
          dotCenters[selectedDots[i + 1]],
          linePaint,
        );
      }

      // Draw line from last selected dot to current touch position
      if (currentTouch != null && selectedDots.isNotEmpty) {
        canvas.drawLine(
          dotCenters[selectedDots.last],
          currentTouch!,
          linePaint,
        );
      }
    }

    // Draw dots
    for (int i = 0; i < dotCenters.length; i++) {
      final isSelected = selectedDots.contains(i);
      final center = dotCenters[i];

      // Outer ring
      final outerPaint = Paint()
        ..color = isSelected
            ? selectedColor.withValues(alpha: 0.3)
            : dotColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, dotRadius + 4, outerPaint);

      // Inner dot
      final dotPaint = Paint()
        ..color = isSelected ? selectedColor : dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, dotRadius, dotPaint);

      // Border
      final borderPaint = Paint()
        ..color = isSelected
            ? selectedColor.withValues(alpha: 0.6)
            : dotColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, dotRadius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    // Always repaint — selectedDots is mutated in place so reference
    // comparison is unreliable, and currentTouch changes every frame.
    return true;
  }
}
