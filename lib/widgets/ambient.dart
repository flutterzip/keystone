import 'package:flutter/material.dart';
import 'package:keystone/kit/kit.dart';

import '../config/app_brand.dart';
import '../config/app_theme.dart';
import '../config/motion.dart';

/// The slow warm gradient behind the splash, onboarding and sign in.
///
/// It folds on its own only while motion is wanted. Under reduce motion (and
/// in tests) it is a still gradient of the same colours, so nothing animates
/// for ever where nobody asked it to.
class AmbientMesh extends StatelessWidget {
  const AmbientMesh({super.key, this.child, this.speed = .55});

  final Widget? child;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.mesh;
    if (!Motion.loops(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: child,
      );
    }
    return RepaintBoundary(
      child: MeshGradient(
        colors: colors,
        speed: speed,
        grain: .03,
        child: child,
      ),
    );
  }
}

/// DRAPE, in spaced capitals. [settle] runs 0 to 1: the letters start far
/// apart and draw together.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 15, this.settle = 1, this.color});

  final double size;
  final double settle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final spacing = size * (.28 + .9 * (1 - settle));
    return Semantics(
      header: true,
      label: AppBrand.name,
      excludeSemantics: true,
      child: Padding(
        // Letter spacing trails the last glyph; this re-centres the word.
        padding: EdgeInsets.only(left: spacing),
        child: Text(
          AppBrand.name.toUpperCase(),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: size,
            height: 1.1,
            letterSpacing: spacing,
            fontWeight: FontWeight.w700,
            color: color ?? context.palette.ink,
          ),
        ),
      ),
    );
  }
}
