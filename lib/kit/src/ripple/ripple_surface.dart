import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../core/shader_library.dart';

const String rippleShaderAsset = 'shaders/ripple.frag';

/// Makes its child behave like the surface of water: a touch sends rings
/// through the child's actual pixels.
///
/// Touches are observed, not consumed. While no ring is alive the child is
/// painted normally and nothing ticks.
///
/// ```dart
/// RippleSurface(child: PhotoCard())
/// ```
class RippleSurface extends StatefulWidget {
  const RippleSurface({
    super.key,
    required this.child,
    this.amplitude = 12,
    this.speed = 520,
    this.wavelength = 34,
  });

  final Widget child;

  /// How far a crest pushes pixels, in logical pixels.
  final double amplitude;

  /// How fast a ring travels, in logical pixels per second.
  final double speed;
  final double wavelength;

  @override
  State<RippleSurface> createState() => RippleSurfaceState();
}

class RippleSurfaceState extends State<RippleSurface>
    with SingleTickerProviderStateMixin {
  static const int _slots = 6;
  static const double _lifetime = 3.2;

  late final Ticker _ticker;
  final _snapshot = SnapshotController();
  final _painter = _RipplePainter();
  final List<double> _rings = List.filled(_slots * 3, -1);
  int _next = 0;
  double _clock = 0;
  Duration _last = Duration.zero;
  Offset? _lastDrop;

  @override
  void initState() {
    super.initState();
    // Created up front: a ticker made lazily would be made during dispose
    // if the surface was never touched, which is too late.
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _snapshot.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RippleSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.child, widget.child)) _snapshot.clear();
  }

  /// Drops a ring at [at], in this widget's own coordinates.
  void drop(Offset at) {
    if (reduceMotionOf(context)) return;
    _rings[_next * 3] = at.dx;
    _rings[_next * 3 + 1] = at.dy;
    _rings[_next * 3 + 2] = _clock;
    _next = (_next + 1) % _slots;
    _lastDrop = at;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _snapshot.clear();
      _snapshot.allowSnapshotting = true;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _clock += dt;
    var alive = false;
    for (var i = 0; i < _slots; i++) {
      final t = _rings[i * 3 + 2];
      if (t < 0) continue;
      if (_clock - t > _lifetime) {
        _rings[i * 3 + 2] = -1;
      } else {
        alive = true;
      }
    }
    if (!alive) {
      _ticker.stop();
      _snapshot.allowSnapshotting = false;
      return;
    }
    // A fresh picture of the child every frame: one held for the life of
    // the rings would freeze whatever moves underneath, a pager most of all.
    _snapshot.clear();
    _painter
      ..rings = _rings
      ..time = _clock
      ..amplitude = widget.amplitude
      ..speed = widget.speed
      ..wavelength = widget.wavelength
      ..poke();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => drop(e.localPosition),
      onPointerMove: (e) {
        final last = _lastDrop;
        if (last == null || (e.localPosition - last).distance > 48) {
          drop(e.localPosition);
        }
      },
      child: ShaderBuilder(
        asset: rippleShaderAsset,
        builder: (context, shader) {
          _painter.shader = shader;
          return SnapshotWidget(
            controller: _snapshot,
            mode: SnapshotMode.permissive,
            autoresize: true,
            painter: _painter,
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _RipplePainter extends SnapshotPainter {
  ui.FragmentShader? shader;
  List<double> rings = const [];
  double time = 0;
  double amplitude = 12;
  double speed = 520;
  double wavelength = 34;

  void poke() => notifyListeners();

  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    painter(context, offset);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    final canvas = context.canvas;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final shader = this.shader;
    if (shader == null || rings.isEmpty) {
      canvas.drawImageRect(image, Offset.zero & sourceSize, rect, Paint());
    } else {
      var i = 0;
      void f(double v) => shader.setFloat(i++, v);
      f(size.width);
      f(size.height);
      f(time);
      f(amplitude);
      f(speed);
      f(wavelength);
      rings.forEach(f);
      shader.setImageSampler(0, image);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => true;
}
