import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/shader_library.dart';

const String islandShaderAsset = 'shaders/island.frag';

/// One thing the island can show.
@immutable
class IslandView {
  const IslandView({
    required this.id,
    required this.size,
    required this.child,
    this.satellite,
  });

  /// Views with different ids cross-fade; the same id only resizes.
  final String id;
  final Size size;
  final Widget child;

  /// Shown in a bubble that splits off to the right.
  final Widget? satellite;
}

/// A black capsule that changes shape to fit what it is showing.
///
/// Size changes ride a spring, so it overshoots and settles like a liquid.
/// A [IslandView.satellite] buds off as a separate drop and is absorbed again
/// when it goes away.
///
/// ```dart
/// MorphingIsland(view: playing ? nowPlaying : idle, onTap: toggle)
/// ```
class MorphingIsland extends StatefulWidget {
  const MorphingIsland({
    super.key,
    required this.view,
    this.onTap,
    this.maxHeight = 200,
  });

  final IslandView view;
  final VoidCallback? onTap;

  /// Room reserved below the top edge for the tallest view.
  final double maxHeight;

  static const double compactHeight = 37;

  @override
  State<MorphingIsland> createState() => _MorphingIslandState();
}

class _MorphingIslandState extends State<MorphingIsland>
    with TickerProviderStateMixin {
  late final AnimationController _w;
  late final AnimationController _h;
  late final AnimationController _split;
  late final Listenable _motion;
  Widget? _satellite;

  static const double _satSize = MorphingIsland.compactHeight;
  static const double _gap = 8;

  @override
  void initState() {
    super.initState();
    final v = widget.view;
    _w = AnimationController.unbounded(vsync: this, value: v.size.width);
    _h = AnimationController.unbounded(vsync: this, value: v.size.height);
    _split = AnimationController.unbounded(
      vsync: this,
      value: v.satellite == null ? 0 : 1,
    );
    _motion = Listenable.merge([_w, _h, _split]);
    _satellite = v.satellite;
  }

  @override
  void didUpdateWidget(MorphingIsland old) {
    super.didUpdateWidget(old);
    final v = widget.view;
    final calm = reduceMotionOf(context);
    if (old.view.size != v.size) {
      final spring = calm ? Springs.snappy : Springs.bouncy;
      _w.springTo(v.size.width, spring: spring);
      _h.springTo(v.size.height, spring: spring);
    }
    if ((old.view.satellite == null) != (v.satellite == null)) {
      _split.springTo(
        v.satellite == null ? 0 : 1,
        spring: calm ? Springs.snappy : Springs.wobbly,
      );
    }
    if (v.satellite != null) _satellite = v.satellite;
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _split.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    return SizedBox(
      height: widget.maxHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final full = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final w = _w.value.clamp(24.0, full);
              final h = _h.value.clamp(24.0, widget.maxHeight);
              final s = _split.value.clamp(0.0, 1.25);
              // The pair stays centred as the drop leaves.
              final shift = (_gap + _satSize) / 2 * s;
              final body = Rect.fromLTWH((full - w) / 2 - shift, 0, w, h);
              final radius = math.min(h / 2, 42.0);
              final satCentre = Offset(
                body.right - _satSize / 2 + (_gap + _satSize) * s,
                _satSize / 2,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ShaderBuilder(
                      asset: islandShaderAsset,
                      builder: (context, shader) => CustomPaint(
                        painter: _IslandPainter(
                          shader,
                          body,
                          radius,
                          satCentre,
                          s > 0.02 ? _satSize / 2 : 0,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: body,
                    child: Semantics(
                      button: widget.onTap != null,
                      label: 'Live activity',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          // Each view keeps its own size and is revealed by
                          // the changing shape, so nothing reflows mid-morph
                          // and the outgoing view is never squeezed.
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: 0,
                            maxWidth: double.infinity,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.none,
                                children: [...previous, ?current],
                              ),
                              transitionBuilder: (child, a) => FadeTransition(
                                opacity: a,
                                child: ScaleTransition(
                                  scale: Tween(begin: 0.9, end: 1.0).animate(a),
                                  child: child,
                                ),
                              ),
                              child: SizedBox.fromSize(
                                key: ValueKey(view.id),
                                size: view.size,
                                child: view.child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_satellite != null && s > 0.02)
                    Positioned(
                      left: satCentre.dx - _satSize / 2,
                      top: 0,
                      width: _satSize,
                      height: _satSize,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: ((s - 0.4) / 0.6).clamp(0.0, 1.0),
                          child: Center(child: _satellite),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _IslandPainter extends CustomPainter {
  const _IslandPainter(
    this.shader,
    this.body,
    this.radius,
    this.satCentre,
    this.satRadius,
  );

  final ui.FragmentShader? shader;
  final Rect body;
  final double radius;
  final Offset satCentre;
  final double satRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = this.shader;
    if (shader == null) {
      final black = Paint()..color = const Color(0xFF000000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(radius)),
        black,
      );
      if (satRadius > 0) canvas.drawCircle(satCentre, satRadius, black);
      return;
    }
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, body.center.dx)
      ..setFloat(3, body.center.dy)
      ..setFloat(4, body.width / 2)
      ..setFloat(5, body.height / 2)
      ..setFloat(6, radius)
      ..setFloat(7, satCentre.dx)
      ..setFloat(8, satCentre.dy)
      ..setFloat(9, satRadius)
      ..setFloat(10, 16);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_IslandPainter old) =>
      old.shader != shader ||
      old.body != body ||
      old.radius != radius ||
      old.satCentre != satCentre ||
      old.satRadius != satRadius;
}
