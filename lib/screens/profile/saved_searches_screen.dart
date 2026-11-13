import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/home.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/linger.dart';
import '../../widgets/removable.dart';
import '../actions.dart';

abstract final class SearchesKeys {
  static Key row(String id) => Key('saved-search-$id');
  static Key alerts(String id) => Key('saved-search-alerts-$id');
  static Key remove(String id) => Key('saved-search-remove-$id');
}

/// Searches kept for later. Each says how many homes match now, runs again
/// with a tap, and can send alerts for new matches.
class SavedSearchesScreen extends ConsumerStatefulWidget {
  const SavedSearchesScreen({super.key});

  @override
  ConsumerState<SavedSearchesScreen> createState() =>
      _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends ConsumerState<SavedSearchesScreen> {
  final _linger = Linger();
  // Removed searches, kept so their rows can still be drawn while lingering.
  final _removed = <String, SavedSearch>{};

  void _remove(SavedSearch s, List<SavedSearch> live) {
    final ids = [for (final x in live) x.id];
    final index = ids.indexOf(s.id);
    final searches = ref.read(savedSearchesProvider.notifier);
    HapticFeedback.selectionClick();
    setState(() {
      _removed[s.id] = s;
      _linger.hold(s.id, ids);
    });
    searches.remove(s.id);
    showToast(
      context,
      'Search removed',
      icon: Icons.notifications_off_outlined,
      onUndo: () => searches.save(s, at: index),
      onClosed: () {
        if (mounted) {
          setState(() {
            _linger.release(s.id);
            _removed.remove(s.id);
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final live =
        ref.watch(savedSearchesProvider).valueOrNull ?? const <SavedSearch>[];
    final homes = ref.watch(homesProvider).valueOrNull ?? const <Home>[];
    final now = ref.watch(nowProvider);
    final currency = homes.firstOrNull?.price.currency ?? 'EUR';
    final byId = {..._removed, for (final s in live) s.id: s};
    final rows = _linger.rows([for (final s in live) s.id]);

    return SubPage(
      title: 'Saved searches',
      child: rows.isEmpty
          ? const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No saved searches',
                  message:
                      'Set your filters in Search and tap "Save search" to hear about new homes that match.',
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                media.padding.bottom + Sizes.tabBarReserve,
              ),
              children: [
                for (final id in rows)
                  if (byId[id] case final s?)
                    Removable(
                      key: ValueKey(id),
                      gone: _linger.isGone(id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: Builder(
                          builder: (context) {
                            final matches = s.filter.apply(homes);
                            final fresh = matches
                                .where((h) => h.isNew(now))
                                .length;
                            return Container(
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(Radii.lg),
                                border: Border.all(color: p.line),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Semantics(
                                    button: true,
                                    label:
                                        '${s.name}. ${matches.length} homes match. Run this search',
                                    excludeSemantics: true,
                                    child: InkWell(
                                      key: SearchesKeys.row(id),
                                      onTap: () {
                                        ref
                                            .read(searchFilterProvider.notifier)
                                            .state = s
                                            .filter;
                                        openSearch(context);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          Space.lg,
                                          Space.lg,
                                          Space.sm,
                                          Space.md,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    s.name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: context.title
                                                        .copyWith(fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    s.filter.summary(currency),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: context.caption,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      StatusPill(
                                                        label:
                                                            matches.length == 1
                                                            ? '1 home'
                                                            : '${matches.length} homes',
                                                      ),
                                                      if (fresh > 0) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        StatusPill(
                                                          label: '$fresh new',
                                                          live: true,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            RoundIcon(
                                              key: SearchesKeys.remove(id),
                                              icon:
                                                  Icons.delete_outline_rounded,
                                              label: 'Remove ${s.name}',
                                              onTap: _linger.isGone(id)
                                                  ? null
                                                  : () => _remove(s, live),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(color: p.line),
                                  SwitchListTile.adaptive(
                                    key: SearchesKeys.alerts(id),
                                    value: s.alerts,
                                    onChanged: (v) => ref
                                        .read(savedSearchesProvider.notifier)
                                        .save(s.copyWith(alerts: v)),
                                    dense: true,
                                    activeThumbColor: p.onAccent,
                                    activeTrackColor: p.accent,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: Space.lg,
                                    ),
                                    title: Text(
                                      s.alerts
                                          ? 'Alerts on for new matches'
                                          : 'Alerts off',
                                      style: context.caption.copyWith(
                                        color: p.inkSoft,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
