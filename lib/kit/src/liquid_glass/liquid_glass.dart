import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'liquid_glass_layer.dart';

export 'liquid_glass_layer.dart' show LiquidGlassSettings;

/// A single pane of refracting glass the size of its child.
///
/// ```dart
/// LiquidGlass(
///   borderRadius: 28,
///   child: Padding(padding: EdgeInsets.all(16), child: Icon(Icons.search)),
/// )
/// ```
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.magnify = 0,
    this.settings = const LiquidGlassSettings(),
  });

  final Widget child;
  final double borderRadius;

  /// 0 is a flat pane. 1 turns the whole pane into a magnifier.
  final double magnify;
  final LiquidGlassSettings settings;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  final _shapes = ValueNotifier<GlassShapes>(
    const GlassShapes(body: Rect.zero, bodyRadius: 0),
  );
  Size _size = Size.zero;

  void _sync() {
    final rect = Offset.zero & _size;
    final lens = widget.magnify > 0;
    _shapes.value = GlassShapes(
      body: rect,
      bodyRadius: widget.borderRadius,
      lens: lens ? rect : Rect.zero,
      lensRadius: widget.borderRadius,
      lensPower: widget.magnify,
    );
  }

  @override
  void didUpdateWidget(LiquidGlass old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _shapes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      shapes: _shapes,
      settings: widget.settings,
      child: _SizeReporter(
        onSize: (size) {
          if (size == _size) return;
          _size = size;
          _sync();
        },
        child: widget.child,
      ),
    );
  }
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter ro) =>
      ro.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    // Changing the notifier during layout only marks the glass for repaint,
    // which is still ahead of us in this frame.
    onSize(size);
  }
}
