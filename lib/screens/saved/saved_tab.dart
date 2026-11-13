import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/home.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/linger.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/removable.dart';
import '../actions.dart';
import '../shell/main_shell.dart';
import 'compare_screen.dart';

abstract final class SavedKeys {
  static const compare = Key('saved-compare');
  static const go = Key('saved-compare-go');
  static Key remove(String id) => Key('saved-remove-$id');
  static Key pick(String id) => Key('saved-pick-$id');
}

/// The shortlist. Homes can be removed (they blow away, with an undo) and
/// any two can be put side by side.
class SavedTab extends ConsumerStatefulWidget {
  const SavedTab({super.key});

  @override
  ConsumerState<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends ConsumerState<SavedTab> {
  final _linger = Linger();
  bool _comparing = false;
  final _picked = <String>[];

  void _remove(Home home) {
    final live = ref.read(savedIdsProvider);
    final index = live.indexOf(home.id);
    final saved = ref.read(savedProvider.notifier);
    HapticFeedback.selectionClick();
    setState(() {
      _linger.hold(home.id, live);
      _picked.remove(home.id);
    });
    saved.remove(home.id);
    showToast(
      context,
      '${home.title} removed',
      icon: Icons.favorite_border_rounded,
      onUndo: () => saved.restore(home.id, index),
      onClosed: () {
        if (mounted) setState(() => _linger.release(home.id));
      },
    );
  }

  void _pick(String id) => setState(() {
    if (_picked.remove(id)) return;
    // Two at most: a third takes the place of the first.
    if (_picked.length == 2) _picked.removeAt(0);
    _picked.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final live = ref.watch(savedIdsProvider);
    final all = ref.watch(homesProvider).valueOrNull ?? const <Home>[];
    final rows = homesById(all, _linger.rows(live));
    final count = homesById(all, live).length;

    return TabPage(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              0,
              media.padding.top + Space.lg,
              0,
              media.padding.bottom + Sizes.tabBarReserve + 70,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saved', style: context.display),
                          Text(
                            _comparing
                                ? 'Choose two homes to compare'
                                : count == 1
                                ? '1 home on your shortlist'
                                : '$count homes on your shortlist',
                            key: const Key('saved-count'),
                            style: context.caption,
                          ),
                        ],
                      ),
                    ),
                    if (count >= 2)
                      TextButton.icon(
                        key: SavedKeys.compare,
                        onPressed: () => setState(() {
                          _comparing = !_comparing;
                          _picked.clear();
                        }),
                        icon: Icon(
                          _comparing
                              ? Icons.close_rounded
                              : Icons.compare_arrows_rounded,
                          size: 18,
                        ),
                        label: Text(_comparing ? 'Cancel' : 'Compare'),
                        style: TextButton.styleFrom(
                          foregroundColor: p.ink,
                          shape: StadiumBorder(side: BorderSide(color: p.line)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(
                            fontFamily: AppTheme.font,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Nothing saved yet',
                    message:
                        'Tap the heart on a home and it lands here, ready to compare.',
                    action: 'Browse homes',
                    onAction: () => ref.read(shellTabProvider.notifier).state =
                        ShellTab.home,
                  ),
                ),
              for (final h in rows)
                Removable(
                  key: ValueKey(h.id),
                  gone: _linger.isGone(h.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      0,
                      Space.gutter - 10,
                      Space.lg,
                    ),
                    child: HomeRow(
                      home: h,
                      scope: 'saved',
                      onTap: _comparing
                          ? () => _pick(h.id)
                          : () => openHome(context, h, scope: 'saved'),
                      trailing: _comparing
                          ? _PickMark(
                              key: SavedKeys.pick(h.id),
                              order: _picked.indexOf(h.id),
                              onTap: () => _pick(h.id),
                            )
                          : RoundIcon(
                              key: SavedKeys.remove(h.id),
                              icon: Icons.favorite_rounded,
                              color: p.accent,
                              label: 'Remove ${h.title} from saved',
                              onTap: _linger.isGone(h.id)
                                  ? null
                                  : () => _remove(h),
                            ),
                    ),
                  ),
                ),
            ],
          ),
          // Slides up once comparing starts; says what is still needed.
          Positioned(
            left: Space.gutter,
            right: Space.gutter,
            bottom: media.padding.bottom + Sizes.tabBarReserve - 14,
            child: _Rising(
              shown: _comparing,
              child: PrimaryButton(
                key: SavedKeys.go,
                label: switch (_picked.length) {
                  0 => 'Choose two homes',
                  1 => 'Choose one more',
                  _ => 'Compare these two',
                },
                icon: Icons.compare_arrows_rounded,
                onPressed: () {
                  if (_picked.length < 2) {
                    showToast(
                      context,
                      _picked.isEmpty
                          ? 'Tap two homes to compare them.'
                          : 'Tap one more home.',
                      icon: Icons.info_outline_rounded,
                    );
                    return;
                  }
                  tabNavigator(
                    context,
                  ).push(tabRoute(CompareScreen(a: _picked[0], b: _picked[1])));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in when [shown], and takes it out of reach
/// when not.
class _Rising extends StatelessWidget {
  const _Rising({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !shown,
    child: AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: Motion.short,
      child: AnimatedSlide(
        offset: shown ? Offset.zero : const Offset(0, .5),
        duration: Motion.medium,
        curve: Motion.settle,
        child: child,
      ),
    ),
  );
}

/// A numbered circle: which of the two a home has been chosen as.
class _PickMark extends StatelessWidget {
  const _PickMark({super.key, required this.order, required this.onTap});

  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final on = order >= 0;
    return Semantics(
      button: true,
      selected: on,
      label: on ? 'Chosen' : 'Choose to compare',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.quick,
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? p.accent : null,
                shape: BoxShape.circle,
                border: Border.all(color: on ? p.accent : p.muted, width: 1.5),
              ),
              child: on
                  ? Text(
                      '${order + 1}',
                      style: TextStyle(
                        color: p.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
