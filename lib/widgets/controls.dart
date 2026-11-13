import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../config/motion.dart';

/// A small filled tag: "NEW", "FOR SALE".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.accent = true});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: accent ? p.accent : p.card,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.label.copyWith(
          fontSize: 8.5,
          letterSpacing: 1.2,
          color: accent ? p.onAccent : p.inkSoft,
        ),
      ),
    );
  }
}

/// Where something has got to. Never colour alone: a live one carries a dot
/// and the accent, a finished one is quiet.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.live = false,
    this.muted = false,
  });

  final String label;
  final bool live;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = live ? p.accentInk : (muted ? p.muted : p.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: live ? p.accentWash : p.field,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: context.label.copyWith(
              fontSize: 9.5,
              letterSpacing: 1.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip that is on or off: a filter, an amenity, a time.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.struck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Shown but unavailable: quiet, with a line through it. Still tappable,
  /// so it can say why.
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.onPrimary : (struck ? p.muted : p.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: struck ? '$label, unavailable' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: Motion.quick,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: selected ? p.primary : (struck ? null : p.card),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? p.primary : p.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.title.copyWith(
                  fontSize: 13.5,
                  color: fg,
                  decoration: struck ? TextDecoration.lineThrough : null,
                  decorationColor: p.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch between a few choices, with a thumb that slides to the chosen
/// one: Rent or Buy, List or Map.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labelOf,
    required this.value,
    required this.onChanged,
    this.height = 46,
    this.keyPrefix,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  /// Each choice gets the key `<prefix>-<label>`.
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index = values.indexOf(value);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Motion.short,
            curve: Motion.settle,
            alignment: Alignment(
              values.length == 1 ? 0 : -1 + 2 * index / (values.length - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / values.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8)],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final v in values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: v == value,
                    label: labelOf(v),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: keyPrefix == null
                          ? null
                          : Key('$keyPrefix-${labelOf(v)}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (v == value) return;
                        HapticFeedback.selectionClick();
                        onChanged(v);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: Motion.quick,
                          style: context.title.copyWith(
                            fontFamily: AppTheme.font,
                            fontSize: 13.5,
                            color: v == value ? p.ink : p.muted,
                          ),
                          child: Text(labelOf(v), maxLines: 1),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
