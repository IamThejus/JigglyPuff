import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'jiggly_logo.dart';

/// Shared glass top bar: the JigglyPuff mascot + wordmark on the left, a
/// settings gear on the right that pushes the Settings screen.
class ServerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ServerAppBar({super.key, this.showSettings = true});

  final bool showSettings;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background.withValues(alpha: 0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: Space.containerPadding,
      title: Row(
        children: [
          const JigglyLogo(size: 30),
          const SizedBox(width: 10),
          const JigglyWordmark(fontSize: 16),
        ],
      ),
      actions: [
        if (showSettings)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        const SizedBox(width: 8),
      ],
      bottom: const _HairlineBottom(),
    );
  }
}

class _HairlineBottom extends StatelessWidget implements PreferredSizeWidget {
  const _HairlineBottom();

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.glassStroke);
}

/// Wraps scrollable screen content in a themed pull-to-refresh + consistent
/// horizontal padding and bottom inset (so content clears the nav bar).
class RefreshableBody extends StatelessWidget {
  const RefreshableBody({
    super.key,
    required this.onRefresh,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(
      Space.containerPadding,
      Space.gutter,
      Space.containerPadding,
      120,
    ),
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerHigh,
      child: ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}
