import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import 'liquid_glass_layer.dart';

@immutable
class GlassTabItem {
  const GlassTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// A floating tab bar made of refracting glass.
///
/// The selection is a droplet that stretches as it travels, lifts into a
/// magnifier while it is dragged, and the optional [action] is a second pane
/// that fuses with the bar when pressed.
class LiquidGlassTabBar extends StatefulWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.onReselected,
    this.action,
    this.actionLabel,
    this.onAction,
    this.settings = const LiquidGlassSettings(),
  }) : assert(items.length >= 2);

  final List<GlassTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Called when the tab that is already selected is tapped again. Apps
  /// usually pop that tab back to its first page here.
  final ValueChanged<int>? onReselected;

  /// Icon of the separate round pane at the trailing edge.
  final IconData? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final LiquidGlassSettings settings;

  static const double height = 64;

  @override
  State<LiquidGlassTabBar> createState() => _LiquidGlassTabBarState();
}

class _LiquidGlassTabBarState extends State<LiquidGlassTabBar>
    with TickerProviderStateMixin {
  static const double _pad = 6;
  static const double _gap = 12;

  /// Pill centre as a fractional tab index, so it survives a resize.
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
    value: widget.currentIndex.toDouble(),
  );
  late final AnimationController _lift = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  late final Listenable _motion = Listenable.merge([_x, _lift, _press]);

  final _shapes = ValueNotifier<GlassShapes>(
    const GlassShapes(body: Rect.zero, bodyRadius: 0),
  );

  double _width = 0;
  bool _dragging = false;
  bool _reduceMotion = false;

  bool get _hasAction => widget.action != null;
  double get _barWidth =>
      _hasAction ? _width - LiquidGlassTabBar.height - _gap : _width;
  double get _itemWidth => (_barWidth - _pad * 2) / widget.items.length;

  @override
  void initState() {
    super.initState();
    _motion.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
  }

  @override
  void didUpdateWidget(LiquidGlassTabBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && !_dragging) {
      _travelTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _motion.removeListener(_sync);
    _x.dispose();
    _lift.dispose();
    _press.dispose();
    _shapes.dispose();
    super.dispose();
  }

  void _travelTo(int index, {double? velocity}) {
    _x.springTo(
      index.toDouble(),
      spring: _reduceMotion ? Springs.snappy : Springs.lively,
      velocity: velocity,
    );
  }

  double _indexAt(double dx) => (dx - _pad) / _itemWidth - 0.5;

  void _sync() {
    if (_width <= 0) return;
    const h = LiquidGlassTabBar.height;
    final bar = Rect.fromLTWH(0, 0, _barWidth, h);
    final lift = _lift.value.clamp(0.0, 1.4);
    final press = _press.value.clamp(-0.3, 1.4);

    // The droplet stretches with speed and thins as it does.
    final speed = _reduceMotion ? 0.0 : _x.velocity.abs() * _itemWidth;
    final stretch = (speed * 0.05).clamp(0.0, _itemWidth * 0.7);
    final pillW = _itemWidth + stretch + 14 * lift;
    final pillH = (h - _pad * 2) - stretch * 0.16 + 22 * lift;
    final cx = _pad + (_x.value + 0.5) * _itemWidth;
    final pill = Rect.fromCenter(
      center: Offset(cx, h / 2),
      width: pillW,
      height: pillH,
    );

    var orb = Rect.zero;
    if (_hasAction) {
      orb = Rect.fromLTWH(
        _width - h,
        0,
        h,
        h,
      ).inflate(5 * press).translate(-11 * press, 0);
    }

    _shapes.value = GlassShapes(
      body: bar,
      bodyRadius: h / 2,
      lens: pill,
      lensRadius: pillH / 2,
      lensPower: lift,
      satellite: orb,
      satelliteRadius: orb.height / 2,
    );
  }

  void _onTapUp(TapUpDetails d) {
    final index = _indexAt(
      d.localPosition.dx,
    ).round().clamp(0, widget.items.length - 1);
    if (index == widget.currentIndex) {
      widget.onReselected?.call(index);
      return;
    }
    HapticFeedback.selectionClick();
    widget.onChanged(index);
  }

  void _onDragStart(DragStartDetails d) {
    _dragging = true;
    HapticFeedback.lightImpact();
    _lift.springTo(1, spring: Springs.bouncy);
    _follow(d.localPosition.dx);
  }

  void _follow(double dx) {
    final last = widget.items.length - 1.0;
    var target = _indexAt(dx);
    // Rubber band past either end.
    if (target < 0) target = target * 0.3;
    if (target > last) target = last + (target - last) * 0.3;
    _x.springTo(target, spring: Springs.snappy);
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging = false;
    final vIndex = d.velocity.pixelsPerSecond.dx / _itemWidth;
    final projected = _x.value + vIndex * 0.12;
    final index = projected.round().clamp(0, widget.items.length - 1);
    _lift.springTo(0, spring: Springs.wobbly);
    _x.springTo(index.toDouble(), spring: Springs.wobbly, velocity: vIndex);
    if (index != widget.currentIndex) {
      HapticFeedback.selectionClick();
      widget.onChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LiquidGlassTabBar.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth != _width) {
            _width = constraints.maxWidth;
            _sync();
          }
          return LiquidGlassLayer(
            shapes: _shapes,
            settings: widget.settings,
            child: Row(
              children: [
                Expanded(child: _buildBar()),
                if (_hasAction) ...[
                  const SizedBox(width: _gap),
                  _buildAction(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBar() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (d) => _follow(d.localPosition.dx),
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () {
        _dragging = false;
        _lift.springTo(0, spring: Springs.wobbly);
        _travelTo(widget.currentIndex);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _pad),
        child: Row(
          children: [
            for (var i = 0; i < widget.items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == widget.currentIndex,
                  label: widget.items[i].label,
                  onTap: () => i == widget.currentIndex
                      ? widget.onReselected?.call(i)
                      : widget.onChanged(i),
                  excludeSemantics: true,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) {
                      final near = (1 - (_x.value - i).abs()).clamp(0.0, 1.0);
                      final lift = _lift.value.clamp(0.0, 1.2);
                      return _TabGlyph(
                        item: widget.items[i],
                        emphasis: near,
                        scale: 1 + 0.14 * lift * near,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    return Semantics(
      button: true,
      label: widget.actionLabel,
      excludeSemantics: true,
      onTap: widget.onAction,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.springTo(1, spring: Springs.bouncy),
        onTapCancel: () => _press.springTo(0, spring: Springs.wobbly),
        onTapUp: (_) {
          _press.springTo(0, spring: Springs.wobbly);
          HapticFeedback.lightImpact();
          widget.onAction?.call();
        },
        child: SizedBox.square(
          dimension: LiquidGlassTabBar.height,
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) => Transform.translate(
              offset: Offset(-11 * _press.value.clamp(-0.3, 1.4), 0),
              child: child,
            ),
            child: Icon(widget.action, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _TabGlyph extends StatelessWidget {
  const _TabGlyph({
    required this.item,
    required this.emphasis,
    required this.scale,
  });

  final GlassTabItem item;
  final double emphasis;
  final double scale;

  static const _shadow = [
    Shadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(const Color(0xB8FFFFFF), Colors.white, emphasis)!;
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 24, color: color, shadows: _shadow),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.1,
              fontWeight: emphasis > 0.5 ? FontWeight.w700 : FontWeight.w600,
              color: color,
              shadows: _shadow,
            ),
          ),
        ],
      ),
    );
  }
}
