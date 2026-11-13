import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../models/home.dart';
import '../providers/core_providers.dart';
import 'common.dart';
import 'photo.dart';
import 'pressable.dart';
import 'save_flight.dart';

/// The tag a home's photo flies under, from a card to its page. [scope]
/// keeps it unique when the same home is in two lists on one screen.
String homeHeroTag(Home home, String scope) => 'home-${home.id}-$scope';

/// "2 bed", "2 bath", "96 m²" with small icons.
class FactsLine extends StatelessWidget {
  const FactsLine(this.home, {super.key, this.color});

  final Home home;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.muted;
    final style = context.caption.copyWith(color: c);
    Widget fact(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: [
        fact(Icons.bed_outlined, '${home.beds}'),
        fact(Icons.bathtub_outlined, '${home.baths}'),
        fact(Icons.straighten_rounded, '${home.sqm} m²'),
      ],
    );
  }
}

/// The price, with "a month" set quieter after a rent.
class PriceText extends StatelessWidget {
  const PriceText(this.home, {super.key, this.size = 17, this.color});

  final Home home;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.ink;
    return Text.rich(
      TextSpan(
        text: home.price.text,
        children: [
          if (home.isRent)
            TextSpan(
              text: ' / month',
              style: TextStyle(
                fontSize: size * .68,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: .7),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.price.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
        color: c,
      ),
    );
  }
}

/// A home's photo with its Hero, its "New" tag and its heart.
class _CardPhoto extends StatelessWidget {
  const _CardPhoto({
    required this.home,
    required this.scope,
    required this.photoKey,
    required this.radius,
    this.decodeWidth = 420,
    this.heart = true,
  });

  final Home home;
  final String scope;
  final GlobalKey photoKey;
  final double radius;
  final double decodeWidth;
  final bool heart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: homeHeroTag(home, scope),
          child: ClipRRect(
            key: photoKey,
            borderRadius: BorderRadius.circular(radius),
            child: HomePhoto(home.cover, decodeWidth: decodeWidth),
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          child: Consumer(
            builder: (context, ref, _) => home.isNew(ref.watch(clockProvider)())
                ? const Tag('New')
                : const SizedBox.shrink(),
          ),
        ),
        if (heart)
          Positioned(
            right: 4,
            top: 4,
            child: SaveButton(home: home, from: photoKey),
          ),
      ],
    );
  }
}

/// The large card of the featured carousel: the photo is the card, and the
/// details sit on its shaded foot.
class FeaturedCard extends StatefulWidget {
  const FeaturedCard({
    super.key,
    required this.home,
    required this.onTap,
    this.scope = 'featured',
  });

  final Home home;
  final VoidCallback onTap;
  final String scope;

  @override
  State<FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<FeaturedCard> {
  final _photo = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final home = widget.home;
    return Pressable(
      onTap: widget.onTap,
      scale: .98,
      semanticLabel: '${home.title}, ${home.area}, ${home.priceText}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CardPhoto(
            home: home,
            scope: widget.scope,
            photoKey: _photo,
            radius: Radii.xl,
            decodeWidth: 420,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(Radii.xl),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [p.photoScrim.withValues(alpha: 0), p.photoScrim],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PriceText(home, size: 21, color: p.onPhoto),
                    const SizedBox(height: 2),
                    Text(
                      home.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.title.copyWith(color: p.onPhoto),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            home.area,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.caption.copyWith(
                              color: p.onPhoto.withValues(alpha: .8),
                            ),
                          ),
                        ),
                        FactsLine(
                          home,
                          color: p.onPhoto.withValues(alpha: .85),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A home as a tile: photo above, details below. Used in rails and lists.
class HomeTile extends StatefulWidget {
  const HomeTile({
    super.key,
    required this.home,
    required this.onTap,
    required this.scope,
    this.photoAspect = 4 / 3,
    this.trailing,
  });

  final Home home;
  final VoidCallback onTap;
  final String scope;
  final double photoAspect;

  /// Shown at the right of the price line, such as a distance.
  final Widget? trailing;

  @override
  State<HomeTile> createState() => _HomeTileState();
}

class _HomeTileState extends State<HomeTile> {
  final _photo = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    return Pressable(
      onTap: widget.onTap,
      scale: .98,
      semanticLabel: '${home.title}, ${home.area}, ${home.priceText}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: widget.photoAspect,
            child: _CardPhoto(
              home: home,
              scope: widget.scope,
              photoKey: _photo,
              radius: Radii.lg,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: PriceText(home)),
              ?widget.trailing,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            home.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.title,
          ),
          const SizedBox(height: 1),
          Text(
            home.area,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.caption,
          ),
          const SizedBox(height: 6),
          FactsLine(home),
        ],
      ),
    );
  }
}

/// A home as a row: a small photo and its details beside it.
class HomeRow extends StatefulWidget {
  const HomeRow({
    super.key,
    required this.home,
    required this.onTap,
    required this.scope,
    this.trailing,
    this.note,
  });

  final Home home;
  final VoidCallback? onTap;
  final String scope;
  final Widget? trailing;

  /// A line under the facts, such as when a viewing is.
  final Widget? note;

  @override
  State<HomeRow> createState() => _HomeRowState();
}

class _HomeRowState extends State<HomeRow> {
  final _photo = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    return Pressable(
      onTap: widget.onTap,
      scale: .985,
      semanticLabel: '${home.title}, ${home.area}, ${home.priceText}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            height: 92,
            child: _CardPhoto(
              home: home,
              scope: widget.scope,
              photoKey: _photo,
              radius: Radii.md,
              decodeWidth: 160,
              heart: false,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                PriceText(home, size: 15.5),
                const SizedBox(height: 2),
                Text(
                  home.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
                Text(
                  home.area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption,
                ),
                const SizedBox(height: 5),
                widget.note ?? FactsLine(home),
              ],
            ),
          ),
          ?widget.trailing,
        ],
      ),
    );
  }
}
