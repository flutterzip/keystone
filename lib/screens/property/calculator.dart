import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/home.dart';
import '../../models/money.dart';
import '../../widgets/common.dart';

/// The monthly repayment on [loan] minor units over [years] at [ratePct] a
/// year: the standard annuity formula, rounded to the minor unit.
int monthlyRepayment(int loan, double ratePct, int years) {
  final n = years * 12;
  final r = ratePct / 100 / 12;
  if (r == 0) return (loan / n).round();
  return (loan * r / (1 - math.pow(1 + r, -n))).round();
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({
    required this.label,
    required this.value,
    required this.at,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double at, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.caption)),
            Text(value, style: context.price),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: p.accent,
            inactiveTrackColor: p.line,
            thumbColor: p.primary,
            overlayColor: p.accent.withValues(alpha: .14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            // The value is printed above the track, not in a balloon.
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Semantics(
            label: label,
            value: value,
            child: Slider(
              value: at.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// What buying [home] would cost a month. Every figure is worked out from
/// the three dials as they move; nothing is stored.
class MortgageCalculator extends StatefulWidget {
  const MortgageCalculator({super.key, required this.home});

  final Home home;

  @override
  State<MortgageCalculator> createState() => _MortgageCalculatorState();
}

class _MortgageCalculatorState extends State<MortgageCalculator> {
  double _deposit = 20;
  double _years = 30;
  double _rate = 3.6;

  @override
  Widget build(BuildContext context) {
    final price = widget.home.price;
    final deposit = (price.amount * _deposit / 100).round();
    final loan = price.amount - deposit;
    final monthly = monthlyRepayment(loan, _rate, _years.round());
    String m(int v) => formatMoney(v, price.currency);
    return _Card(
      children: [
        Text(
          'A MONTH',
          style: context.label.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: 2),
        Text(
          m((monthly / 100).round() * 100),
          key: const Key('calc-monthly'),
          style: context.display.copyWith(
            fontSize: 32,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: Space.md),
        _Dial(
          label: 'Deposit, ${_deposit.round()}%',
          value: m(deposit),
          at: _deposit,
          min: 10,
          max: 50,
          divisions: 8,
          onChanged: (v) => setState(() => _deposit = v),
        ),
        _Dial(
          label: 'Term',
          value: '${_years.round()} years',
          at: _years,
          min: 10,
          max: 40,
          divisions: 6,
          onChanged: (v) => setState(() => _years = v),
        ),
        _Dial(
          label: 'Interest rate',
          value: '${_rate.toStringAsFixed(1)}%',
          at: _rate,
          min: 2,
          max: 7,
          divisions: 50,
          onChanged: (v) => setState(() => _rate = v),
        ),
        const Divider(height: Space.xl),
        ReceiptRow('Loan', m(loan)),
        ReceiptRow('Paid back in total', m(monthly * _years.round() * 12)),
        const SizedBox(height: Space.sm),
        const Notice('An indicative figure, not a mortgage offer.'),
      ],
    );
  }
}

/// How the rent on [home] sits against an income, and what moving in costs.
class RentCalculator extends StatefulWidget {
  const RentCalculator({super.key, required this.home});

  final Home home;

  @override
  State<RentCalculator> createState() => _RentCalculatorState();
}

class _RentCalculatorState extends State<RentCalculator> {
  /// Monthly income after tax, in whole units. Starts at three times the
  /// rent, rounded to the nearest hundred.
  late double _income =
      ((widget.home.price.amount * 3 / 100) / 100).round() * 100.0;

  /// Months of rent held as the tenancy deposit.
  static const depositMonths = 2;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rent = widget.home.price;
    final share = rent.amount / 100 / _income;
    final pct = (share * 100).round();
    final (verdict, icon) = switch (share) {
      <= .35 => ('Comfortable', Icons.check_circle_outline_rounded),
      <= .45 => ('A stretch', Icons.error_outline_rounded),
      _ => ('Too much of your income', Icons.block_rounded),
    };
    String m(int v) => formatMoney(v, rent.currency);
    return _Card(
      children: [
        Text(
          'RENT AS A SHARE OF INCOME',
          style: context.label.copyWith(color: p.muted),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$pct%',
              key: const Key('calc-share'),
              style: context.display.copyWith(
                fontSize: 32,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: share <= .35 ? p.positive : p.error,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        verdict,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.title.copyWith(
                          color: share <= .35 ? p.positive : p.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: p.line),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: share.clamp(0.0, 1.0),
                  child: ColoredBox(color: p.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        _Dial(
          label: 'Household income a month, after tax',
          value: m(_income.round() * 100),
          at: _income,
          min: 1500,
          max: 20000,
          divisions: 185,
          onChanged: (v) => setState(() => _income = v),
        ),
        const Divider(height: Space.xl),
        ReceiptRow('First month', rent.text),
        ReceiptRow(
          'Deposit, $depositMonths months',
          m(rent.amount * depositMonths),
        ),
        ReceiptRow(
          'To move in',
          m(rent.amount * (depositMonths + 1)),
          strong: true,
        ),
      ],
    );
  }
}
