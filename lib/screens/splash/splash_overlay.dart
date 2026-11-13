import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/motion.dart';
import '../../providers/core_providers.dart';
import '../../widgets/ambient.dart';
import '../../widgets/keystone_mark.dart';

/// `intro`: the splash plays over a blank page. `warming`: the first screen
/// is mounted underneath, hidden, so its heavy first build happens while the
/// wordmark holds; its entrance waits. `leaving`: the splash opens and the
/// first screen's entrance plays. `done`: the splash is gone.
enum SplashPhase { intro, warming, leaving, done }

final splashPhaseProvider = StateProvider<SplashPhase>(
  (_) => AppTiming.scale == 0 ? SplashPhase.done : SplashPhase.intro,
);

/// The opening shot: the arch builds itself stone by stone, the brass
/// keystone drops in and locks it, the name settles underneath. Then the
/// camera walks through the doorway: the arch grows until its opening is
/// the whole screen, and the first page is what was on the other side.
///
/// One controller in, one out. It leaves only when the intro has played
/// *and* the homes have loaded, so it never opens onto a half-loaded
/// screen. With reduced motion (and in tests) it dissolves instead.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key});

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _out;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: AppTiming.splashIn);
    _out = AnimationController(vsync: this, duration: AppTiming.splashOut);
    _run();
  }

  Future<void> _run() async {
    // The homes, through their repository: with a backend this is the first
    // network call, and the splash covers it.
    final ready = ref.read(homesProvider.future);
    _in.addListener(_lock);
    await _in.forward();
    await ready;
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.warming;
    await AppTiming.wait(AppTiming.splashHold);
    for (var i = 0; i < 2; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.leaving;
    await _out.forward();
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.done;
  }

  /// A tap of haptics as the keystone lands.
  void _lock() {
    if (!_locked && _in.value > _SplashFace.markUntil * KeystoneMark.locksAt) {
      _locked = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walk = Motion.loops(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, _) => IgnorePointer(
        ignoring: _out.value > .4,
        child: walk
            ? _SplashFace(t: _in.value, leave: _out.value)
            : Opacity(
                opacity: 1 - Curves.easeInCubic.transform(_out.value),
                child: const _SplashFace(t: 1),
              ),
      ),
    );
  }
}

/// What the splash shows at [t] (0 to 1) of its way in, and at [leave]
/// (0 to 1) of its way through the door.
class _SplashFace extends StatelessWidget {
  const _SplashFace({required this.t, this.leave = 0});

  final double t;
  final double leave;

  /// The share of the way in that the arch takes to build.
  static const markUntil = .68;
  static const _markSize = 104.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    double slice(double from, double to) =>
        ((t - from) / (to - from)).clamp(0.0, 1.0);
    final built = slice(0, markUntil);
    // The arch takes the keystone's weight: a small dip as it lands.
    final land = slice(markUntil * KeystoneMark.locksAt, markUntil + .1);
    final dip = math.sin(land * math.pi) * 3;
    final word = Curves.easeOutQuart.transform(slice(.5, .92));
    final rule = Curves.easeInOutCubic.transform(slice(.62, .94));
    final tagline = Curves.easeOut.transform(slice(.78, 1));

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final mark = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * .41),
          width: _markSize,
          height: _markSize,
        );
        // Walking through: everything grows about the middle of the doorway
        // until the opening is wider than the screen.
        final door = MarkGeometry.door(mark);
        final focus = door.getBounds().center;
        final reach = math.max(
          size.width / door.getBounds().width,
          size.height / door.getBounds().height,
        );
        final zoom = math.exp(
          math.log(reach * 2.4) * Curves.easeInCubic.transform(leave),
        );
        final through = Matrix4.identity()
          ..translateByDouble(focus.dx, focus.dy, 0, 1)
          ..scaleByDouble(zoom, zoom, 1, 1)
          ..translateByDouble(-focus.dx, -focus.dy, 0, 1);
        final fade = (1 - (leave - .55) / .3).clamp(0.0, 1.0);

        // A Material, not a bare box: the splash sits above the Navigator,
        // where no Scaffold gives text a default style.
        Widget face = Material(
          color: p.paper,
          child: Stack(
            children: [
              const Positioned.fill(child: AmbientMesh()),
              Transform(
                transform: through,
                child: Opacity(
                  opacity: fade,
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: mark.shift(Offset(0, dip)),
                        child: KeystoneMark(size: _markSize, built: built),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: mark.bottom + 22,
                        child: Column(
                          children: [
                            Opacity(
                              opacity: word,
                              child: Wordmark(size: 27, settle: word),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: 132 * rule,
                              height: 1.2,
                              color: p.accent,
                            ),
                            const SizedBox(height: 16),
                            Opacity(
                              opacity: tagline,
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - tagline)),
                                child: Text(
                                  AppBrand.tagline,
                                  textAlign: TextAlign.center,
                                  style: context.body.copyWith(
                                    color: p.inkSoft,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        if (leave > 0) {
          face = ClipPath(
            clipper: _DoorClipper(door.transform(through.storage)),
            child: face,
          );
        }
        return face;
      },
    );
  }
}

/// Everything but the doorway.
class _DoorClipper extends CustomClipper<Path> {
  const _DoorClipper(this.door);

  final Path door;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    door,
  );

  @override
  bool shouldReclip(_DoorClipper old) => true;
}

/// Starts [start] when the splash begins to leave (or at once if it already
/// has), so a first screen mounted early does not play its entrance unseen.
void startWhenRevealed(WidgetRef ref, VoidCallback start) {
  final phase = ref.read(splashPhaseProvider);
  if (phase == SplashPhase.leaving || phase == SplashPhase.done) {
    start();
    return;
  }
  late final ProviderSubscription<SplashPhase> sub;
  sub = ref.listenManual(splashPhaseProvider, (_, next) {
    if (next == SplashPhase.leaving || next == SplashPhase.done) {
      sub.close();
      start();
    }
  });
}
