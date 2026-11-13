import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// The geometry of the mark, on a unit square: an arch of cut stones over a
/// doorway, locked by the one stone that gives the product its name.
/// `tool/make_mark.py` draws the app icon from the same numbers; keep the
/// two in step.
abstract final class MarkGeometry {
  static const cx = .5, cy = .535;
  static const outer = .40, inner = .215;
  static const foot = .93;
  static const gap = .024;

  /// How far the keystone stands proud of the arch, above and below.
  static const keyRise = .055, keyHang = .028;

  static Offset _polar(double r, double deg) => Offset(
    cx + r * math.cos(deg * math.pi / 180),
    cy - r * math.sin(deg * math.pi / 180),
  );

  static List<Offset> _wedge(double from, double to, double r0, double r1) {
    // Half a joint is taken off each side, measured at the middle radius.
    final trim = gap / 2 / ((r0 + r1) / 2) * 180 / math.pi;
    final a = from - trim, b = to + trim;
    const steps = 14;
    return [
      for (var i = 0; i <= steps; i++) _polar(r1, a + (b - a) * i / steps),
      for (var i = steps; i >= 0; i--) _polar(r0, a + (b - a) * i / steps),
    ];
  }

  static List<Offset> _block(double x0, double y0, double x1, double y1) => [
    Offset(x0, y0),
    Offset(x1, y0),
    Offset(x1, y1),
    Offset(x0, y1),
  ];

  static final double _pierMid = (cy + foot) / 2;

  /// The stones in the order they are laid: (outline, course, which way it
  /// arrives from). The last one is the keystone.
  static final List<(List<Offset>, int, Offset)> stones = [
    for (final left in [true, false]) ...[
      (
        _block(
          left ? cx - outer : cx + inner,
          _pierMid + gap / 2,
          left ? cx - inner : cx + outer,
          foot,
        ),
        0,
        const Offset(0, 1),
      ),
      (
        _block(
          left ? cx - outer : cx + inner,
          cy + gap / 2,
          left ? cx - inner : cx + outer,
          _pierMid - gap / 2,
        ),
        1,
        const Offset(0, 1),
      ),
      (
        left ? _wedge(180, 144, inner, outer) : _wedge(36, 0, inner, outer),
        2,
        Offset(left ? -1 : 1, -.35),
      ),
      (
        left ? _wedge(144, 108, inner, outer) : _wedge(72, 36, inner, outer),
        3,
        Offset(left ? -.7 : .7, -.8),
      ),
    ],
    (_wedge(108, 72, inner - keyHang, outer + keyRise), 4, const Offset(0, -1)),
  ];

  static const courses = 5;

  /// The doorway under the arch, for anything that wants to look through it.
  static Path door(Rect square) {
    final s = square.width;
    Offset at(double x, double y) => square.topLeft + Offset(x * s, y * s);
    return Path()
      ..moveTo(at(cx - inner, foot).dx, at(cx - inner, foot).dy)
      ..lineTo(at(cx - inner, cy).dx, at(cx - inner, cy).dy)
      ..arcToPoint(at(cx + inner, cy), radius: Radius.circular(inner * s))
      ..lineTo(at(cx + inner, foot).dx, at(cx + inner, foot).dy)
      ..close();
  }
}

/// The Keystone mark. [built] runs 0 to 1: the piers rise, the arch stones
/// are set from both sides, and the keystone drops in last and locks them.
class KeystoneMark extends StatelessWidget {
  const KeystoneMark({
    super.key,
    this.size = 56,
    this.color,
    this.keyColor,
    this.built = 1,
  });

  final double size;

  /// The stones. Defaults to the ink.
  final Color? color;

  /// The keystone. Defaults to the accent.
  final Color? keyColor;
  final double built;

  /// The point of [built] at which the keystone lands.
  static const locksAt = .86;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _MarkPainter(color ?? p.ink, keyColor ?? p.accent, built),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color, this.keyColor, this.build);

  final Color color;
  final Color keyColor;
  final double build;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..isAntiAlias = true;
    for (final (outline, course, from) in MarkGeometry.stones) {
      final isKey = course == MarkGeometry.courses - 1;
      // Each course starts a beat after the one below; the keystone waits
      // for the arch, then falls.
      final start = isKey ? .64 : course * .15;
      final length = isKey ? KeystoneMark.locksAt - start : .34;
      final t = ((build - start) / length).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final travel = isKey
          ? Curves.easeInQuad.transform(t)
          : Curves.easeOutCubic.transform(t);
      final shift = from * ((1 - travel) * (isKey ? .34 : .12) * s);
      final path = Path()
        ..addPolygon([for (final o in outline) o * s + shift], true);
      paint.color = (isKey ? keyColor : color).withValues(
        alpha: (isKey ? keyColor : color).a * (t * 2.2).clamp(0.0, 1.0),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.keyColor != keyColor || old.build != build;
}
