import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular ring gauge with a thick semi-transparent track, a round-capped
/// active arc that glows in its status color, and the metric centered inside.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.percent, // 0..100
    required this.label,
    this.trailing,
    this.color,
    this.strokeWidth = 8,
  });

  final double percent;
  final String label;
  final Widget? trailing; // top-right slot (status dot / icon)
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final target = percent.clamp(0, 100).toDouble();
    // Colour follows the *target* value so it never flickers mid-animation.
    final c = color ?? barColor(target);
    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            children: [
              // Ring (animated sweep)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CustomPaint(
                    painter: _RingPainter(percent: value, color: c, stroke: strokeWidth),
                  ),
                ),
              ),
              // Top row: label + trailing indicator
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label.toUpperCase(), style: AppText.labelTechnical()),
                    ?trailing,
                  ],
                ),
              ),
              // Centre metric (animated count-up), centred in the ring.
              Positioned.fill(
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      text: value.toStringAsFixed(0),
                      style: AppText.displayMetrics(),
                      children: [
                        TextSpan(
                            text: '%',
                            style: AppText.headlineMd(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent, required this.color, required this.stroke});
  final double percent;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2; // 12 o'clock
    final sweep = 2 * math.pi * (percent / 100);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.onSurface.withValues(alpha: 0.05);
    canvas.drawCircle(center, radius, track);

    if (percent <= 0) return;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, start, sweep, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawArc(rect, start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.color != color || old.stroke != stroke;
}
