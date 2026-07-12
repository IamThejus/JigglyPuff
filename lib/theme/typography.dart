import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Three typefaces, three intents (per DESIGN.md):
///  - Manrope        → headlines & big data metrics ("the pulse").
///                     The design specifies Geist, which isn't in the
///                     `google_fonts` registry; Manrope is the closest premium
///                     geometric grotesque and matches the intent. Swap here if
///                     you bundle the real Geist `.ttf` under `assets/`.
///  - Inter          → body / general UI copy
///  - JetBrains Mono → technical labels, timestamps, status text
///
/// Fonts are loaded at runtime via `google_fonts` (fetched + cached on first
/// launch). No font files are bundled.
class AppText {
  AppText._();

  static TextStyle _geist({
    required double size,
    required FontWeight weight,
    double? height,
    double? spacing,
    Color color = AppColors.primary,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );

  static TextStyle _mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    double? height,
    double spacing = 0,
    Color color = AppColors.onSurfaceVariant,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );

  // --- Metrics & headlines (Geist) ---
  static TextStyle displayMetrics({Color color = AppColors.primary}) =>
      _geist(size: 44, weight: FontWeight.w700, height: 1.0, spacing: -1.6, color: color);

  static TextStyle headlineLg({Color color = AppColors.primary}) =>
      _geist(size: 30, weight: FontWeight.w600, height: 1.15, spacing: -0.6, color: color);

  static TextStyle headlineMd({Color color = AppColors.primary}) =>
      _geist(size: 20, weight: FontWeight.w600, height: 1.4, color: color);

  // --- Body (Inter) ---
  static TextStyle bodyLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(fontSize: 16, height: 1.5, color: color);

  static TextStyle bodySm({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(fontSize: 14, height: 1.43, color: color);

  // --- Technical labels (JetBrains Mono) ---
  /// Small-caps section descriptor, e.g. "CPU", "STORAGE POOL".
  static TextStyle labelCaps({Color color = AppColors.onSurfaceVariant}) =>
      _mono(size: 12, weight: FontWeight.w500, height: 1.33, spacing: 0.96, color: color);

  /// Dense metadata / timestamps, e.g. "12d 4h", "12.4 MB/s".
  static TextStyle labelTechnical({Color color = AppColors.onSurfaceVariant}) =>
      _mono(size: 11, height: 1.27, color: color);
}
