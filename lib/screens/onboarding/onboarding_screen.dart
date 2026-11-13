import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/city_map.dart';
import '../../models/home.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/ambient.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_screen.dart';
import 'onboarding_art.dart';

/// Three slides: search your way, book viewings, sign from your phone. The
/// art on each is made of the app's own parts and the seeded homes, and it
/// builds on from how far the slide has been dragged, so it follows the
/// finger and reverses with it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const slides = [
    (
      title: 'Search your way',
      body:
          'By area, by price, by what a home must have. See the results as '
          'a list, or as pins on the map.',
    ),
    (
      title: 'Book viewings in a tap',
      body:
          'Pick a day and a time that is free, in person or by video call, '
          'and get a countdown when it is close.',
    ),
    (
      title: 'Sign from your phone',
      body:
          'Apply or make an offer, pay the holding deposit and follow every '
          'step to the contract, all in one place.',
    ),
  ];

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _first = 0;
  final _pages = PageController(initialPage: _first);
  // Seeded from the same constant as the controller: a mirror that starts
  // elsewhere would draw the first slide with no art until the first drag.
  final _page = ValueNotifier<double>(_first.toDouble());

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => _page.value = _pages.page ?? _page.value);
  }

  @override
  void dispose() {
    _pages.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.selectionClick();
    await ref.read(onboardedProvider.notifier).done();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(handOffRoute(const AuthScreen()));
  }

  void _next() {
    final at = _page.value.round();
    if (at >= OnboardingScreen.slides.length - 1) {
      _finish();
    } else {
      _pages.nextPage(duration: Motion.long, curve: Motion.settle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final homes = ref.watch(homesProvider).valueOrNull;
    final map = ref.watch(cityMapProvider).valueOrNull;
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: p.paper,
      body: AmbientMesh(
        speed: .35,
        child: Column(
          children: [
            SizedBox(height: media.padding.top + 6),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Wordmark(size: 14),
                  Positioned(
                    right: Space.md,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: p.inkSoft,
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.font,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: OnboardingScreen.slides.length,
                itemBuilder: (context, i) =>
                    _Slide(index: i, page: _page, homes: homes, map: map),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                media.padding.bottom + Space.lg,
              ),
              child: Row(
                children: [
                  _Dots(page: _page, count: OnboardingScreen.slides.length),
                  const Spacer(),
                  SizedBox(
                    width: 168,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _page,
                      builder: (context, page, _) => PrimaryButton(
                        label:
                            page.round() == OnboardingScreen.slides.length - 1
                            ? 'Get started'
                            : 'Next',
                        onPressed: _next,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.index,
    required this.page,
    required this.homes,
    required this.map,
  });

  final int index;
  final ValueNotifier<double> page;
  final List<Home>? homes;
  final CityMap? map;

  @override
  Widget build(BuildContext context) {
    final slide = OnboardingScreen.slides[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: homes == null || map == null
                ? const SizedBox.expand()
                : ValueListenableBuilder<double>(
                    valueListenable: page,
                    builder: (context, at, _) => OnboardingArt(
                      index: index,
                      // 1 when this slide is centred, 0 a full page away.
                      presence: (1 - (at - index).abs()).clamp(0.0, 1.0),
                      homes: homes!,
                      map: map!,
                    ),
                  ),
          ),
          const SizedBox(height: Space.xl),
          Text(slide.title, style: context.display),
          const SizedBox(height: Space.md),
          Text(slide.body, style: context.body.copyWith(fontSize: 15.5)),
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.count});

  final ValueNotifier<double> page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ValueListenableBuilder<double>(
      valueListenable: page,
      builder: (context, at, _) => Semantics(
        label: 'Step ${at.round() + 1} of $count',
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 7 + 17 * (1 - (at - i).abs()).clamp(0.0, 1.0),
                height: 7,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    p.ink.withValues(alpha: .22),
                    p.ink,
                    (1 - (at - i).abs()).clamp(0.0, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
