import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Slim linear progress bar. Colors itself from the utilisation level unless a
/// [color] is forced. Adds a subtle glow to the filled segment.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.percent, // 0..100
    this.color,
    this.height = 6,
    this.autoLevel = false,
    this.brand = true,
  });

  final double percent;
  final Color? color;
  final double height;

  /// When true, the fill color is driven by utilisation thresholds.
  final bool autoLevel;

  /// With [autoLevel]: nominal load is JigglyPuff pink ([brand]=true) or green
  /// ([brand]=false), escalating to amber/red as usage climbs.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final clamped = (percent.clamp(0, 100)) / 100.0;
    final c = color ?? (autoLevel ? barColor(percent, brand: brand) : AppColors.accent);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.full),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.surfaceContainerHighest),
          // Animate the fill width so bars glide to new values on refresh.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped == 0 ? 0.0001 : clamped),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, factor, _) => FractionallySizedBox(
              widthFactor: factor,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(Radii.full),
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
