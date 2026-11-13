import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keystone/kit/kit.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/motion.dart';
import '../../models/account.dart';
import '../../widgets/keystone_mark.dart';

/// The resident key card, as holographic foil that follows the phone's
/// tilt. The fine bright line work (arches inside arches) is what carries
/// the foil; the dark ground keeps a faint sheen. Still, and plain, under
/// reduce motion.
class KeyCard extends StatefulWidget {
  const KeyCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends State<KeyCard> {
  // The same widget instance for the same details and colours, so a rebuild
  // of the profile page does not make the foil photograph the card again.
  Widget? _face;
  Object? _faceOf;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final p = context.palette;
    final of = (
      profile.name,
      profile.memberNumber,
      profile.memberSince,
      p.keyCard,
      p.keyLine,
    );
    if (_face == null || _faceOf != of) {
      _faceOf = of;
      // Composed once at a design size and scaled to fit, so the card looks
      // the same on every phone and at every text size, like a printed one.
      _face = FittedBox(
        child: SizedBox(
          width: 340,
          height: 210,
          child: MediaQuery.withNoTextScaling(
            child: _Face(
              name: profile.name,
              number: profile.memberNumber,
              since: profile.memberSince,
              ground: p.keyCard,
              line: p.keyLine,
            ),
          ),
        ),
      );
    }
    final face = _face!;
    return Semantics(
      label:
          '${AppBrand.name} resident key, ${profile.name}, since ${profile.memberSince}',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 340 / 210,
        child: Motion.loops(context)
            ? RepaintBoundary(
                child: HoloCard(finish: HoloFinish.engraved, child: face),
              )
            : face,
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.name,
    required this.number,
    required this.since,
    required this.ground,
    required this.line,
  });

  final String name;
  final String number;
  final int since;
  final Color ground;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
      fontFamily: AppTheme.font,
      fontSize: 9,
      letterSpacing: 2.2,
      fontWeight: FontWeight.w600,
      color: line.withValues(alpha: .75),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: CustomPaint(
        painter: _ArchesPainter(ground, line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KeystoneMark(size: 24, color: line, keyColor: line),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      AppBrand.name.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        fontSize: 14,
                        letterSpacing: 4.5,
                        fontWeight: FontWeight.w700,
                        color: line,
                      ),
                    ),
                  ),
                  Text('RESIDENT KEY', style: label),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  fontSize: 21,
                  letterSpacing: -.2,
                  fontWeight: FontWeight.w600,
                  color: line,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label,
                    ),
                  ),
                  Text('SINCE $since', style: label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arches inside arches, receding like a colonnade seen from its end.
class _ArchesPainter extends CustomPainter {
  const _ArchesPainter(this.ground, this.line);

  final Color ground;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..isAntiAlias = true;
    final cx = size.width * .74;
    final foot = size.height * 1.02;
    for (var i = 0; i < 15; i++) {
      final r = 16.0 + i * 13;
      final top = size.height * .56 - i * 5.5;
      paint.color = line.withValues(alpha: i % 3 == 0 ? .42 : .16);
      canvas.drawPath(
        Path()
          ..moveTo(cx - r, foot)
          ..lineTo(cx - r, top)
          ..arcToPoint(Offset(cx + r, top), radius: Radius.circular(r))
          ..lineTo(cx + r, foot),
        paint,
      );
    }
    // The courses of the floor running to the far door.
    for (var i = 1; i <= 5; i++) {
      final a = math.pi * (.5 + (i - 3) * .09);
      paint.color = line.withValues(alpha: .1);
      canvas.drawLine(
        Offset(cx, size.height * .78),
        Offset(cx + math.cos(a) * 400, size.height * .78 + math.sin(a) * 400),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArchesPainter old) =>
      old.ground != ground || old.line != line;
}
