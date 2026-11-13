import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Throws a copy of something from where it is to where it is going: a
/// product into the basket, a file into a folder.
///
/// Runs in the root overlay, so it survives the sheet or page it started
/// from being closed. [onLanded] fires on arrival: add the item to the cart
/// there, so the badge ticks when the thing lands and not before.
///
/// ```dart
/// FlyTo.launch(context, from: imageKey, to: cartIconKey,
///     child: Image.asset(product.image), onLanded: () => cart.add(product));
/// ```
abstract final class FlyTo {
  static void launch(
    BuildContext context, {
    required GlobalKey from,
    required GlobalKey to,
    required Widget child,
    VoidCallback? onLanded,
    Duration duration = const Duration(milliseconds: 780),
    double endScale = 0.2,
  }) {
    final a = from.currentContext?.findRenderObject();
    final b = to.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (a is! RenderBox || b is! RenderBox || overlay == null || reduce) {
      onLanded?.call();
      return;
    }
    final start = a.localToGlobal(Offset.zero) & a.size;
    final end = b.localToGlobal(b.size.center(Offset.zero));
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Flight(
        start: start,
        end: end,
        duration: duration,
        endScale: endScale,
        onDone: () {
          entry.remove();
          onLanded?.call();
        },
        child: child,
      ),
    );
    overlay.insert(entry);
  }
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.start,
    required this.end,
    required this.duration,
    required this.endScale,
    required this.onDone,
    required this.child,
  });

  final Rect start;
  final Offset end;
  final Duration duration;
  final double endScale;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: widget.duration)
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// A point on the arc, bowed above both ends.
  Offset _at(double t) {
    final a = widget.start.center;
    final b = widget.end;
    final lift = math.max(90.0, (a - b).distance * 0.35);
    final c = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - lift);
    final u = 1 - t;
    return a * (u * u) + c * (2 * u * t) + b * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(_t.value);
          Widget copy(double at, double opacity) {
            final p = _at(at.clamp(0.0, 1.0));
            final scale = 1 + (widget.endScale - 1) * at.clamp(0.0, 1.0);
            return Positioned(
              left: p.dx - widget.start.width / 2,
              top: p.dy - widget.start.height / 2,
              width: widget.start.width,
              height: widget.start.height,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: at * 0.5,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            );
          }

          return Stack(
            children: [
              // Two ghosts trail the real thing.
              if (t > 0.05 && t < 0.98) copy(t - 0.10, 0.18),
              if (t > 0.05 && t < 0.98) copy(t - 0.05, 0.32),
              copy(t, 1),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
