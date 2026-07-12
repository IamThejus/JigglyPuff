import 'package:flutter/material.dart';

/// "Deep Obsidian" palette from the Dell Server Sentinel design system.
///
/// The interface is deliberately monochrome — color is reserved for *status*
/// and data visualisation only (see [statusColor]).
class AppColors {
  AppColors._();

  // --- Backgrounds & surfaces (tonal elevation: brighter = closer) ---
  static const background = Color(0xFF131313);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainer = Color(0xFF201F1F);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353534);
  static const surfaceBright = Color(0xFF393939);

  // --- Foreground ---
  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFC4C7C8);
  static const outline = Color(0xFF8E9192);
  static const outlineVariant = Color(0xFF444748);
  static const primary = Color(0xFFFFFFFF); // high-contrast text / metrics
  static const onPrimary = Color(0xFF2F3131);

  // --- Brand accent (JigglyPuff pink) ---
  // The signature color: active nav, gauges/bars at nominal load, primary
  // buttons, the mascot. Health greens/ambers/reds are still reserved for
  // explicit status (see [barColor] / [StatusLevel]).
  static const accent = Color(0xFFF76D9E);
  static const accentSoft = Color(0xFFFBA9C8);
  static const accentDim = Color(0xFF3A1F2A); // low-alpha pink container
  static const onAccent = Color(0xFF2A0B15);

  // --- Status tones (used sparingly) ---
  static const statusHealthy = Color(0xFF34D399); // emerald
  static const statusWarning = Color(0xFFF59E0B); // amber-500
  static const statusError = Color(0xFFEF4444); // red-500
  static const errorText = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);

  // Hairline "glass edge" strokes.
  static const glassStroke = Color(0x1AFFFFFF); // white @ 10%
  static const glassStrokeFaint = Color(0x0DFFFFFF); // white @ 5%
  static const trackFaint = Color(0x0DFFFFFF); // gauge/track base @ 5%
}

/// Semantic thresholds → status color. This is the single source of truth for
/// "green healthy / amber warning / red critical" across gauges, bars & chips.
enum StatusLevel { healthy, warning, error, muted }

extension StatusLevelColor on StatusLevel {
  Color get color {
    switch (this) {
      case StatusLevel.healthy:
        return AppColors.statusHealthy;
      case StatusLevel.warning:
        return AppColors.statusWarning;
      case StatusLevel.error:
        return AppColors.statusError;
      case StatusLevel.muted:
        return AppColors.onSurfaceVariant;
    }
  }
}

/// Maps a 0–100 utilisation percentage to a status level.
/// Warning at >80%, critical at >92% — matches the "disk >80%" UX rule.
StatusLevel levelForPercent(double percent, {double warn = 80, double crit = 92}) {
  if (percent >= crit) return StatusLevel.error;
  if (percent >= warn) return StatusLevel.warning;
  return StatusLevel.healthy;
}

/// Fill color for gauges & progress bars.
/// - [brand] (default): nominal load renders in JigglyPuff pink, escalating to
///   amber then red as it climbs — the house style for CPU/memory/storage-pool.
/// - non-brand: nominal load renders green — used where classic "health"
///   semantics read better (per-volume storage cards).
Color barColor(double percent, {bool brand = true, double warn = 80, double crit = 92}) {
  if (percent >= crit) return AppColors.statusError;
  if (percent >= warn) return AppColors.statusWarning;
  return brand ? AppColors.accent : AppColors.statusHealthy;
}

/// Maps a temperature reading to a status level relative to its sensor limits.
StatusLevel levelForTemp(double current, {double? high, double? critical}) {
  if (critical != null && current >= critical) return StatusLevel.error;
  if (high != null && current >= high) return StatusLevel.warning;
  if (high == null && current >= 80) return StatusLevel.warning;
  return StatusLevel.healthy;
}
