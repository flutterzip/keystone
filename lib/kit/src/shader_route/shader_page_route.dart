import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/shader_library.dart';

const String routeRevealShaderAsset = 'shaders/route_reveal.frag';

enum ShaderTransition {
  /// Ink soaking outwards from [ShaderPageRoute.origin].
  ink,

  /// The old page burns away from the bottom.
  burn,

  /// A sheet of liquid slides across.
  liquid,
}

/// A page route whose new page arrives through a fragment shader.
///
/// Popping plays the same effect backwards.
///
/// ```dart
/// Navigator.of(context).push(ShaderPageRoute(
///   effect: ShaderTransition.ink,
///   origin: tapPosition,
///   builder: (_) => const DetailPage(),
/// ));
/// ```
class ShaderPageRoute<T> extends PageRoute<T> {
  ShaderPageRoute({
    required this.builder,
    this.effect = ShaderTransition.ink,
    this.origin,
    this.duration = const Duration(milliseconds: 1100),
    super.settings,
  });

  final WidgetBuilder builder;
  final ShaderTransition effect;

  /// Where an ink bleed starts, in global coordinates. Defaults to centre.
  final Offset? origin;
  final Duration duration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: animation, child: child);
    }
    return ShaderReveal(
      progress: animation,
      effect: effect,
      origin: origin,
      child: child,
    );
  }
}

/// Reveals [child] through the route shader as [progress] goes 0 to 1.
class ShaderReveal extends StatefulWidget {
  const ShaderReveal({
    super.key,
    required this.progress,
    required this.child,
    this.effect = ShaderTransition.ink,
    this.origin,
  });

  final Animation<double> progress;
  final ShaderTransition effect;
  final Offset? origin;
  final Widget child;

  @override
  State<ShaderReveal> createState() => _ShaderRevealState();
}

class _ShaderRevealState extends State<ShaderReveal> {
  final _snapshot = SnapshotController();
  late final _RevealPainter _painter = _RevealPainter(widget.progress);

  @override
  void initState() {
    super.initState();
    ShaderLibrary.load(routeRevealShaderAsset);
    widget.progress.addStatusListener(_onStatus);
    _onStatus(widget.progress.status);
  }

  @override
  void didUpdateWidget(ShaderReveal old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      old.progress.removeStatusListener(_onStatus);
      widget.progress.addStatusListener(_onStatus);
      _painter.rebind(widget.progress);
      _onStatus(widget.progress.status);
    }
  }

  /// Only snapshot while moving, so the settled page stays live.
  void _onStatus(AnimationStatus status) {
    _snapshot.allowSnapshotting =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
  }

  @override
  void dispose() {
    widget.progress.removeStatusListener(_onStatus);
    _snapshot.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final origin = widget.origin;
    _painter
      ..effect = widget.effect
      ..origin = origin == null
          ? const Offset(0.5, 0.5)
          : Offset(origin.dx / size.width, origin.dy / size.height);
    return ShaderBuilder(
      asset: routeRevealShaderAsset,
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
    );
  }
}

class _RevealPainter extends SnapshotPainter {
  _RevealPainter(this._progress) {
    _progress.addListener(notifyListeners);
  }

  Animation<double> _progress;
  ui.FragmentShader? shader;
  ShaderTransition effect = ShaderTransition.ink;
  Offset origin = const Offset(0.5, 0.5);

  void rebind(Animation<double> progress) {
    _progress.removeListener(notifyListeners);
    _progress = progress..addListener(notifyListeners);
  }

  @override
  void dispose() {
    _progress.removeListener(notifyListeners);
    super.dispose();
  }

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
    final t = Curves.easeInOut.transform(_progress.value.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final shader = this.shader;
    if (shader == null) {
      canvas.drawImageRect(
        image,
        Offset.zero & sourceSize,
        rect,
        Paint()..color = Color.fromRGBO(0, 0, 0, t),
      );
    } else {
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, t)
        ..setFloat(3, effect.index.toDouble())
        ..setFloat(4, origin.dx)
        ..setFloat(5, origin.dy)
        ..setImageSampler(0, image);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RevealPainter oldDelegate) => true;
}
