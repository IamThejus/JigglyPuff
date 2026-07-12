import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A tiny smoothed line chart for trend hints (e.g. load average). Renders
/// nothing meaningful for <2 points.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.accent,
    this.height = 28,
    this.width = 72,
  });

  final List<double> values;
  final Color color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(values, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    Offset pointAt(int i) {
      final norm = (values[i] - minV) / span; // 0..1
      return Offset(i * dx, size.height - norm * size.height);
    }

    final path = Path()..moveTo(0, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = pointAt(i - 1);
      final p1 = pointAt(i);
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}
