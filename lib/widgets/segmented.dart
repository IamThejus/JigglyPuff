import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A segmented control whose selected pink pill **slides** between options
/// (and whose labels crossfade their colour) rather than jump-cutting.
class AnimatedSegmented extends StatelessWidget {
  const AnimatedSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 40,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  static const _dur = Duration(milliseconds: 250);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / labels.length;
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                // Sliding selection pill.
                AnimatedPositioned(
                  duration: _dur,
                  curve: _curve,
                  left: index * segW,
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(Radii.sm + 2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: _dur,
                              curve: _curve,
                              style: AppText.labelTechnical(
                                  color: i == index
                                      ? AppColors.onAccent
                                      : AppColors.onSurfaceVariant),
                              child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
