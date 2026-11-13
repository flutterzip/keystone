import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../particles/particle_switcher.dart';

enum PayState { ready, working, paid, failed }

/// A pay button that becomes its own receipt.
///
/// Tap it and it shows progress while [onPay] runs. On success the button
/// breaks into particles that reassemble as a check and [paidLabel]; on
/// failure it shakes its head and comes back ready, with [failedLabel].
///
/// ```dart
/// PayButton(
///   label: 'Pay \$49.00',
///   onPay: () => checkout.charge(),   // true when the payment went through
///   onPaid: () => Navigator.of(context).push(receiptRoute),
/// )
/// ```
class PayButton extends StatefulWidget {
  const PayButton({
    super.key,
    required this.label,
    required this.onPay,
    this.onPaid,
    this.paidLabel = 'Paid',
    this.failedLabel = 'Payment failed. Try again',
    this.color,
    this.foreground,
    this.height = 58,
  });

  final String label;

  /// Does the paying. Completes true on success.
  final Future<bool> Function() onPay;

  /// Called once the particles have settled into the paid state.
  final VoidCallback? onPaid;
  final String paidLabel;
  final String failedLabel;

  /// Defaults to the theme's primary colour.
  final Color? color;
  final Color? foreground;
  final double height;

  @override
  State<PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<PayButton> {
  PayState _state = PayState.ready;

  Future<void> _pay() async {
    if (_state == PayState.working || _state == PayState.paid) return;
    HapticFeedback.mediumImpact();
    setState(() => _state = PayState.working);
    bool ok;
    try {
      ok = await widget.onPay();
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      HapticFeedback.heavyImpact();
      setState(() => _state = PayState.paid);
      // The morph takes about a second.
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) widget.onPaid?.call();
    } else {
      HapticFeedback.vibrate();
      setState(() => _state = PayState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? scheme.primary;
    final fg = widget.foreground ?? scheme.onPrimary;
    final paid = _state == PayState.paid;
    final working = _state == PayState.working;
    final text = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: fg,
    );

    final Widget face;
    if (paid) {
      face = Row(
        key: const ValueKey('paid'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.height - 8,
            height: widget.height - 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(Icons.check_rounded, color: fg, size: 30),
          ),
          const SizedBox(width: 12),
          Text(
            widget.paidLabel,
            style: text.copyWith(fontSize: 24, color: scheme.onSurface),
          ),
        ],
      );
    } else {
      face = Container(
        key: const ValueKey('pay'),
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: working
              ? SizedBox.square(
                  key: const ValueKey('spin'),
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: fg),
                )
              : Text(
                  _state == PayState.failed ? widget.failedLabel : widget.label,
                  key: ValueKey(_state),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text,
                ),
        ),
      );
    }

    return Semantics(
      button: !paid,
      label: paid
          ? widget.paidLabel
          : working
          ? 'Paying'
          : _state == PayState.failed
          ? widget.failedLabel
          : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pay,
        child: SizedBox(
          height: widget.height,
          child: Center(child: ParticleSwitcher(child: face)),
        ),
      ),
    );
  }
}
