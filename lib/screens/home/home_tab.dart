import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/home.dart';
import '../../providers/activity_providers.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/viewing_island.dart';
import '../shell/main_shell.dart';
import '../splash/splash_overlay.dart';
import 'home_sections.dart';

abstract final class HomeKeys {
  static const location = Key('home-location');
  static const search = Key('home-search');
  static const featured = Key('home-featured');
  static const newThisWeek = Key('home-new');
  static const nearYou = Key('home-near');
  static const recent = Key('home-recent');
}

/// Home: where you are looking, search, Rent or Buy, then the market in
/// four cuts: featured, new this week, near you, recently viewed.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Motion.entrance);
    startWhenRevealed(ref, _enter.forward);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// One controller, sliced: each section rises a beat after the last.
  Widget _rise(int step, Widget child) {
    final a = CurvedAnimation(
      parent: _enter,
      curve: Interval(
        (step * .11).clamp(0.0, .6),
        (step * .11 + .45).clamp(0.0, 1.0),
        curve: Motion.enter,
      ),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .05),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final kind = ref.watch(listingKindProvider);
    final area = ref.watch(areaProvider);
    final homes = ref.watch(kindHomesProvider);
    final near = ref.watch(nearbyHomesProvider);
    final map = ref.watch(cityMapProvider).valueOrNull;
    final now = ref.watch(nowProvider);
    final all = ref.watch(homesProvider).valueOrNull ?? const <Home>[];
    final recent = homesById(
      all,
      ref.watch(recentProvider).valueOrNull ?? const [],
    );
    final soon = ref.watch(soonViewingProvider);
    final soonHome = soon == null ? null : ref.watch(homeProvider(soon.homeId));
    final profile = ref.watch(profileProvider).valueOrNull;

    final featured = [
      for (final h in homes)
        if (h.featured) h,
    ];
    final fresh = [
      for (final h in homes)
        if (h.isNew(now)) h,
    ]..sort((a, b) => b.listedAt.compareTo(a.listedAt));
    final from = map == null
        ? null
        : (area == null ? null : map.areaNamed(area)) ??
              GeoPoint((map.north + map.south) / 2, (map.west + map.east) / 2);

    return TabPage(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                media.padding.top + Space.md,
                Space.gutter,
                0,
              ),
              child: _rise(
                0,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LocationButton(
                            greeting: profile == null
                                ? 'Welcome'
                                : 'Welcome, ${profile.firstName}',
                            area: area,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Your profile',
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(shellTabProvider.notifier).state =
                                    ShellTab.profile,
                            child: Avatar(profile: profile, size: 44),
                          ),
                        ),
                      ],
                    ),
                    if (soon != null && soonHome != null) ...[
                      const SizedBox(height: Space.md),
                      Center(
                        child: ViewingIsland(viewing: soon, home: soonHome),
                      ),
                    ],
                    const SizedBox(height: Space.lg),
                    const SearchPill(key: HomeKeys.search),
                    const SizedBox(height: Space.md),
                    Segmented<ListingKind>(
                      values: ListingKind.values,
                      labelOf: (k) => k.label,
                      value: kind,
                      keyPrefix: 'kind',
                      onChanged: (k) =>
                          ref.read(listingKindProvider.notifier).set(k),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.exit,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(kind),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Space.xl),
                  _rise(
                    1,
                    FeaturedCarousel(key: HomeKeys.featured, homes: featured),
                  ),
                  const SizedBox(height: Space.xxl),
                  _rise(
                    2,
                    HomeRail(
                      key: HomeKeys.newThisWeek,
                      title: 'New this week',
                      scope: 'new',
                      homes: fresh,
                      empty: kind == ListingKind.rent
                          ? 'Nothing new to rent this week.'
                          : 'Nothing new for sale this week.',
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  _rise(
                    3,
                    NearYou(
                      key: HomeKeys.nearYou,
                      title: area == null ? 'Near you' : 'Near $area',
                      homes: near.take(3).toList(),
                      from: from,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (recent.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: Space.xxl),
                child: _rise(
                  4,
                  HomeRail(
                    key: HomeKeys.recent,
                    title: 'Recently viewed',
                    scope: 'recent',
                    homes: recent,
                    compact: true,
                    action: 'Clear',
                    onAction: () => ref.read(recentProvider.notifier).clear(),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: media.padding.bottom + Sizes.tabBarReserve),
          ),
        ],
      ),
    );
  }
}

/// "Welcome, Olympicson" over the place being looked at. Tapping it picks a
/// neighbourhood.
class _LocationButton extends ConsumerWidget {
  const _LocationButton({required this.greeting, required this.area});

  final String greeting;
  final String? area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final place = area == null
        ? '${AppBrand.city}, ${AppBrand.country}'
        : '$area, ${AppBrand.city}';
    return Semantics(
      button: true,
      label: '$greeting. Looking in $place. Change area',
      excludeSemantics: true,
      child: GestureDetector(
        key: HomeKeys.location,
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: context.caption),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.place_rounded, size: 19, color: p.accent),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.heading,
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 22, color: p.ink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    final areas =
        ref.read(cityMapProvider).valueOrNull?.areas.map((a) => a.name) ??
        const <String>[];
    showAppSheet<void>(
      context,
      title: 'Where are you looking?',
      builder: (sheet) {
        final p = sheet.palette;
        Widget row(String label, String? value) => ListTile(
          key: Key('area-${value ?? 'all'}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          title: Text(label, style: sheet.title),
          trailing: value == area
              ? Icon(Icons.check_rounded, color: p.accentInk)
              : null,
          onTap: () {
            ref.read(areaProvider.notifier).set(value);
            Navigator.of(sheet).pop();
          },
        );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Space.md),
          children: [
            row('All of ${AppBrand.city}', null),
            for (final a in areas) row(a, a),
          ],
        );
      },
    );
  }
}
