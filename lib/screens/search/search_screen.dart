import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/home.dart';
import '../../models/ids.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/city_map_view.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../actions.dart';
import '../home/home_sections.dart';
import 'filter_sheet.dart';

abstract final class SearchKeys {
  static const field = Key('search-field');
  static const filters = Key('search-filters');
  static const save = Key('search-save');
  static const clear = Key('search-clear-filters');
  static const selected = Key('search-map-card');
}

enum _View { list, map }

/// Search: text, filters, and the results as a list or as pins on the map.
/// Both views read the same results, so they can never disagree.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.startOnMap = false});

  final bool startOnMap;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _text = TextEditingController(
    text: ref.read(searchFilterProvider).query,
  );
  late _View _view = widget.startOnMap ? _View.map : _View.list;
  String? _pin;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _update(HomeFilter Function(HomeFilter) change) {
    final n = ref.read(searchFilterProvider.notifier);
    n.state = change(n.state);
  }

  void _clear() {
    _text.clear();
    ref.read(searchFilterProvider.notifier).state = HomeFilter(
      kind: ref.read(searchFilterProvider).kind,
    );
  }

  Future<void> _save() async {
    final filter = ref.read(searchFilterProvider);
    final currency =
        ref.read(homesProvider).valueOrNull?.firstOrNull?.price.currency ??
        'EUR';
    await ref
        .read(savedSearchesProvider.notifier)
        .save(
          SavedSearch(
            id: Ids.next('s'),
            name: filter.summary(currency),
            filter: filter,
            alerts: true,
          ),
        );
    if (mounted) {
      showToast(context, 'Search saved. You will hear about new matches.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final filter = ref.watch(searchFilterProvider);
    final results = ref.watch(searchResultsProvider);
    final map = ref.watch(cityMapProvider).valueOrNull;
    final picked = results.where((h) => h.id == _pin).firstOrNull;

    return Material(
      color: p.paper,
      child: Column(
        children: [
          SizedBox(height: media.padding.top + Space.sm),
          Padding(
            padding: const EdgeInsets.only(right: Space.gutter, left: 6),
            child: Row(
              children: [
                const BackChevron(),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const SearchSurface(),
                        Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(Icons.search_rounded, size: 20, color: p.ink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: SearchKeys.field,
                                controller: _text,
                                autofocus:
                                    !widget.startOnMap &&
                                    filter.query.isEmpty &&
                                    Motion.ambient,
                                textInputAction: TextInputAction.search,
                                onChanged: (q) =>
                                    _update((f) => f.copyWith(query: q)),
                                style: context.title.copyWith(fontSize: 15),
                                cursorColor: p.accent,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: 'Area, street or home',
                                  hintStyle: context.body.copyWith(
                                    color: p.muted,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            if (filter.query.isNotEmpty)
                              RoundIcon(
                                icon: Icons.close_rounded,
                                label: 'Clear text',
                                size: 17,
                                onTap: () {
                                  _text.clear();
                                  _update((f) => f.copyWith(query: ''));
                                },
                              )
                            else
                              const SizedBox(width: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                _FilterButton(
                  count: filter.count,
                  onTap: () => showFilterSheet(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              Space.md,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 148,
                  child: Segmented<_View>(
                    values: _View.values,
                    labelOf: (v) => v == _View.list ? 'List' : 'Map',
                    value: _view,
                    height: 40,
                    keyPrefix: 'view',
                    onChanged: (v) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _view = v);
                    },
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    results.length == 1 ? '1 home' : '${results.length} homes',
                    key: const Key('search-count'),
                    style: context.caption,
                  ),
                ),
                TextButton.icon(
                  key: SearchKeys.save,
                  onPressed: results.isEmpty ? null : _save,
                  icon: const Icon(Icons.notifications_none_rounded, size: 17),
                  label: const Text('Save search'),
                  style: TextButton.styleFrom(
                    foregroundColor: p.accentInk,
                    disabledForegroundColor: p.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.font,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.short,
              child: results.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No homes match that',
                          message: filter.query.trim().isEmpty
                              ? 'Nothing on the market fits every filter. Loosen one and look again.'
                              : 'Nothing matches "${filter.query.trim()}" with these filters.',
                          action: 'Clear filters',
                          onAction: _clear,
                        ),
                      ),
                    )
                  : _view == _View.list
                  ? ListView.separated(
                      key: const ValueKey('list'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.sm,
                        Space.gutter,
                        media.padding.bottom + Sizes.tabBarReserve,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Space.xxl),
                      itemBuilder: (context, i) => HomeTile(
                        key: ValueKey(results[i].id),
                        home: results[i],
                        scope: 'search',
                        photoAspect: 16 / 10,
                        onTap: () =>
                            openHome(context, results[i], scope: 'search'),
                      ),
                    )
                  : map == null
                  ? const SizedBox.shrink()
                  : Stack(
                      key: const ValueKey('map'),
                      children: [
                        Positioned.fill(
                          child: CityMapView(
                            map: map,
                            interactive: true,
                            focus:
                                picked?.at ??
                                GeoPoint(
                                  (map.north + map.south) / 2 - .012,
                                  (map.west + map.east) / 2 - .01,
                                ),
                            zoom: picked == null ? 1.25 : 2.4,
                            selected: _pin,
                            onPin: (id) => setState(() => _pin = id),
                            onBackground: () => setState(() => _pin = null),
                            pins: [
                              for (final h in results)
                                MapPin(
                                  id: h.id,
                                  at: h.at,
                                  label: h.price.compact,
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: Space.gutter,
                          right: Space.gutter,
                          bottom: media.padding.bottom + Sizes.tabBarReserve,
                          child: AnimatedSwitcher(
                            duration: Motion.short,
                            switchInCurve: Motion.enter,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, .2),
                                  end: Offset.zero,
                                ).animate(a),
                                child: child,
                              ),
                            ),
                            child: picked == null
                                ? const SizedBox.shrink()
                                : Container(
                                    key: ValueKey(picked.id),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: p.card,
                                      borderRadius: BorderRadius.circular(
                                        Radii.lg,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: p.shadow,
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: HomeRow(
                                      key: SearchKeys.selected,
                                      home: picked,
                                      scope: 'map',
                                      onTap: () => openHome(
                                        context,
                                        picked,
                                        scope: 'map',
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: count == 0 ? 'Filters' : 'Filters, $count set',
      excludeSemantics: true,
      child: GestureDetector(
        key: SearchKeys.filters,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: count > 0 ? p.primary : p.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: count > 0 ? p.primary : p.line),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: count > 0 ? p.onPrimary : p.ink,
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.paper, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: p.onAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the filters over Search.
Future<void> showFilterSheet(BuildContext context) => showAppSheet<void>(
  context,
  title: 'Filters',
  builder: (_) => const FilterSheet(),
);
