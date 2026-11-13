import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/home.dart';
import '../../models/money.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/photo.dart';
import '../../widgets/pressable.dart';
import '../actions.dart';

/// Two homes side by side, line by line. Where one is plainly ahead on a
/// line (cheaper, bigger, more rooms) it is marked, in words as well as
/// weight.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key, required this.a, required this.b});

  final String a;
  final String b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final ha = ref.watch(homeProvider(a));
    final hb = ref.watch(homeProvider(b));
    if (ha == null || hb == null) {
      return const SubPage(
        title: 'Compare',
        child: Center(
          child: EmptyState(
            title: 'One of these has gone',
            message: 'A home you chose has left the market.',
          ),
        ),
      );
    }
    final sameKind = ha.kind == hb.kind;
    int perSqm(Home h) => (h.price.amount / h.sqm).round();
    final amenities = {...ha.amenities, ...hb.amenities}.toList()..sort();

    // -1 when a is ahead, 1 when b is, 0 when level or not comparable.
    int lead(num x, num y, {bool lowerWins = false}) =>
        x == y ? 0 : ((x < y) == lowerWins ? -1 : 1);

    return SubPage(
      title: 'Compare',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.lg,
          Space.gutter,
          media.padding.bottom + Sizes.tabBarReserve,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Head(home: ha)),
              const SizedBox(width: Space.md),
              Expanded(child: _Head(home: hb)),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (!sameKind)
            const Padding(
              padding: EdgeInsets.only(bottom: Space.md),
              child: Notice(
                'One is to rent and one is for sale, so prices are not compared.',
              ),
            ),
          _Line(
            'Price',
            ha.priceText,
            hb.priceText,
            lead: sameKind
                ? lead(ha.price.amount, hb.price.amount, lowerWins: true)
                : 0,
          ),
          _Line(
            'Per m²',
            formatMoney(perSqm(ha), ha.price.currency),
            formatMoney(perSqm(hb), hb.price.currency),
            lead: sameKind ? lead(perSqm(ha), perSqm(hb), lowerWins: true) : 0,
          ),
          _Line(
            'Bedrooms',
            '${ha.beds}',
            '${hb.beds}',
            lead: lead(ha.beds, hb.beds),
          ),
          _Line(
            'Bathrooms',
            '${ha.baths}',
            '${hb.baths}',
            lead: lead(ha.baths, hb.baths),
          ),
          _Line(
            'Floor area',
            '${ha.sqm} m²',
            '${hb.sqm} m²',
            lead: lead(ha.sqm, hb.sqm),
          ),
          _Line('Kind', ha.type, hb.type),
          _Line('Built', '${ha.yearBuilt}', '${hb.yearBuilt}'),
          _Line('Area', ha.area, hb.area),
          const SizedBox(height: Space.lg),
          Text('AMENITIES', style: context.label.copyWith(color: p.muted)),
          const SizedBox(height: Space.sm),
          for (final am in amenities)
            _Line(
              am,
              ha.amenities.contains(am) ? 'Yes' : 'No',
              hb.amenities.contains(am) ? 'Yes' : 'No',
              dimNo: true,
            ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => openHome(context, home),
    scale: .98,
    semanticLabel: home.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: HomePhoto(home.cover, decodeWidth: 220),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          home.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.title,
        ),
        PriceText(home, size: 14),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.a, this.b, {this.lead = 0, this.dimNo = false});

  final String label;
  final String a;
  final String b;
  final int lead;

  /// Sets a "No" quieter than a "Yes".
  final bool dimNo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget cell(String v, bool ahead) => Expanded(
      child: Row(
        children: [
          Flexible(
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.title.copyWith(
                fontWeight: ahead ? FontWeight.w700 : FontWeight.w500,
                color: dimNo && v == 'No' ? p.muted : p.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (ahead) ...[
            const SizedBox(width: 5),
            Icon(Icons.arrow_upward_rounded, size: 14, color: p.positive),
          ],
        ],
      ),
    );
    return Semantics(
      label:
          '$label: $a${lead < 0 ? ', better' : ''} against $b${lead > 0 ? ', better' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.caption),
            const SizedBox(height: 3),
            Row(
              children: [
                cell(a, lead < 0),
                const SizedBox(width: Space.md),
                cell(b, lead > 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
