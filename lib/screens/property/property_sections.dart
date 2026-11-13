import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/home.dart';
import '../../providers/activity_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/city_map_view.dart';
import '../../widgets/common.dart';
import '../../widgets/floor_plan.dart';
import '../../widgets/home_card.dart';
import '../../widgets/photo.dart';
import '../../widgets/pressable.dart';
import '../actions.dart';

/// A section heading inside the property page.
class PropertySection extends StatelessWidget {
  const PropertySection({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xxl, bottom: Space.md),
    child: KeyedSubtree(
      key: actionKey,
      child: SectionTitle(title, action: action, onAction: onAction),
    ),
  );
}

/// Tags, price, name and address.
class PropertyHeadline extends StatelessWidget {
  const PropertyHeadline({super.key, required this.home, required this.now});

  final Home home;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tag(home.isRent ? 'To rent' : 'For sale', accent: false),
              if (home.isNew(now)) ...[
                const SizedBox(width: 6),
                const Tag('New'),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  home.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          PriceText(home, size: 30),
          const SizedBox(height: 4),
          Text(home.title, style: context.display.copyWith(fontSize: 23)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: p.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${home.address}, ${home.area}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.body,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Beds, baths, area and year as four cells of one card.
class KeyFacts extends StatelessWidget {
  const KeyFacts({super.key, required this.home});

  final Home home;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final facts = [
      (Icons.bed_outlined, '${home.beds}', home.beds == 1 ? 'Bed' : 'Beds'),
      (
        Icons.bathtub_outlined,
        '${home.baths}',
        home.baths == 1 ? 'Bath' : 'Baths',
      ),
      (Icons.straighten_rounded, '${home.sqm}', 'm²'),
      (Icons.calendar_today_outlined, '${home.yearBuilt}', 'Built'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, (icon, value, label)) in facts.indexed) ...[
              if (i > 0) VerticalDivider(width: 1, color: p.line),
              Expanded(
                child: Semantics(
                  label: '$value $label',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Icon(icon, size: 19, color: p.accentInk),
                      const SizedBox(height: 7),
                      Text(
                        value,
                        maxLines: 1,
                        style: context.title.copyWith(
                          fontSize: 16,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(label, maxLines: 1, style: context.caption),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _amenityIcons = {
  'Garden': Icons.yard_outlined,
  'Pool': Icons.pool_rounded,
  'Parking': Icons.local_parking_rounded,
  'Terrace': Icons.deck_outlined,
  'Lift': Icons.elevator_outlined,
  'Air conditioning': Icons.ac_unit_rounded,
  'Fireplace': Icons.fireplace_outlined,
  'Furnished': Icons.chair_outlined,
  'Pets welcome': Icons.pets_rounded,
  'River view': Icons.water_rounded,
  'Storage': Icons.inventory_2_outlined,
  'Concierge': Icons.room_service_outlined,
};

IconData amenityIcon(String name) =>
    _amenityIcons[name] ?? Icons.check_circle_outline_rounded;

class Amenities extends StatelessWidget {
  const Amenities({super.key, required this.home});

  final Home home;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in home.amenities)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: p.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(amenityIcon(a), size: 16, color: p.accentInk),
                  const SizedBox(width: 7),
                  Text(a, style: context.title.copyWith(fontSize: 13.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The floor plan on a card, drawn on as [drawn] runs.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.planKey,
    required this.home,
    required this.drawn,
  });

  final GlobalKey planKey;
  final Home home;
  final Animation<double> drawn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      key: planKey,
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MAIN FLOOR',
                  style: context.label.copyWith(color: p.muted),
                ),
              ),
              Text(
                '${FloorPlan.areaOf(home.rooms)} m² of ${home.sqm} m²',
                style: context.caption,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: drawn,
              builder: (context, _) =>
                  FloorPlan(rooms: home.rooms, drawn: drawn.value),
            ),
          ),
        ],
      ),
    );
  }
}

/// The home on the drawn map.
class MapCard extends ConsumerWidget {
  const MapCard({super.key, required this.home});

  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final map = ref.watch(cityMapProvider).valueOrNull;
    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      decoration: BoxDecoration(
        color: p.mapLand,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: map == null
          ? null
          : Semantics(
              image: true,
              label: 'Map: ${home.address}, ${home.area}',
              child: CityMapView(
                map: map,
                focus: home.at,
                zoom: 3.4,
                dot: home.at,
              ),
            ),
    );
  }
}

class AgentCard extends StatelessWidget {
  const AgentCard({super.key, required this.agent, required this.home});

  final Agent agent;
  final Home home;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          PersonPhoto(photo: agent.photo, name: agent.name, size: 52),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title.copyWith(fontSize: 16),
                ),
                Text(
                  agent.agency,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption,
                ),
                const SizedBox(height: 3),
                Text(
                  'Usually replies in ${agent.replyMinutes} min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption.copyWith(color: p.positive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the conversation with the home's agent, starting one if needed.
class MessageAgentButton extends ConsumerWidget {
  const MessageAgentButton({
    super.key,
    required this.agent,
    required this.home,
  });

  final Agent agent;
  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Pressable(
      semanticLabel: 'Message ${agent.firstName}',
      haptic: true,
      onTap: () async {
        final thread = await ref
            .read(threadsProvider.notifier)
            .open(agent.id, homeId: home.id);
        if (context.mounted) openThread(context, thread.id);
      },
      child: Container(
        width: Sizes.buttonHeight,
        height: Sizes.buttonHeight,
        decoration: BoxDecoration(
          color: p.card,
          shape: BoxShape.circle,
          border: Border.all(color: p.line),
        ),
        child: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: p.ink),
      ),
    );
  }
}

/// The way into applying, shown once the home has been viewed: or where
/// the application has got to, once there is one.
class ApplyStrip extends StatelessWidget {
  const ApplyStrip({
    super.key,
    required this.home,
    required this.onTap,
    this.status,
  });

  final Home home;

  /// The application's status, when one exists.
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final what = home.isRent ? 'application' : 'offer';
    return Pressable(
      onTap: onTap,
      scale: .98,
      semanticLabel: status == null
          ? 'You have viewed this home. ${home.isRent ? 'Apply to rent it' : 'Make an offer'}'
          : 'Your $what: $status',
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: p.accentWash,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.assignment_outlined, size: 21, color: p.accentInk),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == null
                        ? (home.isRent ? 'Apply to rent it' : 'Make an offer')
                        : 'Your $what',
                    style: context.title,
                  ),
                  Text(
                    status ?? 'You have viewed this home.',
                    style: context.caption.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.ink),
          ],
        ),
      ),
    );
  }
}
