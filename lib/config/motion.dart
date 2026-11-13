import 'package:flutter/widgets.dart';

/// How things move. How long the app *waits* is a different question and
/// lives in `AppTiming`.
abstract final class Motion {
  static const quick = Duration(milliseconds: 180);
  static const short = Duration(milliseconds: 250);
  static const medium = Duration(milliseconds: 400);
  static const long = Duration(milliseconds: 600);

  /// A screen's sections rising in, from one controller sliced by intervals.
  static const entrance = Duration(milliseconds: 900);

  /// Sign in hands over to the shell, and sign out hands back.
  static const handOff = Duration(milliseconds: 700);

  /// A removed row blowing away, and the gap it leaves closing.
  static const dust = Duration(milliseconds: 900);

  /// Book a viewing arriving through ink, from the button.
  static const inkRoute = Duration(milliseconds: 900);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const settle = Curves.easeOutQuart;

  /// Ambient loops (the mesh gradient, the key card's sway) run only when
  /// this is true. Tests switch it off so `pumpAndSettle` can settle.
  static bool ambient = true;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static bool loops(BuildContext context) => ambient && !reduced(context);
}
