import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/home.dart';
import '../../models/money.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../property/property_sections.dart' show amenityIcon;

abstract final class FilterKeys {
  static const apply = Key('filter-apply');
  static const reset = Key('filter-reset');
  static const price = Key('filter-price');
}

/// Rent or Buy, a price range, beds, baths, the kind of home and what it
/// must have. Changes are tried on a draft, with the count of matches on
/// the button, and only kept when that button is pressed.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late HomeFilter _draft = ref.read(searchFilterProvider);

  /// The price slider's reach for a kind: the market's own range, rounded
  /// out, so it always spans every home.
  (int, int, int) _bounds(List<Home> homes) {
    final prices = [
      for (final h in homes)
        if (_draft.kind == null || h.kind == _draft.kind) h.price.amount,
    ];
    if (prices.isEmpty) return (0, 100000, 10000);
    final hi = prices.reduce((a, b) => a > b ? a : b);
    final step = hi > 50000000
        ? 25000000
        : hi > 1000000
        ? 5000000
        : 25000;
    return (0, (hi / step).ceil() * step, step);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final homes = ref.watch(homesProvider).valueOrNull ?? const <Home>[];
    final currency = homes.firstOrNull?.price.currency ?? 'EUR';
    final (lo, hi, step) = _bounds(homes);
    final from = (_draft.minPrice ?? lo).clamp(lo, hi).toDouble();
    final to = (_draft.maxPrice ?? hi).clamp(lo, hi).toDouble();
    final matches = _draft.apply(homes).length;
    final types = {for (final h in homes) h.type}.toList()..sort();
    final amenities = {for (final h in homes) ...h.amenities}.toList()..sort();

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
      child: Text(
        text.toUpperCase(),
        style: context.label.copyWith(color: p.muted),
      ),
    );
    Widget count(String label, int value, ValueChanged<int> set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in [0, 1, 2, 3, 4])
              SelectChip(
                key: Key('filter-$label-$n'),
                label: n == 0 ? 'Any' : '$n+',
                selected: value == n,
                onTap: () => setState(() => set(n)),
              ),
          ],
        ),
      ],
    );
    Set<String> toggled(Set<String> set, String v) =>
        set.contains(v) ? ({...set}..remove(v)) : {...set, v};

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Segmented<ListingKind?>(
                  values: const [null, ...ListingKind.values],
                  labelOf: (k) => k?.label ?? 'Any',
                  value: _draft.kind,
                  keyPrefix: 'filter-kind',
                  // Rents and prices are on different scales: a range set
                  // for one means nothing for the other.
                  onChanged: (k) => setState(
                    () => _draft = _draft.copyWith(
                      kind: () => k,
                      minPrice: () => null,
                      maxPrice: () => null,
                    ),
                  ),
                ),
                heading(
                  _draft.kind == ListingKind.rent ? 'Rent a month' : 'Price',
                ),
                Text(
                  '${formatMoney(from.round(), currency)} to ${formatMoney(to.round(), currency)}${to >= hi ? ' or more' : ''}',
                  style: context.title,
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
                  child: RangeSlider(
                    key: FilterKeys.price,
                    values: RangeValues(from, to),
                    min: lo.toDouble(),
                    max: hi.toDouble(),
                    divisions: ((hi - lo) / step).round().clamp(1, 400),
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(
                        minPrice: () => v.start <= lo ? null : v.start.round(),
                        maxPrice: () => v.end >= hi ? null : v.end.round(),
                      ),
                    ),
                  ),
                ),
                count(
                  'Bedrooms',
                  _draft.minBeds,
                  (n) => _draft = _draft.copyWith(minBeds: n),
                ),
                count(
                  'Bathrooms',
                  _draft.minBaths,
                  (n) => _draft = _draft.copyWith(minBaths: n),
                ),
                heading('Kind of home'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in types)
                      SelectChip(
                        key: Key('filter-type-$t'),
                        label: t,
                        selected: _draft.types.contains(t),
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(
                            types: toggled(_draft.types, t),
                          ),
                        ),
                      ),
                  ],
                ),
                heading('Must have'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in amenities)
                      SelectChip(
                        key: Key('filter-amenity-$a'),
                        label: a,
                        icon: amenityIcon(a),
                        selected: _draft.amenities.contains(a),
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(
                            amenities: toggled(_draft.amenities, a),
                          ),
                        ),
                      ),
                  ],
                ),
                heading('Sort by'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in HomeSort.values)
                      SelectChip(
                        label: s.label,
                        selected: _draft.sort == s,
                        onTap: () =>
                            setState(() => _draft = _draft.copyWith(sort: s)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xl),
              ],
            ),
          ),
        ),
        // Pinned: the button is never below the fold of a long sheet.
        Container(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.md,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: PrimaryButton(
                  key: FilterKeys.reset,
                  quiet: true,
                  label: 'Reset',
                  onPressed: () => setState(
                    () => _draft = HomeFilter(
                      query: _draft.query,
                      kind: _draft.kind,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: PrimaryButton(
                  key: FilterKeys.apply,
                  label: matches == 0
                      ? 'No homes match'
                      : matches == 1
                      ? 'Show 1 home'
                      : 'Show $matches homes',
                  onPressed: () {
                    ref.read(searchFilterProvider.notifier).state = _draft;
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
