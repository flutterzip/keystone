import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Every spring and duration the widgets use, in one place.
abstract final class Springs {
  /// Settles fast with no overshoot. Selection, snapping.
  static const snappy = SpringDescription(mass: 1, stiffness: 420, damping: 36);

  /// A small overshoot. Travel between targets.
  static const lively = SpringDescription(mass: 1, stiffness: 340, damping: 25);

  /// One visible overshoot. Presses, pops.
  static const bouncy = SpringDescription(mass: 1, stiffness: 340, damping: 19);

  /// Slow and soft. State blends, ambient changes.
  static const gentle = SpringDescription(mass: 1, stiffness: 120, damping: 22);

  /// Several overshoots. Liquid and jelly.
  static const wobbly = SpringDescription(mass: 1, stiffness: 260, damping: 13);
}

abstract final class Beats {
  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
}

extension SpringDrive on AnimationController {
  /// Springs an unbounded controller to [target], carrying current velocity.
  TickerFuture springTo(
    double target, {
    SpringDescription spring = Springs.snappy,
    double? velocity,
  }) {
    return animateWith(
      SpringSimulation(spring, value, target, velocity ?? this.velocity),
    );
  }
}

bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
