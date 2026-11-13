import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/kit/kit.dart';
import 'package:keystone/app.dart';
import 'package:keystone/config/app_brand.dart';
import 'package:keystone/config/app_timing.dart';
import 'package:keystone/config/launch_hooks.dart';
import 'package:keystone/models/viewing.dart';
import 'package:keystone/providers/activity_providers.dart';
import 'package:keystone/providers/browse_providers.dart';
import 'package:keystone/providers/core_providers.dart';
import 'package:keystone/screens/auth/auth_screen.dart';
import 'package:keystone/screens/booking/book_viewing_screen.dart';
import 'package:keystone/screens/home/home_tab.dart';
import 'package:keystone/screens/messages/messages_screen.dart';
import 'package:keystone/screens/onboarding/onboarding_screen.dart';
import 'package:keystone/screens/profile/profile_tab.dart';
import 'package:keystone/screens/property/property_screen.dart';
import 'package:keystone/screens/saved/saved_tab.dart';
import 'package:keystone/screens/shell/main_shell.dart';
import 'package:keystone/screens/splash/splash_overlay.dart';
import 'package:keystone/screens/viewings/viewings_tab.dart';
import 'package:keystone/services/store.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester t, ProviderContainer c) async {
  await warm(c);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: KeystoneApp(),
      ),
    ),
  );
}

/// Steps past the splash in frames: one long pump would run its timeline,
/// its awaits and the first screen's entrance only once.
Future<void> pumpPastSplash(WidgetTester t) async {
  final frames = AppTiming.splashTotal.inMilliseconds ~/ 50 + 12;
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder tab(String label) => find.descendant(
  of: find.byType(LiquidGlassTabBar),
  matching: find.text(label),
);

void main() {
  final seed = readSeed();
  setUp(quietMotion);
  tearDown(() => AppTiming.scale = 0);

  group('first screen', () {
    testWidgets('a first launch opens on onboarding', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('once onboarded, it opens on sign in', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, prefs: {Store.onboarded: '1'});
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('a remembered session opens on Home', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(HomeTab), findsOneWidget);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    });
  });

  group('splash', () {
    testWidgets('plays over a blank page, then hands over without a remount', (
      t,
    ) async {
      phone(t);
      AppTiming.scale = 1;
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashOverlay), findsOneWidget);
      expect(find.byType(HomeTab), findsNothing);
      // The tagline sits on its own Material: no debug underline.
      final style = DefaultTextStyle.of(
        t.element(find.text(AppBrand.tagline)),
      ).style;
      expect(style.decoration, isNot(TextDecoration.underline));

      // Step until the first screen is mounted under the leaving splash.
      for (
        var i = 0;
        i < 90 && c.read(splashPhaseProvider) != SplashPhase.leaving;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(c.read(splashPhaseProvider), SplashPhase.leaving);
      final during = t.state(find.byType(MainShell));
      await pumpPastSplash(t);
      expect(c.read(splashPhaseProvider), SplashPhase.done);
      expect(find.byType(SplashOverlay), findsNothing);
      // The same State before and after: the first screen was not rebuilt
      // from scratch, so its entrance cannot have played twice.
      expect(identical(t.state(find.byType(MainShell)), during), isTrue);
    });
  });

  group('shell', () {
    testWidgets('tabs switch and Messages opens inside the tab', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      await t.tap(tab('Saved'));
      await t.pumpAndSettle();
      expect(c.read(shellTabProvider), ShellTab.saved);
      expect(find.byType(SavedTab), findsOneWidget);
      await t.tap(tab('Viewings'));
      await t.pumpAndSettle();
      expect(find.byType(ViewingsTab), findsOneWidget);
      await t.tap(tab('You'));
      await t.pumpAndSettle();
      expect(find.byType(ProfileTab), findsOneWidget);

      // One seeded thread is unread, and the badge says so.
      expect(
        find.descendant(
          of: find.byKey(const Key('messages-badge')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byIcon(Icons.chat_bubble_outline_rounded).last);
      await t.pumpAndSettle();
      expect(find.byType(MessagesScreen), findsOneWidget);
      // The bar is still there: the page opened inside the tab.
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    });

    testWidgets('the journey: open a home, save it, book a viewing', (t) async {
      phone(t, size: const Size(390, 1500));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();

      await t.tap(find.text('Ourique Garden Flat').first);
      await t.pumpAndSettle();
      expect(find.byType(PropertyScreen), findsOneWidget);
      expect(c.read(recentProvider).value!.first, 'ourique');

      expect(c.read(savedIdsProvider), isNot(contains('ourique')));
      await t.tap(find.byKey(const Key('save-ourique')).last);
      await t.pumpAndSettle();
      expect(c.read(savedIdsProvider).first, 'ourique');

      await t.tap(find.byKey(PropertyKeys.book));
      await t.pumpAndSettle();
      expect(find.byType(BookViewingScreen), findsOneWidget);
      // Tomorrow, the first time that is free.
      await t.tap(find.byKey(BookingKeys.day(1)));
      await t.pumpAndSettle();
      final slots = await (await c.read(
        viewingRepositoryProvider.future,
      )).slots('ourique', testNow.add(const Duration(days: 1)));
      final free = slots.firstWhere((s) => s.free);
      await tapVisible(t, find.byKey(BookingKeys.slot(free.at)));
      await t.tap(find.byKey(BookingKeys.confirm));
      await t.pumpAndSettle();
      expect(find.text('Viewing booked'), findsOneWidget);
      final booked = c
          .read(viewingsProvider)
          .value!
          .where((v) => v.homeId == 'ourique' && v.at == free.at);
      expect(booked.single.status(testNow), ViewingStatus.upcoming);

      await t.tap(find.byKey(BookingKeys.done));
      await t.pumpAndSettle();
      expect(c.read(shellTabProvider), ShellTab.viewings);
      expect(find.byType(ViewingsTab), findsOneWidget);
    });
  });

  group('the source', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('no em dashes in anything a person can read', () {
      for (final f in [
        ...sources,
        ...Directory('assets/data').listSync().whereType<File>(),
      ]) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue;
          expect(line.contains('—'), isFalse, reason: '${f.path}:${i + 1}');
        }
      }
    });

    test('launch hooks are off unless asked for', () {
      expect(LaunchHooks.start, isEmpty);
      expect(
        File('lib/config/launch_hooks.dart').readAsStringSync(),
        contains("defaultValue: ''"),
      );
    });

    test('colours are defined in the palette and nowhere else', () {
      final allowed = {
        'lib/config/palette.dart',
        // Apple's and Google's marks are fixed by their guidelines.
        'lib/widgets/social_buttons.dart',
      };
      final literal = RegExp(r'Color\(0x|Color\.from|Colors\.(?!transparent)');
      for (final f in sources) {
        if (allowed.contains(f.path)) continue;
        // The copied-in components: they take the app's colours as arguments
        // and only keep neutral defaults of their own.
        if (f.path.startsWith('lib/kit/')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          expect(
            literal.hasMatch(lines[i]),
            isFalse,
            reason: '${f.path}:${i + 1} ${lines[i].trim()}',
          );
        }
      }
    });

    test('no source file is longer than 500 lines', () {
      for (final f in sources) {
        expect(
          f.readAsLinesSync().length,
          lessThanOrEqualTo(500),
          reason: f.path,
        );
      }
    });
  });
}
