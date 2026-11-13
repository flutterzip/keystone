import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/motion.dart';
import '../core/shader_library.dart';

const String holoFoilShaderAsset = 'shaders/holo_foil.frag';

enum HoloFinish { prism, glitter, engraved }

/// Turns any card into holographic foil that answers to tilt.
///
/// Bright parts of [child] carry the foil and are embossed; dark parts keep
/// a faint sheen. Tilt comes from the motion sensor where there is one, from
/// a drag anywhere on the card, and from a slow sway when left alone.
///
/// ```dart
/// HoloCard(finish: HoloFinish.prism, child: MembershipCard())
/// ```
class HoloCard extends StatefulWidget {
  const HoloCard({
    super.key,
    required this.child,
    this.finish = HoloFinish.prism,
    this.strength = 1,
    this.emboss = 1.3,
    this.maxAngle = 0.34,
    this.useMotionSensor = true,
    this.sway = true,
  });

  final Widget child;
  final HoloFinish finish;

  /// Foil strength, 0 to 1.
  final double strength;

  /// Depth of the relief on bright artwork.
  final double emboss;

  /// How far the card turns at full tilt, in radians.
  final double maxAngle;
  final bool useMotionSensor;

  /// Whether the card drifts on its own when nothing is tilting it.
  final bool sway;

  @override
  State<HoloCard> createState() => _HoloCardState();
}

class _HoloCardState extends State<HoloCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _snapshot = SnapshotController(allowSnapshotting: true);
  final _painter = _FoilPainter();
  final _frame = ValueNotifier<int>(0);
  StreamSubscription<AccelerometerEvent>? _sensor;

  Duration _last = Duration.zero;
  double _clock = 0;
  Offset _tilt = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset? _drag;
  Offset? _sensorTilt;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    if (widget.useMotionSensor) _listenToSensor();
  }

  void _listenToSensor() {
    try {
      _sensor =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            (e) {
              // Flat on a table reads as level; a natural reading angle is the
              // vertical rest position.
              final x = (e.x / 9.81 * 1.8).clamp(-1.0, 1.0);
              final y = ((e.y / 9.81 - 0.65) * 2.2).clamp(-1.0, 1.0);
              final next = Offset(x, -y);
              final prev = _sensorTilt;
              _sensorTilt = prev == null ? next : Offset.lerp(prev, next, 0.25);
            },
            onError: (Object _) => _sensorTilt = null,
            cancelOnError: true,
          );
    } on Object {
      _sensorTilt = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
  }

  @override
  void didUpdateWidget(HoloCard old) {
    super.didUpdateWidget(old);
    // The snapshot is a picture of the old child.
    if (!identical(old.child, widget.child)) _snapshot.clear();
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _ticker.dispose();
    _snapshot.dispose();
    _painter.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.033);
    _last = now;
    _clock += dt;

    Offset target;
    double stiffness;
    double damping;
    if (_drag != null) {
      target = _drag!;
      stiffness = 520;
      damping = 42;
    } else if (_sensorTilt != null) {
      target = _sensorTilt!;
      stiffness = 260;
      damping = 26;
    } else {
      final sway = widget.sway && !_reduceMotion;
      target = sway
          ? Offset(
              0.42 * math.sin(_clock * 0.9),
              0.30 * math.sin(_clock * 0.62 + 1.2),
            )
          : Offset.zero;
      // Loose, so letting go of the card wobbles before it settles.
      stiffness = 150;
      damping = 11;
    }
    final accel = (target - _tilt) * stiffness - _velocity * damping;
    _velocity += accel * dt;
    _tilt += _velocity * dt;

    _painter
      ..tilt = _tilt
      ..time = _clock
      ..finish = widget.finish
      ..strength = widget.strength
      ..emboss = widget.emboss
      ..poke();
    _frame.value++;
  }

  void _onDrag(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _drag = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.2, 1.2),
      (local.dy / size.height * 2 - 1).clamp(-1.2, 1.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _onDrag(d.localPosition),
      onPanUpdate: (d) => _onDrag(d.localPosition),
      onPanEnd: (_) => _drag = null,
      onPanCancel: () => _drag = null,
      child: Builder(
        builder: (context) {
          return ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, child) {
              final angle = widget.maxAngle;
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.0011)
                ..rotateX(_tilt.dy * angle)
                ..rotateY(-_tilt.dx * angle);
              return Transform(
                transform: matrix,
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x99000000),
                        blurRadius: 44,
                        spreadRadius: -8,
                        offset: Offset(-_tilt.dx * 22, 22 - _tilt.dy * 16),
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: ShaderBuilder(
              asset: holoFoilShaderAsset,
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
        },
      ),
    );
  }
}

class _FoilPainter extends SnapshotPainter {
  ui.FragmentShader? shader;
  Offset tilt = Offset.zero;
  double time = 0;
  HoloFinish finish = HoloFinish.prism;
  double strength = 1;
  double emboss = 1;

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
    if (shader == null) {
      canvas.drawImageRect(image, Offset.zero & sourceSize, rect, Paint());
    } else {
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, tilt.dx.clamp(-1.3, 1.3))
        ..setFloat(3, tilt.dy.clamp(-1.3, 1.3))
        ..setFloat(4, time)
        ..setFloat(5, strength)
        ..setFloat(6, finish.index.toDouble())
        ..setFloat(7, emboss)
        ..setImageSampler(0, image);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoilPainter oldDelegate) => true;
}
