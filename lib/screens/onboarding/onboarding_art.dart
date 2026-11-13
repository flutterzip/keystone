import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/city_map.dart';
import '../../models/home.dart';
import '../../services/viewing_repository.dart';
import '../../widgets/city_map_view.dart';
import '../../widgets/keystone_mark.dart';

/// The art for one onboarding slide. [presence] is 1 when the slide is
/// centred and 0 a full page away, so everything builds on with the drag
/// and reverses with it.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({
    super.key,
    required this.index,
    required this.presence,
    required this.homes,
    required this.map,
  });

  final int index;
  final double presence;
  final List<Home> homes;
  final CityMap map;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      child: FittedBox(
        // Composed once at a design size, so it is the same picture on
        // every phone.
        child: SizedBox(
          width: 320,
          height: 380,
          child: MediaQuery.withNoTextScaling(
            child: switch (index) {
              0 => _SearchArt(t: presence, homes: homes, map: map),
              1 => _ViewingArt(t: presence),
              _ => _SignArt(t: presence),
            },
          ),
        ),
      ),
    ),
  );
}

/// [t] sliced: 0 before [from], 1 after [to], eased between.
double _slice(double t, double from, double to) =>
    Curves.easeOutCubic.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: p.line),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The real map with the real homes pinned on it, under a search pill.
class _SearchArt extends StatelessWidget {
  const _SearchArt({required this.t, required this.homes, required this.map});

  final double t;
  final List<Home> homes;
  final CityMap map;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rent = [
      for (final h in homes)
        if (h.isRent) h,
    ];
    // Pins drop in one after another as the slide arrives.
    final shown = (rent.length * _slice(t, .25, .95)).round();
    return Stack(
      children: [
        Positioned.fill(
          top: 30,
          child: _Sheet(
            child: IgnorePointer(
              child: CityMapView(
                map: map,
                focus: GeoPoint(
                  (map.north + map.south) / 2 - .014,
                  (map.west + map.east) / 2,
                ),
                zoom: 1.5,
                selected: rent.isEmpty ? null : rent.first.id,
                pins: [
                  for (final h in rent.take(shown))
                    MapPin(id: h.id, at: h.at, label: h.price.compact),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          top: 0,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - _slice(t, 0, .5))),
            child: Opacity(
              opacity: _slice(t, 0, .4),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: p.line),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: p.ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Two beds near the river',
                        style: context.title.copyWith(fontSize: 14.5),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: p.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: p.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A week of days, the times on offer (one taken, one chosen) and the
/// countdown pill.
class _ViewingArt extends StatelessWidget {
  const _ViewingArt({required this.t});

  final double t;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const times = DemoViewingRepository.times;
    const chosen = 6, taken = 2;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          top: 24,
          child: _Sheet(
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (i, d) in _days.indexed)
                      Opacity(
                        opacity: _slice(t, .05 * i, .35 + .05 * i),
                        child: Container(
                          width: 50,
                          height: 62,
                          decoration: BoxDecoration(
                            color: i == 2 ? p.primary : p.paper,
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(
                              color: i == 2 ? p.primary : p.line,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                d,
                                style: context.caption.copyWith(
                                  fontSize: 11,
                                  color: i == 2
                                      ? p.onPrimary.withValues(alpha: .8)
                                      : p.muted,
                                ),
                              ),
                              Text(
                                '${14 + i}',
                                style: context.heading.copyWith(
                                  fontSize: 17,
                                  color: i == 2 ? p.onPrimary : p.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, (h, m)) in times.take(9).indexed)
                      Transform.scale(
                        scale: .8 + .2 * _slice(t, .2 + .04 * i, .6 + .04 * i),
                        child: Opacity(
                          opacity: _slice(t, .2 + .04 * i, .55 + .04 * i),
                          child: Container(
                            width: 86,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i == chosen
                                  ? Color.lerp(
                                      p.paper,
                                      p.accent,
                                      _slice(t, .7, 1),
                                    )
                                  : p.paper,
                              borderRadius: BorderRadius.circular(Radii.pill),
                              border: Border.all(
                                color: i == chosen ? p.accent : p.line,
                              ),
                            ),
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                              style: context.title.copyWith(
                                fontSize: 13.5,
                                color: i == taken
                                    ? p.muted
                                    : (i == chosen ? p.onAccent : p.ink),
                                decoration: i == taken
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: p.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Opacity(
                  opacity: _slice(t, .6, 1),
                  child: Row(
                    children: [
                      Icon(Icons.key_rounded, size: 17, color: p.accentInk),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Wed 16 at 14:45, in person',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.title.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // The live pill, dropping onto the top edge of the sheet.
        Transform.translate(
          offset: Offset(0, -18 * (1 - _slice(t, .45, .95))),
          child: Opacity(
            opacity: _slice(t, .45, .8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: p.keyCard,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Viewing in 45 min',
                    style: context.title.copyWith(
                      fontSize: 13.5,
                      color: p.onIsland,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A contract: lines of text, a signature that writes itself, and the mark
/// built and locked as its seal.
class _SignArt extends StatelessWidget {
  const _SignArt({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget line(double width, int i) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: width * _slice(t, .04 * i, .4 + .04 * i),
          height: 7,
          decoration: BoxDecoration(
            color: p.line,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      child: _Sheet(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TENANCY AGREEMENT',
                    style: context.label.copyWith(color: p.accentInk),
                  ),
                ),
                KeystoneMark(size: 44, built: _slice(t, .3, 1)),
              ],
            ),
            const SizedBox(height: 18),
            for (final (i, w) in [
              220.0,
              190.0,
              228.0,
              150.0,
              205.0,
              120.0,
            ].indexed)
              line(w, i),
            const Spacer(),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: _SignaturePainter(_slice(t, .45, 1), p.ink),
              ),
            ),
            Container(height: 1.2, color: p.ink.withValues(alpha: .5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Signed', style: context.caption)),
                Opacity(
                  opacity: _slice(t, .85, 1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: p.positive,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Deposit paid',
                        style: context.caption.copyWith(color: p.positive),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .04, h * .78)
      ..cubicTo(w * .10, h * .05, w * .20, h * .02, w * .19, h * .55)
      ..cubicTo(w * .18, h * .98, w * .10, h * .9, w * .22, h * .55)
      ..cubicTo(w * .30, h * .30, w * .30, h * .9, w * .36, h * .62)
      ..cubicTo(w * .40, h * .42, w * .42, h * .86, w * .47, h * .6)
      ..cubicTo(w * .52, h * .30, w * .50, h * .95, w * .58, h * .58)
      ..cubicTo(w * .64, h * .30, w * .66, h * .80, w * .72, h * .62)
      ..cubicTo(w * .80, h * .40, w * .84, h * .70, w * .96, h * .48);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final ui.PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.t != t || old.color != color;
}
