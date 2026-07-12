/// 4px-baseline spacing scale + shape radii from the design system.
class Space {
  Space._();

  static const base = 4.0;
  static const stackGap = 12.0; // vertical rhythm between cards
  static const gutter = 16.0; // padding inside cards
  static const containerPadding = 20.0; // screen outer margins
  static const sectionMargin = 32.0;
}

/// Soft-Industrial corner radii.
class Radii {
  Radii._();

  static const sm = 4.0;
  static const chip = 8.0;
  static const card = 16.0; // 1rem primary cards
  static const full = 9999.0;
}
