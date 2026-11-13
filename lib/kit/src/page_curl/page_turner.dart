import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../core/shader_library.dart';

const String pageCurlShaderAsset = 'shaders/page_curl.frag';

/// Pages that turn like paper.
///
/// Drag from the right half and the page rolls round a cylinder that follows
/// the finger, showing its underside and casting a shadow on the next page.
/// Let go past halfway and it turns; otherwise it falls back. Tapping the
/// left or right third turns a page on its own.
///
/// ```dart
/// PageTurner(itemCount: pages.length, itemBuilder: (_, i) => pages[i])
/// ```
class PageTurner extends StatefulWidget {
  const PageTurner({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PageTurner> createState() => _PageTurnerState();
}

class _PageTurnerState extends State<PageTurner>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _snapshot = SnapshotController();
  final _painter = _CurlPainter();
  int _index = 0;
  Size _size = Size.zero;

  Offset _corner = Offset.zero;
  Offset _finger = Offset.zero;
  Offset _target = Offset.zero;
  bool _dragging = false;
  bool _turning = false;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _snapshot.dispose();
    _painter.dispose();
    super.dispose();
  }

  Offset get _turned => Offset(-_size.width, _corner.dy);

  /// Paper cannot stretch: the held corner stays within one page width of
  /// the near end of the spine and one diagonal of the far end. Without the
  /// second limit the sheet folds across itself at angles paper cannot make.
  Offset _reach(Offset p) {
    final w = _size.width;
    final h = _size.height;
    final near = Offset(0, _corner.dy);
    final far = Offset(0, h - _corner.dy);
    var q = p;
    var v = q - near;
    if (v.distance > w) q = near + v / v.distance * w;
    final diagonal = math.sqrt(w * w + h * h);
    v = q - far;
    if (v.distance > diagonal) q = far + v / v.distance * diagonal;
    return q;
  }

  void _lift(Offset corner, Offset finger) {
    _corner = corner;
    _finger = _reach(finger);
    _last = Duration.zero;
    _snapshot.clear();
    _snapshot.allowSnapshotting = true;
    _push();
    if (!_ticker.isActive) _ticker.start();
  }

  void _push() {
    final across = _corner - _finger;
    final d = across.distance;
    if (d < 1) {
      _painter.radius = 0;
    } else {
      // The roll tightens to nothing at either end of the turn.
      final remaining = (_finger.dx + _size.width).abs();
      final radius = math.max(
        math.min(math.min(_size.width * 0.085, d * 0.22), remaining * 0.3),
        0.6,
      );
      final dir = across / d;
      // Half a turn of the roll uses up pi * r of paper, so the fold sits
      // that much nearer the finger for the corner to land under it.
      _painter
        ..fold = _corner - dir * ((d + math.pi * radius) / 2)
        ..dir = dir
        ..radius = radius;
    }
    _painter.poke();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (!_dragging) {
      _finger = _reach(
        _finger + (_target - _finger) * (1 - math.exp(-7.5 * dt)),
      );
      if ((_target - _finger).distance < 1.5) {
        _ticker.stop();
        _snapshot.allowSnapshotting = false;
        _painter
          ..radius = 0
          ..poke();
        if (_turning) {
          _turning = false;
          setState(() => _index++);
          widget.onPageChanged?.call(_index);
        }
        return;
      }
    }
    _push();
  }

  bool get _busy => _ticker.isActive;

  void _onPanStart(DragStartDetails d) {
    if (_busy || _index >= widget.itemCount - 1) return;
    final at = d.localPosition;
    if (at.dx < _size.width * 0.5) return;
    _dragging = true;
    _turning = false;
    HapticFeedback.selectionClick();
    _lift(Offset(_size.width, at.dy > _size.height / 2 ? _size.height : 0), at);
  }

  void _onPanEnd(Velocity v) {
    if (!_dragging) return;
    _dragging = false;
    final turn = _finger.dx < _size.width * 0.45 || v.pixelsPerSecond.dx < -500;
    _turning = turn;
    _target = turn ? _turned : _corner;
    if (turn) HapticFeedback.lightImpact();
  }

  void _onTap(TapUpDetails d) {
    if (_busy) return;
    final x = d.localPosition.dx;
    final corner = Offset(_size.width, _size.height);
    if (x > _size.width * 0.66 && _index < widget.itemCount - 1) {
      HapticFeedback.lightImpact();
      if (reduceMotionOf(context)) {
        setState(() => _index++);
        widget.onPageChanged?.call(_index);
        return;
      }
      _turning = true;
      _lift(corner, corner - const Offset(24, 18));
      _target = _turned;
    } else if (x < _size.width * 0.34 && _index > 0) {
      HapticFeedback.lightImpact();
      setState(() => _index--);
      widget.onPageChanged?.call(_index);
      if (reduceMotionOf(context)) return;
      // The previous page starts fully turned and is laid back down.
      _turning = false;
      _corner = corner;
      _lift(corner, _turned);
      _target = corner;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final hasNext = _index + 1 < widget.itemCount;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasNext)
              KeyedSubtree(
                key: ValueKey('under-${_index + 1}'),
                child: widget.itemBuilder(context, _index + 1),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTap,
              onPanStart: _onPanStart,
              onPanUpdate: (d) {
                if (_dragging) _finger = _reach(d.localPosition);
              },
              onPanEnd: (d) => _onPanEnd(d.velocity),
              onPanCancel: () => _onPanEnd(Velocity.zero),
              child: ShaderBuilder(
                asset: pageCurlShaderAsset,
                builder: (context, shader) {
                  _painter.shader = shader;
                  return SnapshotWidget(
                    controller: _snapshot,
                    mode: SnapshotMode.permissive,
                    autoresize: true,
                    painter: _painter,
                    child: KeyedSubtree(
                      key: ValueKey('top-$_index'),
                      child: widget.itemBuilder(context, _index),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurlPainter extends SnapshotPainter {
  ui.FragmentShader? shader;
  Offset fold = Offset.zero;
  Offset dir = const Offset(1, 0);
  double radius = 0;

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
    if (shader == null || radius <= 0) {
      canvas.drawImageRect(image, Offset.zero & sourceSize, rect, Paint());
    } else {
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, fold.dx)
        ..setFloat(3, fold.dy)
        ..setFloat(4, dir.dx)
        ..setFloat(5, dir.dy)
        ..setFloat(6, radius)
        ..setImageSampler(0, image);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CurlPainter oldDelegate) => true;
}
