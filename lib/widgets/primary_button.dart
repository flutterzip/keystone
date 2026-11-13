import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../config/motion.dart';
import 'pressable.dart';

/// The primary pill, in the accent.
///
/// A busy button keeps its colour and height; only the label swaps for the
/// loader. Greying it out on press reads as "refused", not "working".
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.height = Sizes.buttonHeight,
    this.icon,
    this.quiet = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final IconData? icon;

  /// An outlined, secondary version of the same button.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null;
    final fg = quiet ? p.ink : p.onPrimary;
    return Pressable(
      onTap: busy || !enabled ? null : onPressed,
      semanticLabel: label,
      haptic: true,
      child: AnimatedOpacity(
        opacity: enabled || busy ? 1 : .45,
        duration: Motion.quick,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          decoration: BoxDecoration(
            color: quiet ? null : p.primary,
            border: quiet ? Border.all(color: p.ink, width: 1.2) : null,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: AnimatedSwitcher(
            duration: Motion.quick,
            child: busy
                ? DotsLoader(key: const ValueKey('busy'), color: fg)
                : Row(
                    key: ValueKey(label),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: Space.sm),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            letterSpacing: -.1,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Three dots breathing in turn: the app's loader. It runs only while it is
/// on screen, and stands still under reduce motion.
class DotsLoader extends StatefulWidget {
  const DotsLoader({super.key, required this.color, this.size = 7});

  final Color color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_t.isAnimating) _t.repeat();
    } else {
      _t.stop();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Working',
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * .35),
                child: Opacity(
                  opacity: _t.isAnimating
                      ? .35 +
                            .65 *
                                (1 - ((_t.value * 3 - i) % 3 / 1.5 - 1).abs())
                                    .clamp(0.0, 1.0)
                      : .8,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
