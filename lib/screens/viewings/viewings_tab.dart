import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/format.dart';
import '../../models/home.dart';
import '../../models/viewing.dart';
import '../../providers/activity_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/linger.dart';
import '../../widgets/removable.dart';
import '../../widgets/viewing_island.dart';
import '../actions.dart';
import '../shell/main_shell.dart';

abstract final class ViewingKeys {
  static Key card(String id) => Key('viewing-$id');
  static Key cancel(String id) => Key('viewing-cancel-$id');
  static Key move(String id) => Key('viewing-move-$id');
  static Key apply(String id) => Key('viewing-apply-$id');
}

enum _Tense { upcoming, past }

/// Viewings: what is coming up, and what has been. One that starts within
/// the hour shows a live countdown at the top.
class ViewingsTab extends ConsumerStatefulWidget {
  const ViewingsTab({super.key});

  @override
  ConsumerState<ViewingsTab> createState() => _ViewingsTabState();
}

class _ViewingsTabState extends ConsumerState<ViewingsTab> {
  final _linger = Linger();
  _Tense _tense = _Tense.upcoming;

  Future<void> _cancel(Viewing v, Home home, List<String> live) async {
    final yes = await confirmRemove(
      context,
      title: 'Cancel this viewing?',
      message:
          '${home.title}, ${inSentence(whenLabel(v.at, ref.read(clockProvider)()))}. The agent is told straight away.',
      action: 'Cancel viewing',
      keep: 'Keep viewing',
    );
    if (!yes || !mounted) return;
    final viewings = ref.read(viewingsProvider.notifier);
    HapticFeedback.selectionClick();
    setState(() => _linger.hold(v.id, live));
    await viewings.cancel(v.id);
    if (!mounted) return;
    showToast(
      context,
      'Viewing cancelled',
      icon: Icons.event_busy_rounded,
      onUndo: () => viewings.restore(v.id),
      onClosed: () {
        if (mounted) setState(() => _linger.release(v.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final now = ref.watch(nowProvider);
    final all = ref.watch(viewingsProvider).valueOrNull ?? const <Viewing>[];
    final byId = {for (final v in all) v.id: v};
    bool ahead(Viewing v) => switch (v.status(now)) {
      ViewingStatus.upcoming || ViewingStatus.soon => true,
      _ => false,
    };
    final upcoming = [
      for (final v in all)
        if (ahead(v)) v.id,
    ];
    // Most recent first.
    final past = [
      for (final v in all.reversed)
        if (!ahead(v)) v.id,
    ];
    final soon = ref.watch(soonViewingProvider);
    final soonHome = soon == null ? null : ref.watch(homeProvider(soon.homeId));
    final rows = _tense == _Tense.upcoming
        ? _linger.rows(upcoming)
        : past.where((id) => !_linger.isGone(id)).toList();

    return TabPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          media.padding.top + Space.lg,
          0,
          media.padding.bottom + Sizes.tabBarReserve,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Viewings', style: context.display),
                if (soon != null && soonHome != null) ...[
                  const SizedBox(height: Space.lg),
                  Center(
                    child: ViewingIsland(viewing: soon, home: soonHome),
                  ),
                ],
                const SizedBox(height: Space.lg),
                Segmented<_Tense>(
                  values: _Tense.values,
                  labelOf: (t) => t == _Tense.upcoming
                      ? 'Upcoming, ${upcoming.length}'
                      : 'Past, ${past.length}',
                  value: _tense,
                  keyPrefix: 'viewings',
                  onChanged: (t) => setState(() => _tense = t),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: _tense == _Tense.upcoming
                  ? EmptyState(
                      icon: Icons.event_rounded,
                      title: 'No viewings booked',
                      message:
                          'Find a home you like and book a time to see it, in person or by video.',
                      action: 'Browse homes',
                      onAction: () =>
                          ref.read(shellTabProvider.notifier).state =
                              ShellTab.home,
                    )
                  : const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Nothing here yet',
                      message: 'Homes you have viewed are kept here.',
                    ),
            ),
          for (final id in rows)
            if (byId[id] case final v?)
              Removable(
                key: ValueKey('${_tense.name}-$id'),
                gone: _linger.isGone(id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.lg,
                  ),
                  child: _ViewingCard(
                    key: ViewingKeys.card(id),
                    viewing: v,
                    now: now,
                    onCancel: (home) => _cancel(v, home, upcoming),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ViewingCard extends ConsumerWidget {
  const _ViewingCard({
    super.key,
    required this.viewing,
    required this.now,
    required this.onCancel,
  });

  final Viewing viewing;
  final DateTime now;
  final ValueChanged<Home> onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final v = viewing;
    final home = ref.watch(homeProvider(v.homeId));
    if (home == null) return const SizedBox.shrink();
    final status = v.status(now);
    final application = ref.watch(applicationForHomeProvider(home.id));
    final ahead =
        status == ViewingStatus.upcoming || status == ViewingStatus.soon;

    Widget action(Key key, String label, IconData icon, VoidCallback onTap) =>
        Expanded(
          child: TextButton.icon(
            key: key,
            onPressed: onTap,
            icon: Icon(icon, size: 17),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: TextButton.styleFrom(
              foregroundColor: p.ink,
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(
                fontFamily: AppTheme.font,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Opacity(
              opacity: status == ViewingStatus.cancelled ? .6 : 1,
              child: HomeRow(
                home: home,
                scope: 'viewing-${v.id}',
                onTap: () => openHome(context, home, scope: 'viewing-${v.id}'),
                note: Row(
                  children: [
                    Icon(
                      v.mode == ViewingMode.video
                          ? Icons.videocam_outlined
                          : Icons.key_rounded,
                      size: 14,
                      color: p.accentInk,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        whenLabel(v.at, now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                          decoration: status == ViewingStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: switch (status) {
                    ViewingStatus.soon => StatusPill(
                      label: now.isBefore(v.at) ? untilLabel(v.at, now) : 'Now',
                      live: true,
                    ),
                    ViewingStatus.upcoming => const StatusPill(label: 'Booked'),
                    ViewingStatus.past => const StatusPill(label: 'Viewed'),
                    ViewingStatus.cancelled => const StatusPill(
                      label: 'Cancelled',
                      muted: true,
                    ),
                  },
                ),
              ),
            ),
          ),
          Divider(color: p.line),
          Row(
            children: [
              if (ahead) ...[
                action(
                  ViewingKeys.move(v.id),
                  'Reschedule',
                  Icons.update_rounded,
                  () => openBooking(context, home, reschedule: v),
                ),
                Container(width: 1, height: 22, color: p.line),
                action(
                  ViewingKeys.cancel(v.id),
                  'Cancel',
                  Icons.close_rounded,
                  () => onCancel(home),
                ),
              ] else if (status == ViewingStatus.past)
                action(
                  ViewingKeys.apply(v.id),
                  application != null
                      ? '${application.kind.label}: ${application.statusLabel(now)}'
                      : home.isRent
                      ? 'Apply to rent it'
                      : 'Make an offer',
                  Icons.assignment_outlined,
                  () => openApplication(context, home),
                )
              else
                action(
                  ViewingKeys.move(v.id),
                  'Book again',
                  Icons.event_repeat_rounded,
                  () => openBooking(context, home),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
