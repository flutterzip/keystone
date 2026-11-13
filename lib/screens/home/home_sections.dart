import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/home.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../actions.dart';

/// The shape the search pill shares with the search field, so one morphs
/// into the other. Only the surface flies; the words stay out of it.
class SearchSurface extends StatelessWidget {
  const SearchSurface({super.key});

  static const tag = 'search-surface';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hero(
      tag: tag,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: p.line),
          boxShadow: [
            BoxShadow(
              color: p.shadow.withValues(alpha: p.shadow.a * .5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// The search pill on Home. Opens Search; its right end opens it on the map.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 54,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SearchSurface(),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Search homes',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openSearch(context),
                    child: Row(
                      children: [
                        const SizedBox(width: 18),
                        Icon(Icons.search_rounded, size: 21, color: p.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Area, street or home',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.body.copyWith(
                              color: p.muted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: p.line),
              Semantics(
                button: true,
                label: 'Search on the map',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('home-search-map'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openSearch(context, map: true),
                  child: SizedBox(
                    width: 56,
                    child: Icon(Icons.map_outlined, size: 20, color: p.ink),
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

/// The featured homes, one large card at a time. Each card's size and the
/// dots follow the scroll offset, so they track the finger.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.homes});

  final List<Home> homes;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  static const _fraction = .86;
  final _pages = PageController(viewportFraction: _fraction);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  double get _page => _pages.hasClients && _pages.position.haveDimensions
      ? _pages.page ?? 0
      : 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final homes = widget.homes;
    if (homes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Featured'),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 312,
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            clipBehavior: Clip.none,
            itemCount: homes.length,
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final away = (_page - i).abs().clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? Space.gutter : Space.md / 2,
                    right: Space.md / 2,
                  ),
                  child: Transform.scale(
                    scale: 1 - .05 * away,
                    alignment: Alignment.centerLeft,
                    child: Opacity(opacity: 1 - .25 * away, child: child),
                  ),
                );
              },
              child: FeaturedCard(
                home: homes[i],
                onTap: () => openHome(context, homes[i], scope: 'featured'),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        AnimatedBuilder(
          animation: _pages,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < homes.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6 + 14 * (1 - (_page - i).abs()).clamp(0.0, 1.0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      p.line,
                      p.accent,
                      (1 - (_page - i).abs()).clamp(0.0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled row of homes that scrolls sideways.
class HomeRail extends StatelessWidget {
  const HomeRail({
    super.key,
    required this.title,
    required this.scope,
    required this.homes,
    this.empty,
    this.compact = false,
    this.action,
    this.onAction,
  });

  final String title;
  final String scope;
  final List<Home> homes;

  /// The sentence shown when there are none.
  final String? empty;

  /// Smaller tiles, for a list that is a reminder rather than a shelf.
  final bool compact;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 168.0 : 224.0;
    // Tall enough for the photo and four lines of type at large text.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = width * 3 / 4 + 106 * scale + 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title, action: action, onAction: onAction),
        const SizedBox(height: Space.md),
        if (homes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Notice(empty ?? 'Nothing here yet.'),
          )
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              itemCount: homes.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.lg),
              itemBuilder: (context, i) => SizedBox(
                width: width,
                child: HomeTile(
                  home: homes[i],
                  scope: scope,
                  onTap: () => openHome(context, homes[i], scope: scope),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The nearest homes as rows, each with how far away it is.
class NearYou extends StatelessWidget {
  const NearYou({
    super.key,
    required this.title,
    required this.homes,
    required this.from,
  });

  final String title;
  final List<Home> homes;
  final GeoPoint? from;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title,
          action: 'See the map',
          onAction: () => openSearch(context, map: true),
        ),
        const SizedBox(height: Space.md),
        for (final (i, h) in homes.indexed)
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              i == 0 ? 0 : Space.lg,
              Space.gutter,
              0,
            ),
            child: AnimatedSwitcher(
              duration: Motion.short,
              child: HomeRow(
                key: ValueKey(h.id),
                home: h,
                scope: 'near',
                onTap: () => openHome(context, h, scope: 'near'),
                trailing: from == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${h.at.kmTo(from!).toStringAsFixed(1)} km',
                          style: context.caption.copyWith(color: p.accentInk),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
