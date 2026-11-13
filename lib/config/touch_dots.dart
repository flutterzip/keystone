import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shows where fingers are, for screen recordings: a soft dot under each
/// touch and a ring that opens where it lands. Only built when the launch
/// token `touches` is given (see `LaunchHooks`), and it never takes a touch
/// away from the app underneath.
class TouchDots extends StatefulWidget {
  const TouchDots({super.key, required this.child});

  final Widget child;

  @override
  State<TouchDots> createState() => _TouchDotsState();
}

class _Touch {
  _Touch(this.at, this.ring);

  Offset at;
  bool down = true;
  final AnimationController ring;
}

class _TouchDotsState extends State<TouchDots> with TickerProviderStateMixin {
  final _touches = <int, _Touch>{};
  final _repaint = ValueNotifier(0);

  void _down(PointerDownEvent e) {
    final ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(() => _repaint.value++);
    _touches[e.pointer] = _Touch(e.position, ring);
    ring.forward();
  }

  void _move(PointerMoveEvent e) {
    _touches[e.pointer]?.at = e.position;
    _repaint.value++;
  }

  void _up(PointerEvent e) {
    final touch = _touches[e.pointer];
    if (touch == null) return;
    touch.down = false;
    // The dot outlives a quick tap, or a tap would never be seen.
    touch.ring.forward().whenCompleteOrCancel(() {
      if (!mounted) return;
      _touches.remove(e.pointer)?.ring.dispose();
      _repaint.value++;
    });
  }

  @override
  void dispose() {
    for (final touch in _touches.values) {
      touch.ring.dispose();
    }
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: CustomPaint(
        foregroundPainter: _DotsPainter(
          _touches,
          context.palette.accent,
          context.palette.onPhoto,
          _repaint,
        ),
        child: widget.child,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.touches, this.fill, this.edge, Listenable repaint)
    : super(repaint: repaint);

  final Map<int, _Touch> touches;
  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    for (final touch in touches.values) {
      final t = Curves.easeOutCubic.transform(touch.ring.value);
      final fade = touch.down ? 1.0 : 1 - t;
      canvas.drawCircle(
        touch.at,
        22 + 30 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = fill.withValues(alpha: 0.7 * (1 - t)),
      );
      canvas.drawCircle(
        touch.at,
        21,
        Paint()..color = fill.withValues(alpha: 0.42 * fade),
      );
      canvas.drawCircle(
        touch.at,
        21,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = edge.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => true;
}
