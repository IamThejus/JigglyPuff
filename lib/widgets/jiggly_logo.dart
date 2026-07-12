import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The JigglyPuff mascot — a stylised round creature drawn as pink line-art
/// (round body, two ears, a forehead curl, big eyes) with an optional sparkle.
/// Scales to whatever [size] it's given; used small in the app bar and large
/// on the splash screen.
class JigglyLogo extends StatelessWidget {
  const JigglyLogo({super.key, this.size = 28, this.color = AppColors.accent, this.stroke = 2, this.sparkle = false});

  final double size;
  final Color color;
  final double stroke;
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _JigglyPainter(color: color, stroke: stroke * (size / 28), sparkle: sparkle),
      ),
    );
  }
}

class _JigglyPainter extends CustomPainter {
  _JigglyPainter({required this.color, required this.stroke, required this.sparkle});
  final Color color;
  final double stroke;
  final bool sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final cx = w * 0.5;
    final cy = h * 0.55;
    final r = w * 0.33; // body radius

    // Round balloon body.
    canvas.drawCircle(Offset(cx, cy), r, line);

    // Two short, pointed cat-style ears sitting on the crown.
    Path ear(double dir) => Path()
      ..moveTo(cx + dir * r * 0.30, cy - r * 0.93) // inner base (on the crown)
      ..lineTo(cx + dir * r * 0.72, cy - r * 1.48) // apex
      ..lineTo(cx + dir * r * 0.86, cy - r * 0.72) // outer base
      ..close();
    canvas.drawPath(ear(-1), line);
    canvas.drawPath(ear(1), line);

    // Signature forehead curl: a ~300° open spiral with a little tail,
    // swept toward the upper-left of the face.
    final curlC = Offset(cx - r * 0.14, cy - r * 0.52);
    final curlR = r * 0.26;
    final curl = Path()
      ..addArc(Rect.fromCircle(center: curlC, radius: curlR), -math.pi * 0.35, math.pi * 1.7)
      ..relativeCubicTo(-curlR * 0.2, curlR * 0.7, curlR * 0.6, curlR * 1.1, curlR * 1.15, curlR * 0.7);
    canvas.drawPath(curl, line);

    // Big eyes, placed high on the face, each with a highlight.
    final eyeR = r * 0.23;
    for (final s in [-1, 1]) {
      final ec = Offset(cx + s * r * 0.40, cy - r * 0.04);
      canvas.drawCircle(ec, eyeR, line);
      canvas.drawCircle(Offset(ec.dx - eyeR * 0.28, ec.dy - eyeR * 0.30), eyeR * 0.30, fill);
    }

    // Little feet hint at the base.
    for (final s in [-1, 1]) {
      final fx = cx + s * r * 0.34;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(fx, cy + r * 0.98), radius: r * 0.14),
        math.pi, math.pi, false, line,
      );
    }

    if (sparkle) {
      _sparkle(canvas, Offset(w * 0.84, h * 0.16), w * 0.055, fill);
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      path.moveTo(c.dx, c.dy);
      path.lineTo(c.dx + math.cos(a - 0.35) * r * 0.5, c.dy + math.sin(a - 0.35) * r * 0.5);
      path.lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      path.lineTo(c.dx + math.cos(a + 0.35) * r * 0.5, c.dy + math.sin(a + 0.35) * r * 0.5);
      path.close();
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_JigglyPainter old) => old.color != color || old.stroke != stroke;
}

/// The wordmark used beside the logo — "JIGGLYPUFF" in tight mono caps.
class JigglyWordmark extends StatelessWidget {
  const JigglyWordmark({super.key, this.fontSize = 16});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'JIGGLYPUFF',
      style: AppText.labelCaps(color: AppColors.primary).copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
