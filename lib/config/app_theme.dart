import 'package:flutter/material.dart';

import 'palette.dart';

/// Turns the [Palette] into Material themes. Colours are not defined here:
/// see `palette.dart`. This file owns the typeface and the type scale.
abstract final class AppTheme {
  static const font = 'Bricolage';

  static ThemeData light() => _build(Palette.light, Brightness.light);
  static ThemeData dark() => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette p, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: b)
        .copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          surface: p.paper,
          onSurface: p.ink,
          error: p.error,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: p.paper,
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: .25),
        selectionHandleColor: p.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        actionTextColor: p.paper,
        contentTextStyle: TextStyle(
          fontFamily: font,
          color: p.paper,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Text styles named for what they are, read from the palette in context.
extension AppText on BuildContext {
  Palette get palette => Palette.of(this);

  TextStyle get display => TextStyle(
    fontSize: 28,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
    color: palette.ink,
  );
  TextStyle get heading => TextStyle(
    fontSize: 19,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -.3,
    color: palette.ink,
  );
  TextStyle get title => TextStyle(
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -.1,
    color: palette.ink,
  );
  TextStyle get body => TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: palette.inkSoft,
  );
  TextStyle get caption => TextStyle(
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: palette.muted,
  );

  /// The small spaced capitals used for labels across the app.
  TextStyle get label => TextStyle(
    fontSize: 10.5,
    height: 1.3,
    letterSpacing: 1.9,
    fontWeight: FontWeight.w600,
    color: palette.ink,
  );

  /// Prices: tabular figures so columns of them line up.
  TextStyle get price => TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: palette.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
