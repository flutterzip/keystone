import 'package:flutter/material.dart';
import 'package:keystone/kit/kit.dart';

import '../config/motion.dart';

/// A row that blows away as dust when [gone] turns true, then closes the gap
/// it leaves; and opens the gap and re-forms when [gone] turns false again
/// (an undo).
///
/// The owner removes the record from its state straight away, so totals and
/// badges are right at once, and keeps this widget in its list for as long
/// as the undo is on offer.
class Removable extends StatefulWidget {
  const Removable({super.key, required this.gone, required this.child});

  final bool gone;
  final Widget child;

  @override
  State<Removable> createState() => _RemovableState();
}

class _RemovableState extends State<Removable> {
  final _dust = DisintegrateController();
  late bool _collapsed = widget.gone;
  int _run = 0;

  @override
  void didUpdateWidget(Removable old) {
    super.didUpdateWidget(old);
    if (old.gone != widget.gone) widget.gone ? _leave() : _comeBack();
  }

  Future<void> _leave() async {
    final run = ++_run;
    if (Motion.loops(context)) await _dust.disintegrate();
    if (mounted && run == _run) setState(() => _collapsed = true);
  }

  Future<void> _comeBack() async {
    final run = ++_run;
    setState(() => _collapsed = false);
    if (!Motion.loops(context)) return;
    // Let the gap open before the dust flies back into it.
    await Future<void>.delayed(Motion.short);
    if (mounted && run == _run) await _dust.reform();
  }

  @override
  Widget build(BuildContext context) {
    final calm = !Motion.loops(context);
    // The row stays mounted while collapsed, so an undo re-forms the very
    // dust that blew away.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _collapsed ? 0 : 1),
      duration: Motion.short,
      curve: Motion.settle,
      builder: (context, h, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: h.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: calm
          ? Visibility(
              visible: !widget.gone,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: widget.child,
            )
          : Disintegrable(
              controller: _dust,
              duration: Motion.dust,
              child: widget.child,
            ),
    );
  }
}
