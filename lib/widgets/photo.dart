import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';

/// The asset path behind a bundled media reference such as
/// `asset:homes/loft-1.jpg`. With a backend, a reference is a URL instead
/// and this is where `Image.network` goes.
String assetPathOf(String ref) =>
    'assets/images/${ref.startsWith('asset:') ? ref.substring(6) : ref}';

/// A property photograph. Decoded at the size it is shown, faded in over
/// the plate colour, and replaced by a quiet placeholder when it is missing.
class HomePhoto extends StatelessWidget {
  const HomePhoto(
    this.photo, {
    super.key,
    this.fit = BoxFit.cover,
    this.decodeWidth = 800,
    this.alignment = Alignment.center,
  });

  final String photo;
  final BoxFit fit;

  /// Logical pixels wide it will be shown, at most. Keeps a thumbnail from
  /// holding a full-size bitmap in memory.
  final double decodeWidth;
  final Alignment alignment;

  static ImageProvider provider(BuildContext context, String photo, double w) =>
      ResizeImage.resizeIfNeeded(
        (w * MediaQuery.devicePixelRatioOf(context)).round(),
        null,
        AssetImage(assetPathOf(photo)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.plate,
      child: Image(
        image: provider(context, photo, decodeWidth),
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: Motion.short,
                curve: Curves.easeOut,
                child: child,
              ),
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.landscape_outlined, color: p.muted, size: 28),
        ),
      ),
    );
  }
}

/// An agent's portrait in a circle, falling back to their initial.
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({
    super.key,
    required this.photo,
    required this.name,
    this.size = 44,
  });

  final String photo;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initial = Center(
      child: Text(
        name.isEmpty ? '' : name[0].toUpperCase(),
        style: TextStyle(
          color: p.accentInk,
          fontWeight: FontWeight.w800,
          fontSize: size * .42,
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: p.accentWash,
          child: photo.isEmpty
              ? initial
              : Image(
                  image: HomePhoto.provider(context, photo, size),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => initial,
                ),
        ),
      ),
    );
  }
}
