import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keystone/kit/kit.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../config/palette.dart';
import '../../models/city_map.dart';
import '../../models/home.dart';
import '../../providers/core_providers.dart';
import '../../widgets/city_map_view.dart';
import '../../widgets/common.dart';
import '../../widgets/floor_plan.dart';
import '../../widgets/keystone_mark.dart';
import '../../widgets/photo.dart';

/// The home's brochure, with pages that turn like paper. Under reduce
/// motion the same pages slide.
class BrochureScreen extends ConsumerStatefulWidget {
  const BrochureScreen({super.key, required this.homeId});

  final String homeId;

  @override
  ConsumerState<BrochureScreen> createState() => _BrochureScreenState();
}

class _BrochureScreenState extends ConsumerState<BrochureScreen> {
  int _at = 0;

  // The same page widgets for the same home and colours, so the turner
  // does not photograph them again on every rebuild.
  List<Widget>? _pages;
  Object? _pagesOf;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final home = ref.watch(homeProvider(widget.homeId));
    final agent = home == null ? null : ref.watch(agentProvider(home.agentId));
    final map = ref.watch(cityMapProvider).valueOrNull;
    if (home == null) {
      return const SubPage(title: 'Brochure', child: SizedBox.shrink());
    }
    final of = (home.id, agent?.id, map, p);
    if (_pages == null || _pagesOf != of) {
      _pagesOf = of;
      _pages = [
        _Cover(home: home, p: p),
        _Page(
          p: p,
          number: 2,
          title: 'The home',
          child: _About(home: home),
        ),
        _Page(
          p: p,
          number: 3,
          title: 'The plan',
          child: _Plan(home: home),
        ),
        _Page(
          p: p,
          number: 4,
          title: 'The area',
          child: _Area(home: home, map: map),
        ),
        _Page(
          p: p,
          number: 5,
          title: 'Arrange a viewing',
          child: _Contact(home: home, agent: agent),
        ),
      ];
    }
    final pages = _pages!;
    return SubPage(
      title: 'Brochure',
      trailing: Text(
        '${_at + 1} of ${pages.length}',
        key: const Key('brochure-page'),
        style: context.caption.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xl,
          Space.gutter,
          MediaQuery.paddingOf(context).bottom + Space.md,
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4.3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: p.shadow,
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Motion.loops(context)
                        ? PageTurner(
                            itemCount: pages.length,
                            itemBuilder: (_, i) => pages[i],
                            onPageChanged: (i) => setState(() => _at = i),
                          )
                        : PageView(
                            onPageChanged: (i) => setState(() => _at = i),
                            children: pages,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(
              'Drag a corner, or tap the edge, to turn the page',
              textAlign: TextAlign.center,
              style: context.caption,
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _t(Palette p, double size, FontWeight w, {Color? color}) => TextStyle(
  fontFamily: AppTheme.font,
  fontSize: size,
  height: 1.3,
  fontWeight: w,
  color: color ?? p.ink,
);

/// The cover: the photograph to the edges, the name on its foot.
class _Cover extends StatelessWidget {
  const _Cover({required this.home, required this.p});

  final Home home;
  final Palette p;

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: Stack(
      fit: StackFit.expand,
      children: [
        HomePhoto(home.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [p.photoScrim.withValues(alpha: 0), p.photoScrim],
            ),
          ),
        ),
        Positioned(
          left: 22,
          top: 22,
          child: Row(
            children: [
              KeystoneMark(size: 26, color: p.onPhoto),
              const SizedBox(width: 8),
              Text(
                AppBrand.name.toUpperCase(),
                style: _t(
                  p,
                  12,
                  FontWeight.w700,
                  color: p.onPhoto,
                ).copyWith(letterSpacing: 3),
              ),
            ],
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                home.area.toUpperCase(),
                style: _t(
                  p,
                  10.5,
                  FontWeight.w600,
                  color: p.accent,
                ).copyWith(letterSpacing: 2.4),
              ),
              const SizedBox(height: 6),
              Text(
                home.title,
                style: _t(
                  p,
                  27,
                  FontWeight.w700,
                  color: p.onPhoto,
                ).copyWith(height: 1.08, letterSpacing: -.6),
              ),
              const SizedBox(height: 8),
              Text(
                home.priceText,
                style: _t(p, 15, FontWeight.w600, color: p.onPhoto),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// An inside page: a running head, the content, and a folio.
class _Page extends StatelessWidget {
  const _Page({
    required this.p,
    required this.number,
    required this.title,
    required this.child,
  });

  final Palette p;
  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: ColoredBox(
      color: p.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: _t(
                p,
                10.5,
                FontWeight.w600,
                color: p.accentInk,
              ).copyWith(letterSpacing: 2.4),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: p.line),
            const SizedBox(height: 16),
            Expanded(child: child),
            Row(
              children: [
                KeystoneMark(size: 16, color: p.muted),
                const Spacer(),
                Text(
                  '$number',
                  style: _t(p, 11, FontWeight.w500, color: p.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _About extends StatelessWidget {
  const _About({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: HomePhoto(home.photos[1 % home.photos.length]),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  home.description,
                  overflow: TextOverflow.fade,
                  style: _t(p, 12.5, FontWeight.w400, color: p.inkSoft),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${home.beds} bedrooms   ${home.baths} bathrooms   ${home.sqm} m²',
                style: _t(p, 12, FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                home.amenities.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _t(p, 11.5, FontWeight.w500, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(child: FloorPlan(rooms: home.rooms)),
        ),
        const SizedBox(height: 12),
        for (final r in home.rooms.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.name,
                    style: _t(p, 11.5, FontWeight.w500, color: p.inkSoft),
                  ),
                ),
                Text(
                  '${r.w.toStringAsFixed(1)} x ${r.h.toStringAsFixed(1)} m',
                  style: _t(p, 11.5, FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _Area extends StatelessWidget {
  const _Area({required this.home, required this.map});

  final Home home;
  final CityMap? map;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: map == null
                ? ColoredBox(color: p.mapLand)
                : CityMapView(
                    map: map!,
                    focus: home.at,
                    zoom: 2.6,
                    dot: home.at,
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Text(home.area, style: _t(p, 19, FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          '${home.address}, ${AppBrand.city}',
          style: _t(p, 12.5, FontWeight.w400, color: p.inkSoft),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.home, required this.agent});

  final Home home;
  final Agent? agent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Center(child: KeystoneMark(size: 84, color: p.ink)),
        const Spacer(),
        if (agent != null) ...[
          Row(
            children: [
              PersonPhoto(photo: agent!.photo, name: agent!.name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent!.name, style: _t(p, 15, FontWeight.w700)),
                    Text(
                      agent!.agency,
                      style: _t(p, 11.5, FontWeight.w500, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(agent!.phone, style: _t(p, 13, FontWeight.w600)),
          Text(
            agent!.email,
            style: _t(p, 12.5, FontWeight.w400, color: p.inkSoft),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Book a viewing of ${home.title} in the ${AppBrand.name} app, in '
          'person or by video call.',
          style: _t(p, 12.5, FontWeight.w400, color: p.inkSoft),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
