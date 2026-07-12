import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill-shaped status label with a 6px "pulse" dot. Monospaced text.
/// Used for service health, connectivity, torrent state badges, etc.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.level,
    this.filledDot = true,
  });

  final String label;
  final StatusLevel level;
  final bool filledDot;

  @override
  Widget build(BuildContext context) {
    final c = level.color;
    final isError = level == StatusLevel.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.errorContainer.withValues(alpha: 0.2)
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(
          color: isError ? c.withValues(alpha: 0.3) : AppColors.glassStroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppText.labelTechnical(color: isError ? AppColors.errorText : AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// A pulsing connectivity dot (the "online" indicator).
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.level, this.size = 8});
  final StatusLevel level;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.level.color;
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Expanding halo
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Container(
                width: widget.size * (0.8 + 1.2 * _c.value),
                height: widget.size * (0.8 + 1.2 * _c.value),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.5 * (1 - _c.value)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
