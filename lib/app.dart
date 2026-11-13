import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_brand.dart';
import 'config/app_theme.dart';
import 'config/app_timing.dart';
import 'config/launch_hooks.dart';
import 'config/touch_dots.dart';
import 'providers/session_providers.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/shell/main_shell.dart';
import 'screens/splash/splash_overlay.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class KeystoneApp extends ConsumerStatefulWidget {
  const KeystoneApp({super.key});

  @override
  ConsumerState<KeystoneApp> createState() => _KeystoneAppState();
}

class _KeystoneAppState extends ConsumerState<KeystoneApp> {
  final _appKey = GlobalKey(debugLabel: 'app');

  @override
  void initState() {
    super.initState();
    // Launch hooks open their page only once the splash has gone: a route
    // pushed on the first frame lands on top of the splash or under it.
    void go() => WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null || !mounted) return;
      LaunchHooks.run(context, ProviderScope.containerOf(context));
    });
    if (ref.read(splashPhaseProvider) == SplashPhase.done) {
      go();
    } else {
      ref.listenManual(splashPhaseProvider, (previous, next) {
        if (next == SplashPhase.done && previous != SplashPhase.done) go();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(splashPhaseProvider);
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const StartGate(),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        // The Stack keeps one shape for the app's whole life: the app is
        // always its keyed first child and only the splash sibling goes.
        // Returning `child` bare once the splash ends would remount the
        // first screen and replay its entrance.
        final app = AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                KeyedSubtree(key: _appKey, child: child!),
                if (phase != SplashPhase.done) const SplashOverlay(),
              ],
            ),
          ),
        );
        return LaunchHooks.showTouches ? TouchDots(child: app) : app;
      },
    );
  }
}

/// The first route. Blank until the splash has the homes, so the first
/// screen's own entrance plays while the splash dissolves rather than
/// unseen behind it.
class StartGate extends ConsumerWidget {
  const StartGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(splashPhaseProvider);
    if (phase == SplashPhase.intro && AppTiming.scale > 0) {
      return ColoredBox(color: context.palette.paper);
    }
    // Read once: signing in or out later navigates explicitly.
    if (ref.read(sessionProvider) != null) return const MainShell();
    if (!ref.read(onboardedProvider)) return const OnboardingScreen();
    return const AuthScreen();
  }
}

/// A page handing over to another: a plain cross-fade, long enough for the
/// new page's entrance to start inside it.
Route<T> handOffRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 700),
  reverseTransitionDuration: const Duration(milliseconds: 400),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    child: child,
  ),
);
