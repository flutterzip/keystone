import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../core/shader_library.dart';

const String meshGradientShaderAsset = 'shaders/mesh_gradient.frag';

/// A slowly folding four-colour gradient that a finger can stir.
///
/// Changing [colors] blends to the new palette. Touches are observed, never
/// consumed, so anything in [child] still gets its taps.
///
/// ```dart
/// MeshGradient(
///   colors: [indigo, violet, teal, rose],
///   child: content,
/// )
/// ```
class MeshGradient extends StatefulWidget {
  const MeshGradient({
    super.key,
    required this.colors,
    this.speed = 1,
    this.grain = 0.035,
    this.interactive = true,
    this.child,
  }) : assert(colors.length == 4);

  final List<Color> colors;

  /// Flow speed. Eased towards, so it can change at any time.
  final double speed;
  final double grain;
  final bool interactive;
  final Widget? child;

  @override
  State<MeshGradient> createState() => _MeshGradientState();
}

class _MeshGradientState extends State<MeshGradient>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  bool _reduceMotion = false;

  double _time = 0;
  double _speed = 1;
  Offset _touch = const Offset(0.5, 0.5);
  double _strength = 0;
  bool _down = false;
  late final List<double> _rgb = _target();

  List<double> _target() => [
    for (final c in widget.colors) ...[c.r, c.g, c.b],
  ];

  @override
  void initState() {
    super.initState();
    _speed = widget.speed;
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    double ease(double a, double b, double rate) =>
        a + (b - a) * (1 - math.exp(-rate * dt));
    _speed = ease(_speed, widget.speed * (_reduceMotion ? 0.15 : 1), 2.5);
    _time += dt * _speed;
    _strength = ease(_strength, _down ? 1 : 0, _down ? 9 : 2.2);
    final target = _target();
    for (var i = 0; i < 12; i++) {
      _rgb[i] = ease(_rgb[i], target[i], 2.6);
    }
    _frame.value++;
  }

  void _point(Offset local, {bool? down}) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _touch = Offset(local.dx / size.width, local.dy / size.height);
    if (down != null) _down = down;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = ShaderBuilder(
      asset: meshGradientShaderAsset,
      builder: (context, shader) => CustomPaint(
        painter: _MeshPainter(this, shader, _frame),
        child: widget.child,
      ),
    );
    if (widget.interactive) {
      result = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _point(e.localPosition, down: true),
        onPointerMove: (e) => _point(e.localPosition),
        onPointerUp: (e) => _point(e.localPosition, down: false),
        onPointerCancel: (e) => _point(e.localPosition, down: false),
        child: result,
      );
    }
    return result;
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.s, this.shader, Listenable repaint)
    : super(repaint: repaint);

  final _MeshGradientState s;
  final ui.FragmentShader? shader;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = this.shader;
    if (shader == null) {
      canvas.drawRect(rect, Paint()..color = s.widget.colors.first);
      return;
    }
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    f(size.width);
    f(size.height);
    f(s._time);
    f(s._touch.dx);
    f(s._touch.dy);
    f(s._strength);
    s._rgb.forEach(f);
    f(s.widget.grain);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.shader != shader;
}
