import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../config/motion.dart';

/// The one text field: its title sits above the box, the hint shows what
/// goes in it, and the leading icon says what kind of field it is. Title
/// and icons take the accent on focus and the error colour on error.
class AppField extends StatefulWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onBlur,
    this.onChanged,
    this.autofillHints,
    this.inputFormatters,
    this.capitalization = TextCapitalization.none,
    this.fieldKey,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onBlur;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization capitalization;
  final Key? fieldKey;

  /// An action that belongs to this field, shown at the right of its title.
  final Widget? trailing;

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  final _focus = FocusNode();
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) widget.onBlur?.call();
    setState(() {});
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final focused = _focus.hasFocus;
    final hasError = widget.error != null;
    final tone = hasError ? p.error : (focused ? p.accentInk : p.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The trailing action floats over the title row: in a Row its 44dp
        // touch target would become the row's height and open a gap.
        Stack(
          clipBehavior: Clip.none,
          // Full width, so the trailing action sits at the right edge and
          // not on top of the title.
          fit: StackFit.passthrough,
          children: [
            const SizedBox(width: double.infinity),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 7),
              child: Text(
                widget.label,
                style: context.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasError ? p.error : (focused ? p.accentInk : p.ink),
                ),
              ),
            ),
            if (widget.trailing != null)
              Positioned(right: 0, top: -14, child: widget.trailing!),
          ],
        ),
        AnimatedContainer(
          duration: Motion.quick,
          height: Sizes.fieldHeight,
          decoration: BoxDecoration(
            color: focused || hasError ? p.card : p.field,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: hasError ? p.error : (focused ? p.accentInk : p.line),
              width: focused || hasError ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 19, color: tone),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                child: TextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure && _hidden,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.capitalization,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  autofillHints: widget.autofillHints,
                  inputFormatters: widget.inputFormatters,
                  autocorrect: false,
                  enableSuggestions: !widget.obscure,
                  style: context.title.copyWith(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: context.body.copyWith(color: p.muted),
                  ),
                ),
              ),
              if (widget.obscure)
                IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: tone,
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: Motion.quick,
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(left: 2, top: 6),
                  child: Text(
                    widget.error!,
                    style: context.caption.copyWith(
                      color: p.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
