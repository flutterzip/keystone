import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/application.dart';
import '../../models/format.dart';
import '../../models/home.dart';
import '../../models/money.dart';
import '../../providers/activity_providers.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../services/application_repository.dart';
import '../../widgets/app_field.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/primary_button.dart';
import 'application_status.dart';

abstract final class ApplicationKeys {
  static const submit = Key('application-submit');
  static const note = Key('application-note');
  static const offer = Key('application-offer');
  static const pay = Key('application-pay');
  static const withdraw = Key('application-withdraw');
  static const declined = Key('application-declined');
  static Key card(String id) => Key('application-card-$id');
  static Key moveIn(int i) => Key('application-movein-$i');
}

/// Apply to rent a home, or make an offer to buy it. Once sent, the same
/// page becomes its status: a timeline, and the holding deposit when due.
class ApplicationScreen extends ConsumerWidget {
  const ApplicationScreen({super.key, required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider(homeId));
    final application = ref.watch(applicationForHomeProvider(homeId));
    if (home == null) {
      return const SubPage(title: 'Application', child: SizedBox.shrink());
    }
    return SubPage(
      title: application != null
          ? application.kind.label
          : home.isRent
          ? 'Apply to rent'
          : 'Make an offer',
      child: application == null
          ? _Form(home: home)
          : ApplicationStatus(application: application, home: home),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.home});

  final Home home;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _note = TextEditingController();
  late final DateTime _today = dayOf(ref.read(clockProvider)());

  /// Move-in dates on offer: the next six Mondays.
  late final List<DateTime> _dates = [
    for (var i = 1; i <= 6; i++)
      _today.add(Duration(days: (8 - _today.weekday) % 7 + 7 * i)),
  ];
  int _moveIn = 1;

  /// The offer as a share of the asking price.
  double _pct = 100;
  bool _busy = false;
  String? _error;

  Money get _offer => widget.home.price.copyWith(
    // To the nearest thousand: nobody offers odd euros on a house.
    amount: (widget.home.price.amount * _pct / 100 / 100000).round() * 100000,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(applicationsProvider.notifier)
          .submit(
            ApplicationDraft(
              home: widget.home,
              offer: widget.home.isRent ? null : _offer,
              moveIn: widget.home.isRent ? _dates[_moveIn] : null,
              note: _note.text,
            ),
          );
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send that. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final home = widget.home;
    final now = ref.watch(nowProvider);
    final documents = ref.watch(documentsProvider).valueOrNull ?? const [];
    final verified = documents.where((d) => d.verified(now)).length;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
      child: Text(
        text.toUpperCase(),
        style: context.label.copyWith(color: p.muted),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              Space.xl,
            ),
            children: [
              HomeRow(home: home, scope: 'apply', onTap: null),
              if (home.isRent) ...[
                label('Move in on'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, d) in _dates.indexed)
                      SelectChip(
                        key: ApplicationKeys.moveIn(i),
                        label: '${d.day} ${monthShort(d)}',
                        selected: i == _moveIn,
                        onTap: () => setState(() => _moveIn = i),
                      ),
                  ],
                ),
                label('Your documents'),
                Notice(
                  documents.isEmpty
                      ? 'No documents yet. Add an ID and proof of income in your profile to be approved sooner.'
                      : '${documents.length} from your profile go with this, $verified verified.',
                  icon: Icons.folder_outlined,
                ),
              ] else ...[
                label('Your offer'),
                Text(
                  _offer.text,
                  key: ApplicationKeys.offer,
                  style: context.display.copyWith(
                    fontSize: 32,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _pct == 100
                      ? 'The asking price'
                      : '${(100 - _pct).abs().toStringAsFixed(_pct % 1 == 0 ? 0 : 1)}% ${_pct < 100 ? 'under' : 'over'} the asking price of ${home.price.text}',
                  style: context.caption,
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: p.accent,
                    inactiveTrackColor: p.line,
                    thumbColor: p.primary,
                    overlayColor: p.accent.withValues(alpha: .14),
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Semantics(
                    label: 'Offer',
                    value: _offer.text,
                    child: Slider(
                      value: _pct,
                      min: 85,
                      max: 105,
                      divisions: 40,
                      onChanged: (v) => setState(() => _pct = v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.xl),
              AppField(
                fieldKey: ApplicationKeys.note,
                label: 'A note to the agent',
                controller: _note,
                hint: home.isRent
                    ? 'Who is moving in, and for how long'
                    : 'Conditions, timing, how you are paying',
                icon: Icons.edit_note_rounded,
                capitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: Space.lg),
              Notice(
                home.isRent
                    ? 'Nothing is charged now. A holding deposit is only asked for once you are approved.'
                    : 'An offer is not binding until contracts are signed.',
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            media.viewInsets.bottom > 0
                ? media.viewInsets.bottom + Space.md
                : media.padding.bottom + Sizes.tabBarReserve - 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Notice(_error!, error: true),
                ),
              PrimaryButton(
                key: ApplicationKeys.submit,
                label: home.isRent ? 'Send application' : 'Send offer',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Every application and offer, newest first.
class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key, required this.onOpen});

  final ValueChanged<Home> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final now = ref.watch(nowProvider);
    final all =
        ref.watch(applicationsProvider).valueOrNull ?? const <Application>[];
    return SubPage(
      title: 'Applications and offers',
      child: all.isEmpty
          ? const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Nothing sent yet',
                  message:
                      'After a viewing you can apply to rent a home, or make an offer to buy it.',
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                media.padding.bottom + Sizes.tabBarReserve,
              ),
              itemCount: all.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.lg),
              itemBuilder: (context, i) {
                final a = all[i];
                final home = ref.watch(homeProvider(a.homeId));
                if (home == null) return const SizedBox.shrink();
                return Opacity(
                  opacity: a.withdrawn ? .6 : 1,
                  child: HomeRow(
                    key: ValueKey(a.id),
                    home: home,
                    scope: 'application-${a.id}',
                    onTap: a.withdrawn ? null : () => onOpen(home),
                    note: Text(
                      '${a.kind.label}, sent ${inSentence(agoLabel(a.submittedAt, now))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption.copyWith(color: p.inkSoft),
                    ),
                    trailing: StatusPill(
                      label: a.statusLabel(now),
                      live: a.depositDue(now),
                      muted: a.withdrawn,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
