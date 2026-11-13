import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keystone/kit/kit.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/format.dart';
import '../../models/home.dart';
import '../../models/viewing.dart';
import '../../providers/activity_providers.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/home_card.dart';
import '../../widgets/photo.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/save_flight.dart';
import '../actions.dart';
import '../home/home_sections.dart';
import 'calculator.dart';
import 'property_sections.dart';

abstract final class PropertyKeys {
  static const book = Key('property-book');
  static const message = Key('property-message');
  static const brochure = Key('property-brochure');
  static const apply = Key('property-apply');
  static const photos = Key('property-photos');
  static const plan = Key('property-plan');
}

/// A home: its photographs full width, then everything a person needs to
/// decide, with "Book a viewing" pinned at the foot.
class PropertyScreen extends ConsumerStatefulWidget {
  const PropertyScreen({super.key, required this.homeId, this.scope = 'page'});

  final String homeId;

  /// The list the home was opened from; its card's photo flies in.
  final String scope;

  @override
  ConsumerState<PropertyScreen> createState() => _PropertyScreenState();
}

class _PropertyScreenState extends ConsumerState<PropertyScreen>
    with SingleTickerProviderStateMixin {
  static const _photoHeight = 400.0;

  final _scroll = ScrollController();
  final _photos = PageController();
  final _photoKey = GlobalKey();
  final _planKey = GlobalKey();
  final _photo = ValueNotifier<int>(0);

  /// Draws the floor plan the first time it scrolls into view.
  late final AnimationController _plan;

  @override
  void initState() {
    super.initState();
    _plan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scroll.addListener(_maybeDrawPlan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentProvider.notifier).viewed(widget.homeId);
      if (Motion.reduced(context)) _plan.value = 1;
      _maybeDrawPlan();
    });
  }

  void _maybeDrawPlan() {
    if (_plan.value > 0 || _plan.isAnimating) return;
    final box = _planKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * .78) _plan.forward();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _photos.dispose();
    _photo.dispose();
    _plan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final home = ref.watch(homeProvider(widget.homeId));
    if (home == null) {
      return const SubPage(
        title: 'Home',
        child: Center(
          child: EmptyState(
            icon: Icons.home_outlined,
            title: 'This home has left the market',
            message: 'It may have been let or sold since you saved it.',
          ),
        ),
      );
    }
    final now = ref.watch(nowProvider);
    final agent = ref.watch(agentProvider(home.agentId));
    final viewings = [
      for (final v
          in ref.watch(viewingsProvider).valueOrNull ?? const <Viewing>[])
        if (v.homeId == home.id && v.cancelledAt == null) v,
    ];
    final next = viewings.where((v) => v.status(now) != ViewingStatus.past);
    final viewed = viewings.any((v) => v.status(now) == ViewingStatus.past);
    final application = ref.watch(applicationForHomeProvider(home.id));
    final similar =
        [
          for (final h
              in ref.watch(homesProvider).valueOrNull ?? const <Home>[])
            if (h.kind == home.kind && h.id != home.id) h,
        ]..sort(
          (a, b) => (a.price.amount - home.price.amount).abs().compareTo(
            (b.price.amount - home.price.amount).abs(),
          ),
        );
    final barBottom = media.padding.bottom + Sizes.tabBarReserve - 14;

    final gallery = PageView.builder(
      key: PropertyKeys.photos,
      controller: _photos,
      itemCount: home.photos.length,
      onPageChanged: (i) => _photo.value = i,
      itemBuilder: (context, i) {
        final photo = GestureDetector(
          onTap: () => openGallery(context, home, at: i),
          child: HomePhoto(home.photos[i], decodeWidth: media.size.width),
        );
        // Only the cover flies in from the card.
        return i == 0
            ? Hero(
                tag: homeHeroTag(home, widget.scope),
                child: KeyedSubtree(key: _photoKey, child: photo),
              )
            : photo;
      },
    );

    return Material(
      color: p.paper,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                // One sliver: a viewport paints later slivers first, and the
                // sheet must paint over the photograph's foot.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _photoHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Water rings through the photograph under a touch:
                          // the one loud effect on this page.
                          Motion.loops(context)
                              ? RippleSurface(amplitude: 9, child: gallery)
                              : gallery,
                          Positioned(
                            right: Space.lg,
                            bottom: 40,
                            child: IgnorePointer(
                              child: ValueListenableBuilder<int>(
                                valueListenable: _photo,
                                builder: (context, i, _) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.photoScrim,
                                    borderRadius: BorderRadius.circular(
                                      Radii.pill,
                                    ),
                                  ),
                                  child: Text(
                                    '${i + 1} / ${home.photos.length}',
                                    style: context.caption.copyWith(
                                      color: p.onPhoto,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The details are a sheet of paper laid over the photo's foot.
                    Transform.translate(
                      offset: const Offset(0, -26),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.paper,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Radii.xl + 4),
                          ),
                        ),
                        padding: const EdgeInsets.only(top: Space.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PropertyHeadline(home: home, now: now),
                            if (next.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.gutter,
                                  Space.lg,
                                  Space.gutter,
                                  0,
                                ),
                                child: Notice(
                                  'Your viewing is ${inSentence(whenLabel(next.first.at, now))}.',
                                  icon: Icons.event_available_rounded,
                                ),
                              ),
                            if (application != null || viewed)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.gutter,
                                  Space.lg,
                                  Space.gutter,
                                  0,
                                ),
                                child: ApplyStrip(
                                  key: PropertyKeys.apply,
                                  home: home,
                                  status: application?.statusLabel(now),
                                  onTap: () => openApplication(context, home),
                                ),
                              ),
                            const SizedBox(height: Space.xl),
                            KeyFacts(home: home),
                            const PropertySection(title: 'About this home'),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.gutter,
                              ),
                              child: Text(
                                home.description,
                                style: context.body.copyWith(fontSize: 15),
                              ),
                            ),
                            const PropertySection(title: 'Amenities'),
                            Amenities(home: home),
                            PropertySection(
                              title: 'Floor plan',
                              action: 'Brochure',
                              actionKey: PropertyKeys.brochure,
                              onAction: () => openBrochure(context, home),
                            ),
                            PlanCard(
                              key: PropertyKeys.plan,
                              planKey: _planKey,
                              home: home,
                              drawn: _plan,
                            ),
                            const PropertySection(title: 'Where it is'),
                            MapCard(home: home),
                            if (agent != null) ...[
                              const PropertySection(title: 'Shown by'),
                              AgentCard(agent: agent, home: home),
                            ],
                            PropertySection(
                              title: home.isRent
                                  ? 'Can you afford the rent?'
                                  : 'What would it cost a month?',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.gutter,
                              ),
                              child: home.isRent
                                  ? RentCalculator(home: home)
                                  : MortgageCalculator(home: home),
                            ),
                            if (similar.isNotEmpty) ...[
                              const SizedBox(height: Space.xxl),
                              HomeRail(
                                title: 'Similar homes',
                                scope: 'similar-${home.id}',
                                homes: similar.take(4).toList(),
                                compact: true,
                              ),
                            ],
                            SizedBox(height: barBottom + Sizes.buttonHeight),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Back and save float over the photograph.
          Positioned(
            top: media.padding.top + 4,
            left: 8,
            right: 8,
            child: Row(
              children: [
                RoundIcon(
                  icon: Icons.arrow_back_ios_new_rounded,
                  label: 'Back',
                  filled: true,
                  size: 16,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                SaveButton(home: home, from: _photoKey),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: barBottom + Sizes.buttonHeight + 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .32],
                    colors: [p.paper.withValues(alpha: 0), p.paper],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: Space.gutter,
            right: Space.gutter,
            bottom: barBottom,
            child: Row(
              children: [
                if (agent != null) ...[
                  MessageAgentButton(
                    key: PropertyKeys.message,
                    agent: agent,
                    home: home,
                  ),
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: Builder(
                    builder: (button) => PrimaryButton(
                      key: PropertyKeys.book,
                      label: 'Book a viewing',
                      icon: Icons.event_rounded,
                      onPressed: () {
                        final box = button.findRenderObject() as RenderBox;
                        openBooking(
                          context,
                          home,
                          origin: box.localToGlobal(
                            box.size.center(Offset.zero),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
