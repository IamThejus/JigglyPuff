import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Base "Apple Music"-style surface: tonal elevation + a faint inner glass
/// stroke instead of a drop shadow. All cards build on this.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.gutter),
    this.color = AppColors.surfaceContainerLow,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor ?? AppColors.glassStrokeFaint),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// A titled stat card: mono label top-left, optional trailing icon/indicator,
/// and arbitrary body content. The workhorse layout for the dashboard grid.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.gutter),
  });

  final String label;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: AppText.labelTechnical()),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.stackGap),
          child,
        ],
      ),
    );
  }
}

/// Uppercase mono section heading with an optional trailing action.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, this.trailing, required this.child});
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.stackGap, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: AppText.labelCaps()),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// A framed key/value row, e.g. HOSTNAME → dell-server. Mono on both sides.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.labelTechnical()),
          const SizedBox(width: Space.gutter),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.labelTechnical(color: valueColor ?? AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
