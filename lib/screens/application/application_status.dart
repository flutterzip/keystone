import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keystone/kit/kit.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/account.dart';
import '../../models/application.dart';
import '../../models/format.dart';
import '../../models/home.dart';
import '../../providers/activity_providers.dart';
import '../../providers/core_providers.dart';
import '../../services/application_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/primary_button.dart';
import '../actions.dart';
import 'application_screen.dart';

/// Where an application has got to: the home, a timeline worked out from
/// the clock, and the holding deposit when it is due.
class ApplicationStatus extends ConsumerStatefulWidget {
  const ApplicationStatus({
    super.key,
    required this.application,
    required this.home,
  });

  final Application application;
  final Home home;

  @override
  ConsumerState<ApplicationStatus> createState() => _ApplicationStatusState();
}

class _ApplicationStatusState extends ConsumerState<ApplicationStatus> {
  String? _cardId;
  bool _declined = false;

  Future<bool> _pay(PaymentCard card) async {
    setState(() => _declined = false);
    try {
      await ref
          .read(applicationsProvider.notifier)
          .payDeposit(widget.application.id, card);
      return true;
    } on PaymentDeclined {
      if (mounted) setState(() => _declined = true);
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _withdraw() async {
    final a = widget.application;
    final yes = await confirmRemove(
      context,
      title: a.isOffer ? 'Withdraw your offer?' : 'Withdraw your application?',
      message:
          'The agent is told straight away and ${widget.home.title} stays on the market.',
      action: a.isOffer ? 'Withdraw offer' : 'Withdraw application',
    );
    if (!yes || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final p = context.palette;
    final applications = ref.read(applicationsProvider.notifier);
    await applications.withdraw(a.id);
    showToastOn(
      messenger,
      p,
      a.isOffer ? 'Offer withdrawn' : 'Application withdrawn',
      icon: Icons.undo_rounded,
      onUndo: () => applications.restore(a.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final a = widget.application;
    final home = widget.home;
    final now = ref.watch(nowProvider);
    final cards = ref.watch(cardsProvider).valueOrNull ?? const <PaymentCard>[];
    final deposit = ref.watch(holdingDepositProvider(home)).valueOrNull;
    final card =
        cards.where((c) => c.id == _cardId).firstOrNull ?? cards.firstOrNull;
    final stages = a.stages(now);
    final due = a.depositDue(now);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        media.padding.bottom + Sizes.tabBarReserve,
      ),
      children: [
        HomeRow(
          home: home,
          scope: 'status',
          onTap: () => openHome(context, home),
          trailing: StatusPill(label: a.statusLabel(now), live: due),
        ),
        const SizedBox(height: Space.lg),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              if (a.offer != null) ReceiptRow('Your offer', a.offer!.text),
              if (a.moveIn != null)
                ReceiptRow(
                  'Move in',
                  '${a.moveIn!.day} ${monthShort(a.moveIn!)} ${a.moveIn!.year}',
                ),
              ReceiptRow('Sent', whenLabel(a.submittedAt, now)),
              if (a.note.isNotEmpty) ...[
                Divider(height: Space.xl, color: p.line),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(a.note, style: context.body),
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.settle,
          alignment: Alignment.topCenter,
          child: !due || deposit == null || card == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'PAY WITH',
                        style: context.label.copyWith(color: p.muted),
                      ),
                      const SizedBox(height: Space.sm),
                      for (final c in cards)
                        _CardRow(
                          key: ApplicationKeys.card(c.id),
                          card: c,
                          selected: c.id == card.id,
                          onTap: () => setState(() {
                            _cardId = c.id;
                            _declined = false;
                          }),
                        ),
                      if (_declined)
                        Padding(
                          key: ApplicationKeys.declined,
                          padding: const EdgeInsets.only(top: Space.sm),
                          child: Notice(
                            '${card.masked} was declined. Nothing was charged. Try another card.',
                            error: true,
                          ),
                        ),
                      const SizedBox(height: Space.lg),
                      // The button becomes its own receipt.
                      KeyedSubtree(
                        key: ApplicationKeys.pay,
                        child: Motion.loops(context)
                            ? PayButton(
                                label: 'Pay ${deposit.text} deposit',
                                paidLabel: 'Deposit paid',
                                failedLabel: 'Declined. Try again',
                                color: p.primary,
                                foreground: p.onPrimary,
                                height: Sizes.buttonHeight,
                                onPay: () => _pay(card),
                              )
                            : PrimaryButton(
                                label: 'Pay ${deposit.text} deposit',
                                onPressed: () => _pay(card),
                              ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        home.isRent
                            ? 'A week of rent. It comes off your first month.'
                            : 'A reservation fee. It comes off the price on completion.',
                        textAlign: TextAlign.center,
                        style: context.caption,
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: Space.xl),
        for (final (i, s) in stages.indexed)
          _StageRow(
            stage: s,
            now: now,
            first: i == 0,
            last: i == stages.length - 1,
            // The step being waited on: the first not yet done.
            current: !s.done && (i == 0 || stages[i - 1].done),
          ),
        const SizedBox(height: Space.xl),
        if (a.depositPaidAt == null)
          Center(
            child: TextButton(
              key: ApplicationKeys.withdraw,
              onPressed: _withdraw,
              style: TextButton.styleFrom(
                foregroundColor: p.error,
                textStyle: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: Text(
                a.isOffer ? 'Withdraw offer' : 'Withdraw application',
              ),
            ),
          ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.now,
    required this.first,
    required this.last,
    required this.current,
  });

  final ApplicationStage stage;
  final DateTime now;
  final bool first;
  final bool last;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = stage.done;
    final when = stage.at == null
        ? null
        : done
        ? whenLabel(stage.at!, now)
        : 'Expected ${inSentence(dayLabel(stage.at!, now))}';
    return Semantics(
      label:
          '${stage.title}, ${done
              ? 'done'
              : current
              ? 'in progress'
              : 'to come'}. ${stage.note}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 6,
                    color: first ? null : (done ? p.accent : p.line),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: done ? p.accent : p.paper,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done || current ? p.accent : p.line,
                        width: 2,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check_rounded, size: 13, color: p.onAccent)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: last ? null : (done ? p.accent : p.line),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5, bottom: Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stage.title,
                            style: context.title.copyWith(
                              color: done || current ? p.ink : p.muted,
                            ),
                          ),
                        ),
                        if (when != null) Text(when, style: context.caption),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stage.note,
                      style: context.caption.copyWith(
                        color: done || current ? p.inkSoft : p.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    super.key,
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final PaymentCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '${card.masked}, expires ${card.expiry}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          margin: const EdgeInsets.only(bottom: Space.sm),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          height: 54,
          decoration: BoxDecoration(
            color: selected ? p.accentWash : p.card,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? p.accent : p.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 20, color: p.ink),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  card.masked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
              ),
              Text(card.expiry, style: context.caption),
              const SizedBox(width: Space.md),
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
