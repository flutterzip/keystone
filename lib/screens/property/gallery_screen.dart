import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/home.dart';
import '../../widgets/common.dart';
import '../../widgets/photo.dart';

/// Every photograph of a home, full screen: swipe between them, pinch or
/// double tap to look closer, and jump by the strip along the foot.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.home, this.initial = 0});

  final Home home;
  final int initial;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _at = widget.initial;

  /// While a photo is zoomed, a drag pans it instead of turning the page.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final photos = widget.home.photos;
    return Material(
      color: p.keyCard,
      child: Stack(
        children: [
          PageView.builder(
            key: const Key('gallery-pages'),
            controller: _pages,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _at = i),
            itemBuilder: (context, i) => _Zoomable(
              onZoomed: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
              child: HomePhoto(
                photos[i],
                fit: BoxFit.contain,
                decodeWidth: media.size.width * 1.6,
              ),
            ),
          ),
          Positioned(
            top: media.padding.top + 4,
            left: 8,
            right: Space.lg,
            child: Row(
              children: [
                RoundIcon(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  filled: true,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                Text(
                  '${_at + 1} of ${photos.length}',
                  style: context.title.copyWith(
                    color: p.onPhoto,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + Space.md,
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _at,
                label: 'Photo ${i + 1}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _pages.animateToPage(
                    i,
                    duration: Motion.medium,
                    curve: Motion.settle,
                  ),
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    width: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.sm + 2),
                      border: Border.all(
                        color: i == _at
                            ? p.accent
                            : p.onPhoto.withValues(alpha: 0),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm - 2),
                      child: Opacity(
                        opacity: i == _at ? 1 : .55,
                        child: HomePhoto(photos[i], decodeWidth: 100),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Zoomable extends StatefulWidget {
  const _Zoomable({required this.child, required this.onZoomed});

  final Widget child;
  final ValueChanged<bool> onZoomed;

  @override
  State<_Zoomable> createState() => _ZoomableState();
}

class _ZoomableState extends State<_Zoomable>
    with SingleTickerProviderStateMixin {
  final _view = TransformationController();
  late final AnimationController _glide;
  Animation<Matrix4>? _to;
  Offset _tap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: Motion.short)
      ..addListener(() {
        if (_to != null) _view.value = _to!.value;
      });
    _view.addListener(
      () => widget.onZoomed(_view.value.getMaxScaleOnAxis() > 1.02),
    );
  }

  @override
  void dispose() {
    _glide.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Double tap: in to 2.5x on the point tapped, or back out.
  void _toggle() {
    final zoomed = _view.value.getMaxScaleOnAxis() > 1.02;
    final target = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-_tap.dx * 1.5, -_tap.dy * 1.5, 0, 1)
            ..scaleByDouble(2.5, 2.5, 1, 1));
    _to = Matrix4Tween(
      begin: _view.value,
      end: target,
    ).animate(CurvedAnimation(parent: _glide, curve: Motion.settle));
    _glide.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (d) => _tap = d.localPosition,
    onDoubleTap: _toggle,
    child: InteractiveViewer(
      transformationController: _view,
      minScale: 1,
      maxScale: 4,
      child: widget.child,
    ),
  );
}
