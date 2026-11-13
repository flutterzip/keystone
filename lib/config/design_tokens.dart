/// Spacing, radii and sizes. Widgets read these instead of inlining numbers.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  /// The page gutter used by every screen.
  static const gutter = 20.0;
}

abstract final class Radii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

abstract final class Sizes {
  static const fieldHeight = 54.0;
  static const buttonHeight = 54.0;

  /// Room a scrolling page leaves at the bottom for the floating tab bar.
  static const tabBarReserve = 104.0;
}
