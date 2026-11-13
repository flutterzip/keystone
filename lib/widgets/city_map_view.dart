import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../config/palette.dart';
import '../models/city_map.dart';
import '../models/home.dart';

/// A pin on the map.
class MapPin {
  const MapPin({required this.id, required this.at, required this.label});

  final String id;
  final GeoPoint at;
  final String label;
}

/// The stylised city: streets, parks and the river drawn in code from the
/// seed, with pins placed by coordinate. No map SDK and no keys.
///
/// The view is centred on [focus] at [zoom] (1 fits the whole city's short
/// side) and glides when either changes. With [interactive] it can be
/// dragged and pinched.
class CityMapView extends StatefulWidget {
  const CityMapView({
    super.key,
    required this.map,
    required this.focus,
    this.zoom = 2.2,
    this.pins = const [],
    this.selected,
    this.onPin,
    this.onBackground,
    this.interactive = false,
    this.dot,
  });

  final CityMap map;
  final GeoPoint focus;
  final double zoom;
  final List<MapPin> pins;
  final String? selected;
  final ValueChanged<String>? onPin;
  final VoidCallback? onBackground;
  final bool interactive;

  /// A single place marked with a brass dot and a soft ring, with no label:
  /// the home on its own page.
  final GeoPoint? dot;

  @override
  State<CityMapView> createState() => _CityMapViewState();
}

class _CityMapViewState extends State<CityMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide;
  late Offset _centre = widget.map.project(widget.focus);
  late double _zoom = widget.zoom;
  Offset _fromCentre = Offset.zero, _toCentre = Offset.zero;
  double _fromZoom = 1, _toZoom = 1;
  double _pinchStart = 1;

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: Motion.long)
      ..addListener(() {
        final t = Motion.settle.transform(_glide.value);
        setState(() {
          _centre = Offset.lerp(_fromCentre, _toCentre, t)!;
          _zoom = _fromZoom + (_toZoom - _fromZoom) * t;
        });
      });
  }

  @override
  void didUpdateWidget(CityMapView old) {
    super.didUpdateWidget(old);
    final target = widget.map.project(widget.focus);
    if (target != old.map.project(old.focus) || widget.zoom != old.zoom) {
      _fromCentre = _centre;
      _toCentre = target;
      _fromZoom = _zoom;
      _toZoom = widget.zoom;
      if (Motion.reduced(context)) {
        setState(() {
          _centre = _toCentre;
          _zoom = _toZoom;
        });
      } else {
        _glide.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        // The city is a square whose side is the view's short side at zoom 1.
        final side = math.max(size.width, size.height) * _zoom;
        // Keep the view inside the city.
        final halfW = size.width / 2 / side, halfH = size.height / 2 / side;
        final c = Offset(
          halfW >= .5 ? .5 : _centre.dx.clamp(halfW, 1 - halfW),
          halfH >= .5 ? .5 : _centre.dy.clamp(halfH, 1 - halfH),
        );
        final origin = Offset(
          size.width / 2 - c.dx * side,
          size.height / 2 - c.dy * side,
        );
        Offset place(GeoPoint g) => origin + widget.map.project(g) * side;

        final view = Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CityPainter(
                    map: widget.map,
                    origin: origin,
                    side: side,
                    p: p,
                  ),
                ),
              ),
            ),
            if (widget.dot != null) _Dot(at: place(widget.dot!)),
            // The chosen pin last, so it sits on top of its neighbours.
            for (final pin in [
              ...widget.pins.where((x) => x.id != widget.selected),
              ...widget.pins.where((x) => x.id == widget.selected),
            ])
              _PinView(
                key: ValueKey(pin.id),
                pin: pin,
                at: place(pin.at),
                selected: pin.id == widget.selected,
                onTap: widget.onPin == null
                    ? null
                    : () => widget.onPin!(pin.id),
              ),
          ],
        );
        if (!widget.interactive) return view;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBackground,
          onScaleStart: (_) {
            _glide.stop();
            _pinchStart = _zoom;
          },
          onScaleUpdate: (d) => setState(() {
            _zoom = (_pinchStart * d.scale).clamp(1.0, 6.0);
            _centre = c - d.focalPointDelta / side;
          }),
          child: view,
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.at});

  final Offset at;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Positioned(
      left: at.dx - 34,
      top: at.dy - 34,
      child: IgnorePointer(
        child: Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: .18),
            shape: BoxShape.circle,
            border: Border.all(color: p.accent.withValues(alpha: .45)),
          ),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: p.accent,
              shape: BoxShape.circle,
              border: Border.all(color: p.card, width: 3),
              boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

/// A price in a bubble with a small tail, standing on its place.
class _PinView extends StatelessWidget {
  const _PinView({
    super.key,
    required this.pin,
    required this.at,
    required this.selected,
    required this.onTap,
  });

  final MapPin pin;
  final Offset at;
  final bool selected;
  final VoidCallback? onTap;

  static const _w = 96.0, _h = 48.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = selected ? p.accent : p.card;
    final fg = selected ? p.onAccent : p.ink;
    return Positioned(
      left: at.dx - _w / 2,
      top: at.dy - _h,
      width: _w,
      height: _h,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Home at ${pin.label}',
        excludeSemantics: true,
        child: GestureDetector(
          key: Key('pin-${pin.id}'),
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedScale(
              scale: selected ? 1.14 : 1,
              alignment: Alignment.bottomCenter,
              duration: Motion.short,
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: Motion.quick,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? bg : p.line),
                      boxShadow: [
                        BoxShadow(
                          color: p.shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      pin.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: const Size(12, 6),
                    painter: _TailPainter(bg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, -1)
      ..lineTo(size.width, -1)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

class _CityPainter extends CustomPainter {
  const _CityPainter({
    required this.map,
    required this.origin,
    required this.side,
    required this.p,
  });

  final CityMap map;
  final Offset origin;
  final double side;
  final Palette p;

  Path _through(List<Offset> points, {bool close = false}) {
    final path = Path();
    for (final (i, pt) in points.indexed) {
      final o = origin + pt * side;
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    if (close) path.close();
    return path;
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    double size = 10,
    double spacing = 1.6,
    bool italic = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: italic ? text : text.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTheme.font,
          fontSize: size,
          letterSpacing: spacing,
          fontWeight: FontWeight.w600,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = p.mapLand);
    // Streets thicken as the view closes in, but less than the city grows.
    final k = math.sqrt(side / 900).clamp(.7, 2.4);

    final park = Paint()
      ..color = p.mapPark
      ..style = PaintingStyle.fill;
    final parkEdge = Paint()
      ..color = p.mapPark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14 * k
      ..strokeJoin = StrokeJoin.round;
    for (final poly in map.parks) {
      final path = _through(poly, close: true);
      canvas.drawPath(path, park);
      canvas.drawPath(path, parkEdge);
    }

    final street = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in map.streets) {
      canvas.drawPath(
        _through(s),
        street
          ..color = p.mapStreet
          ..strokeWidth = 2.2 * k,
      );
    }
    for (final a in map.avenues) {
      canvas.drawPath(
        _through(a),
        street
          ..color = p.mapBlock
          ..strokeWidth = 8.5 * k,
      );
    }
    for (final a in map.avenues) {
      canvas.drawPath(
        _through(a),
        street
          ..color = p.mapStreet
          ..strokeWidth = 6 * k,
      );
    }

    final water = _through(map.water, close: true);
    canvas.drawPath(water, Paint()..color = p.mapWater);
    canvas.drawPath(
      water,
      Paint()
        ..color = p.mapStreet.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * k,
    );
    if (map.waterName.isNotEmpty) {
      _label(
        canvas,
        map.waterName,
        origin + const Offset(.6, .92) * side,
        color: p.ink.withValues(alpha: .35),
        size: 13,
        spacing: 3,
        italic: true,
      );
    }
    for (final a in map.areas) {
      _label(
        canvas,
        a.name,
        origin + map.project(a.at) * side + Offset(0, 16 * k),
        color: p.muted,
        size: 9.5,
      );
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.origin != origin || old.side != side || old.p != p || old.map != map;
}
