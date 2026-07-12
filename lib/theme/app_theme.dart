import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

// Re-export the theme primitives so screens/widgets get colors, spacing &
// typography from a single `theme/app_theme.dart` import.
export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';

/// Dark-theme-first ThemeData. The app is designed for the Obsidian dark
/// palette; a lighter variant is intentionally out of scope for v1.
ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentSoft,
      error: AppColors.statusError,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accentDim,
      selectionHandleColor: AppColors.accent,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.primary,
    ),
    dividerColor: AppColors.glassStroke,
    splashColor: AppColors.glassStrokeFaint,
    highlightColor: AppColors.glassStrokeFaint,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.headlineMd(),
    ),
  );
}
