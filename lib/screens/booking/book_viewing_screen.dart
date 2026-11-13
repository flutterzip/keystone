import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/format.dart';
import '../../models/home.dart';
import '../../models/viewing.dart';
import '../../providers/activity_providers.dart';
import '../../providers/core_providers.dart';
import '../../services/viewing_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/keystone_mark.dart';
import '../../widgets/primary_button.dart';
import '../shell/main_shell.dart';

abstract final class BookingKeys {
  static const confirm = Key('booking-confirm');
  static const done = Key('booking-done');
  static const notice = Key('booking-notice');
  static Key day(int i) => Key('booking-day-$i');
  static Key slot(DateTime t) => Key('booking-slot-${timeLabel(t)}');
  static Key mode(ViewingMode m) => Key('booking-mode-${m.name}');
}

/// Book a viewing: a day, a time, in person or by video, confirm. A time
/// that cannot be booked is still shown, and says why when it is tapped.
class BookViewingScreen extends ConsumerStatefulWidget {
  const BookViewingScreen({super.key, required this.homeId, this.reschedule});

  final String homeId;

  /// A viewing being moved, rather than a new one being booked.
  final Viewing? reschedule;

  @override
  ConsumerState<BookViewingScreen> createState() => _BookViewingScreenState();
}

class _BookViewingScreenState extends ConsumerState<BookViewingScreen> {
  static const _days = 14;

  late final DateTime _today = dayOf(ref.read(clockProvider)());
  int _day = 0;
  DateTime? _time;
  late ViewingMode _mode = widget.reschedule?.mode ?? ViewingMode.inPerson;
  String? _notice;
  bool _busy = false;
  Viewing? _booked;

  DateTime get _date => _today.add(Duration(days: _day));
  bool get _moving => widget.reschedule != null;

  Future<void> _confirm() async {
    final time = _time;
    if (time == null) {
      setState(() => _notice = 'Choose a time first.');
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    final viewings = ref.read(viewingsProvider.notifier);
    try {
      final v = _moving
          ? await viewings.reschedule(widget.reschedule!.id, time)
          : await viewings.book(widget.homeId, time, _mode);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _booked = v);
    } on SlotTaken catch (e) {
      // It went while the page was open: say so and let them pick again.
      if (mounted) {
        setState(() {
          _notice = e.reason;
          _time = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Could not book that. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final home = ref.watch(homeProvider(widget.homeId));
    final now = ref.watch(clockProvider)();
    if (home == null) {
      return const SubPage(title: 'Book a viewing', child: SizedBox.shrink());
    }
    final booked = _booked;
    if (booked != null) return _Booked(viewing: booked, home: home, now: now);

    final slots = ref.watch(
      slotsProvider((
        homeId: home.id,
        day: _date,
        ignoring: widget.reschedule?.id,
      )),
    );
    return SubPage(
      title: _moving ? 'Move your viewing' : 'Book a viewing',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: HomeRow(home: home, scope: 'booking', onTap: null),
                ),
                if (_moving)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.lg,
                      Space.gutter,
                      0,
                    ),
                    child: Notice(
                      'Currently ${inSentence(whenLabel(widget.reschedule!.at, now))}.',
                      icon: Icons.event_rounded,
                    ),
                  ),
                const _Label('Day'),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    itemCount: _days,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _DayChip(
                      key: BookingKeys.day(i),
                      date: _today.add(Duration(days: i)),
                      today: i == 0,
                      selected: i == _day,
                      onTap: () => setState(() {
                        _day = i;
                        _time = null;
                        _notice = null;
                      }),
                    ),
                  ),
                ),
                const _Label('Time'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: switch (slots) {
                    AsyncData(:final value) when value.isEmpty => const Notice(
                      'There are no viewings on a Sunday. Choose another day.',
                      icon: Icons.event_busy_rounded,
                    ),
                    AsyncData(:final value) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in value)
                          SelectChip(
                            key: BookingKeys.slot(s.at),
                            label: timeLabel(s.at),
                            selected: _time == s.at,
                            struck: !s.free,
                            onTap: () => setState(() {
                              _time = s.free ? s.at : null;
                              _notice = s.taken;
                            }),
                          ),
                      ],
                    ),
                    // A frame or two: a still placeholder, not a spinner.
                    _ => const SizedBox(height: 92),
                  },
                ),
                AnimatedSize(
                  duration: Motion.short,
                  curve: Motion.settle,
                  alignment: Alignment.topCenter,
                  child: _notice == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          key: BookingKeys.notice,
                          padding: const EdgeInsets.fromLTRB(
                            Space.gutter,
                            Space.md,
                            Space.gutter,
                            0,
                          ),
                          child: Notice(_notice!, error: true),
                        ),
                ),
                if (!_moving) ...[
                  const _Label('How'),
                  for (final m in ViewingMode.values)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        0,
                        Space.gutter,
                        Space.sm,
                      ),
                      child: _ModeCard(
                        key: BookingKeys.mode(m),
                        mode: m,
                        selected: m == _mode,
                        onTap: () => setState(() => _mode = m),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              media.padding.bottom + Space.md,
            ),
            decoration: BoxDecoration(
              color: p.card,
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _time == null
                      ? 'No time chosen yet'
                      : '${whenLabel(_time!, now)}, ${_mode.label.toLowerCase()}',
                  key: const Key('booking-summary'),
                  textAlign: TextAlign.center,
                  style: context.caption.copyWith(color: p.inkSoft),
                ),
                const SizedBox(height: Space.sm),
                PrimaryButton(
                  key: BookingKeys.confirm,
                  label: _moving ? 'Move viewing' : 'Confirm viewing',
                  busy: _busy,
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.xl,
      Space.gutter,
      Space.md,
    ),
    child: Text(
      text.toUpperCase(),
      style: context.label.copyWith(color: context.palette.muted),
    ),
  );
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.date,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.onPrimary : p.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${weekdayShort(date)} ${date.day} ${monthShort(date)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.quick,
          width: 58,
          decoration: BoxDecoration(
            color: selected ? p.primary : p.card,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: selected ? p.primary : p.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                today ? 'Today' : weekdayShort(date),
                maxLines: 1,
                style: context.caption.copyWith(
                  fontSize: 11.5,
                  color: selected ? fg.withValues(alpha: .8) : p.muted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${date.day}',
                style: context.heading.copyWith(
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ViewingMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label}. ${mode.note}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: selected ? p.accentWash : p.card,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected ? p.accent : p.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                mode == ViewingMode.video
                    ? Icons.videocam_outlined
                    : Icons.key_rounded,
                size: 22,
                color: selected ? p.accentInk : p.ink,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.label, style: context.title),
                    Text(mode.note, style: context.caption),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? p.accentInk : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The viewing is booked: the arch builds once more and the keystone locks
/// it, over when and where.
class _Booked extends ConsumerWidget {
  const _Booked({required this.viewing, required this.home, required this.now});

  final Viewing viewing;
  final Home home;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    return Material(
      color: p.paper,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.xxl,
          media.padding.top + Space.xxl,
          Space.xxl,
          media.padding.bottom + Space.lg,
        ),
        child: Column(
          children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 1300),
              builder: (_, t, _) => KeystoneMark(size: 112, built: t),
            ),
            const SizedBox(height: Space.xxl),
            Text(
              'Viewing booked',
              style: context.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.sm),
            Text(
              '${whenLabel(viewing.at, now)}, ${viewing.mode.label.toLowerCase()}',
              key: const Key('booked-when'),
              style: context.title.copyWith(color: p.accentInk),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.md),
            Text(
              viewing.mode == ViewingMode.video
                  ? 'The agent will call you in the app at the time. ${home.title} is saved to your viewings.'
                  : 'Meet the agent at ${home.address}. ${home.title} is saved to your viewings.',
              style: context.body,
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                key: BookingKeys.done,
                label: 'See my viewings',
                onPressed: () {
                  tabNavigator(context).popUntil((r) => r.isFirst);
                  ref.read(shellTabProvider.notifier).state = ShellTab.viewings;
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                quiet: true,
                label: 'Back to the home',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
