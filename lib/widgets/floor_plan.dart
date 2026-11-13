import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/home.dart';

/// A floor plan drawn from the home's rooms. [drawn] runs 0 to 1: the walls
/// are ruled in as one line, then the names and areas settle into the rooms.
class FloorPlan extends StatelessWidget {
  const FloorPlan({super.key, required this.rooms, this.drawn = 1});

  final List<Room> rooms;
  final double drawn;

  /// The floor area the plan shows, in whole square metres.
  static int areaOf(List<Room> rooms) =>
      rooms.fold(0.0, (a, r) => a + r.sqm).round();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final w = rooms.fold(0.0, (m, r) => math.max(m, r.x + r.w));
    final h = rooms.fold(0.0, (m, r) => math.max(m, r.y + r.h));
    return Semantics(
      image: true,
      label:
          'Floor plan: ${[for (final r in rooms) '${r.name} ${r.sqm.round()} square metres'].join(', ')}',
      child: AspectRatio(
        aspectRatio: w / h,
        child: CustomPaint(
          painter: _PlanPainter(
            rooms: rooms,
            extent: Size(w, h),
            drawn: drawn,
            wall: p.ink,
            fill: p.card,
            wet: p.accentWash,
            text: p.ink,
            soft: p.muted,
            textScale: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  const _PlanPainter({
    required this.rooms,
    required this.extent,
    required this.drawn,
    required this.wall,
    required this.fill,
    required this.wet,
    required this.text,
    required this.soft,
    required this.textScale,
  });

  final List<Room> rooms;
  final Size extent;
  final double drawn;
  final Color wall, fill, wet, text, soft;
  final TextScaler textScale;

  static bool _isWet(Room r) =>
      r.name.startsWith('Bath') || r.name == 'Kitchen' || r.name == 'Pantry';

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 3.0;
    final k = (size.width - inset * 2) / extent.width;
    Rect rect(Room r) =>
        Rect.fromLTWH(inset + r.x * k, inset + r.y * k, r.w * k, r.h * k);
    final settle = Curves.easeOut.transform(
      ((drawn - .55) / .45).clamp(0.0, 1.0),
    );

    // Floors first, so walls sit on top of every fill.
    for (final r in rooms) {
      canvas.drawRect(
        rect(r),
        Paint()
          ..color = (_isWet(r) ? wet : fill).withValues(
            alpha: (drawn * 1.6).clamp(0.0, 1.0),
          ),
      );
    }

    // Every wall as one path, revealed along its length.
    final walls = Path();
    for (final r in rooms) {
      walls.addRect(rect(r));
    }
    final line = Paint()
      ..color = wall
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.miter;
    final ruled = Curves.easeInOutCubic.transform((drawn / .7).clamp(0.0, 1.0));
    if (ruled >= 1) {
      canvas.drawPath(walls, line);
    } else {
      for (final ui.PathMetric m in walls.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * ruled), line);
      }
    }

    if (settle <= 0) return;
    for (final r in rooms) {
      final box = rect(r);
      final name = TextPainter(
        text: TextSpan(
          text: r.name,
          style: TextStyle(
            fontFamily: AppTheme.font,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: text.withValues(alpha: settle),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScale,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(0, box.width - 8));
      final area = TextPainter(
        text: TextSpan(
          text: '${r.sqm.round()} m²',
          style: TextStyle(
            fontFamily: AppTheme.font,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: soft.withValues(alpha: settle),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScale,
        maxLines: 1,
      )..layout(maxWidth: math.max(0, box.width - 8));
      final both = name.height + area.height + 1 <= box.height - 6;
      final total = both ? name.height + area.height + 1 : name.height;
      if (total > box.height - 2) continue;
      final top = box.center.dy - total / 2 + 4 * (1 - settle);
      name.paint(canvas, Offset(box.center.dx - name.width / 2, top));
      if (both) {
        area.paint(
          canvas,
          Offset(box.center.dx - area.width / 2, top + name.height + 1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PlanPainter old) =>
      old.drawn != drawn ||
      old.rooms != rooms ||
      old.wall != wall ||
      old.fill != fill ||
      old.textScale != textScale;
}
