import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/shader_library.dart';

const String liquidGlassShaderAsset = 'shaders/liquid_glass.frag';

/// How the glass looks. All lengths are logical pixels.
@immutable
class LiquidGlassSettings {
  const LiquidGlassSettings({
    this.thickness = 20,
    this.refraction = 26,
    this.dispersion = 0.05,
    this.blur = 3,
    this.blend = 18,
    this.tint = const Color(0x700B0D12),
    this.saturation = 1.35,
    this.lightAngle = -2.2,
    this.shadow = 0.16,
  });

  /// Width of the curved rim. Wider reads as a thicker pane.
  final double thickness;

  /// How far the rim bends what is behind it.
  final double refraction;

  /// Colour fringing at the rim, as a fraction of the bend.
  final double dispersion;

  /// Frost radius. Zero is clear glass.
  final double blur;

  /// How close two shapes get before they fuse like droplets.
  final double blend;

  final Color tint;
  final double saturation;

  /// Direction the light comes from, in radians.
  final double lightAngle;

  /// Strength of the contact shadow under the glass.
  final double shadow;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSettings &&
      other.thickness == thickness &&
      other.refraction == refraction &&
      other.dispersion == dispersion &&
      other.blur == blur &&
      other.blend == blend &&
      other.tint == tint &&
      other.saturation == saturation &&
      other.lightAngle == lightAngle &&
      other.shadow == shadow;

  @override
  int get hashCode => Object.hash(
    thickness,
    refraction,
    dispersion,
    blur,
    blend,
    tint,
    saturation,
    lightAngle,
    shadow,
  );
}

/// The shapes one glass layer draws, in the layer's own coordinates.
///
/// [body] is the pane. [satellite] is a second pane that fuses with it when
/// they come close. [lens] is a pill that rides on the pane and turns into a
/// magnifier as [lensPower] goes to one.
@immutable
class GlassShapes {
  const GlassShapes({
    required this.body,
    required this.bodyRadius,
    this.lens = Rect.zero,
    this.lensRadius = 0,
    this.lensPower = 0,
    this.satellite = Rect.zero,
    this.satelliteRadius = 0,
  });

  final Rect body;
  final double bodyRadius;
  final Rect lens;
  final double lensRadius;
  final double lensPower;
  final Rect satellite;
  final double satelliteRadius;

  Rect get bounds {
    var r = body;
    if (!lens.isEmpty) r = r.expandToInclude(lens);
    if (!satellite.isEmpty) r = r.expandToInclude(satellite);
    return r;
  }
}

/// Paints refracting glass over whatever is behind it, then [child] on top.
///
/// Shapes come from a listenable so an animation repaints without rebuilding.
/// Needs Impeller. Elsewhere it falls back to a plain frosted pane.
class LiquidGlassLayer extends StatelessWidget {
  const LiquidGlassLayer({
    super.key,
    required this.shapes,
    this.settings = const LiquidGlassSettings(),
    this.child,
  });

  final ValueListenable<GlassShapes> shapes;
  final LiquidGlassSettings settings;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ShaderBuilder(
      asset: liquidGlassShaderAsset,
      builder: (context, shader) => _RawGlass(
        shader: shader,
        shapes: shapes,
        settings: settings,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        child: child,
      ),
    );
  }
}

class _RawGlass extends SingleChildRenderObjectWidget {
  const _RawGlass({
    required this.shader,
    required this.shapes,
    required this.settings,
    required this.devicePixelRatio,
    super.child,
  });

  final ui.FragmentShader? shader;
  final ValueListenable<GlassShapes> shapes;
  final LiquidGlassSettings settings;
  final double devicePixelRatio;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) =>
      RenderLiquidGlass(shader, shapes, settings, devicePixelRatio);

  @override
  void updateRenderObject(BuildContext context, RenderLiquidGlass ro) {
    ro
      ..shader = shader
      ..shapes = shapes
      ..settings = settings
      ..devicePixelRatio = devicePixelRatio;
  }
}

class RenderLiquidGlass extends RenderProxyBox {
  RenderLiquidGlass(
    this._shader,
    this._shapes,
    this._settings,
    this._devicePixelRatio,
  );

  /// Room around the shapes for the contact shadow.
  static const double _bleed = 36;

  ui.FragmentShader? _shader;
  set shader(ui.FragmentShader? value) {
    if (identical(value, _shader)) return;
    _shader = value;
    markNeedsPaint();
  }

  ValueListenable<GlassShapes> _shapes;
  set shapes(ValueListenable<GlassShapes> value) {
    if (identical(value, _shapes)) return;
    if (attached) _shapes.removeListener(markNeedsPaint);
    _shapes = value;
    if (attached) _shapes.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  LiquidGlassSettings _settings;
  set settings(LiquidGlassSettings value) {
    if (value == _settings) return;
    _settings = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  Offset? _paintedOrigin;
  bool _watching = false;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _shapes.addListener(markNeedsPaint);
    _watch();
  }

  @override
  void detach() {
    _shapes.removeListener(markNeedsPaint);
    _watching = false;
    super.detach();
  }

  /// The shader works in screen space, so an ancestor that moves this box
  /// without repainting it (a scroll, a route slide) must trigger a repaint.
  void _watch() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback(_checkOrigin);
  }

  void _checkOrigin(Duration _) {
    if (!attached || !_watching) return;
    if (_paintedOrigin != null && hasSize) {
      final now = MatrixUtils.transformPoint(getTransformTo(null), Offset.zero);
      if ((now - _paintedOrigin!).distanceSquared > 0.0001) markNeedsPaint();
    }
    SchedulerBinding.instance.addPostFrameCallback(_checkOrigin);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shapes = _shapes.value;
    final shader = _shader;
    final clip = shapes.bounds.inflate(_bleed).shift(offset);

    if (shader == null || !ui.ImageFilter.isShaderFilterSupported) {
      _paintFallback(context, offset, shapes);
      super.paint(context, offset);
      return;
    }

    final toScreen = getTransformTo(null);
    final origin = MatrixUtils.transformPoint(toScreen, Offset.zero);
    _paintedOrigin = origin;
    final scale = toScreen.getMaxScaleOnAxis();
    _setUniforms(shader, shapes, origin, scale);

    context.pushClipRect(needsCompositing, Offset.zero, clip, (context, _) {
      // A fresh layer each paint: the filter snapshots the uniforms when it
      // is created, and a reused layer would keep the old ones.
      context.pushLayer(
        BackdropFilterLayer(filter: ui.ImageFilter.shader(shader)),
        (context, offset) {},
        Offset.zero,
      );
      super.paint(context, offset);
    });
  }

  void _setUniforms(
    ui.FragmentShader shader,
    GlassShapes shapes,
    Offset origin,
    double scale,
  ) {
    final s = _settings;
    var i = 2; // 0 and 1 are the texture size, set by the engine.
    void f(double v) => shader.setFloat(i++, v);
    void box(Rect r, double radius) {
      if (r.isEmpty) {
        f(0);
        f(0);
        f(0);
        f(0);
        f(0);
        return;
      }
      final c = origin + r.center * scale;
      final hw = r.width / 2 * scale;
      final hh = r.height / 2 * scale;
      f(c.dx);
      f(c.dy);
      f(hw);
      f(hh);
      f(math.min(radius * scale, math.min(hw, hh)));
    }

    f(_devicePixelRatio);
    box(shapes.body, shapes.bodyRadius);
    box(shapes.lens, shapes.lensRadius);
    box(shapes.satellite, shapes.satelliteRadius);
    f(s.blend * scale);
    f(s.thickness * scale);
    f(s.refraction * scale);
    f(s.dispersion);
    f(s.blur * scale);
    f(shapes.lensPower.clamp(0.0, 1.0));
    f(s.tint.r);
    f(s.tint.g);
    f(s.tint.b);
    f(s.tint.a);
    f(math.cos(s.lightAngle));
    f(math.sin(s.lightAngle));
    f(s.saturation);
    f(s.shadow);
  }

  void _paintFallback(PaintingContext context, Offset offset, GlassShapes s) {
    void pane(Rect rect, double radius) {
      if (rect.isEmpty) return;
      final rrect = RRect.fromRectAndRadius(
        rect.shift(offset),
        Radius.circular(radius),
      );
      context.pushClipRRect(
        needsCompositing,
        Offset.zero,
        rrect.outerRect,
        rrect,
        (context, _) {
          context.pushLayer(
            BackdropFilterLayer(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            ),
            (context, _) {
              context.canvas.drawRRect(
                rrect,
                Paint()..color = _settings.tint.withValues(alpha: 0.35),
              );
              context.canvas.drawRRect(
                rrect.deflate(0.5),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1
                  ..color = const Color(0x40FFFFFF),
              );
            },
            Offset.zero,
          );
        },
      );
    }

    pane(s.body, s.bodyRadius);
    pane(s.satellite, s.satelliteRadius);
  }
}
