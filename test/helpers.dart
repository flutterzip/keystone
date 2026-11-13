import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keystone/config/app_theme.dart';
import 'package:keystone/config/app_timing.dart';
import 'package:keystone/config/motion.dart';
import 'package:keystone/models/account.dart';
import 'package:keystone/models/home.dart';
import 'package:keystone/providers/activity_providers.dart';
import 'package:keystone/providers/browse_providers.dart';
import 'package:keystone/providers/core_providers.dart';
import 'package:keystone/providers/session_providers.dart';
import 'package:keystone/services/seed.dart';
import 'package:keystone/services/store.dart';

/// The real seed, read from disk with dart:io. Call outside testWidgets: an
/// asset-bundle load inside the fake-async zone hangs every test after the
/// first in a file.
Seed readSeed() => Seed.fromSources({
  for (final f in Seed.files) f: File('assets/data/$f.json').readAsStringSync(),
});

/// No ambient loops (so pumpAndSettle settles) and no deliberate waits.
void quietMotion() {
  Motion.ambient = false;
  AppTiming.scale = 0;
}

/// An iPhone-sized surface. The 800x600 default hides phone layout bugs.
void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The fixed "now" every test runs at, unless it picks another.
// A Wednesday, mid-morning: slots later the same day are still bookable.
final testNow = DateTime(2026, 11, 11, 10, 0);

/// [now] is both the clock and the first-launch stamp, so seeded viewings,
/// messages and applications are exactly their seeded age.
Future<(ProviderContainer, Store)> makeContainer(
  Seed seed, {
  Map<String, Object> prefs = const {},
  UserProfile? signedIn,
  DateTime? now,
  DateTime? firstLaunch,
  List<Override> overrides = const [],
}) async {
  final clock = now ?? testNow;
  SharedPreferences.setMockInitialValues({
    'flutter.${Store.seedStamp}':
        '${(firstLaunch ?? testNow).millisecondsSinceEpoch}',
    for (final e in prefs.entries) 'flutter.${e.key}': e.value,
  });
  final store = Store(await SharedPreferences.getInstance());
  if (signedIn != null) {
    await store.setJson(Store.session, {'email': signedIn.email});
  }
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => clock),
      ...overrides,
      seedProvider.overrideWith((_) async => seed),
    ],
  );
  addTearDown(container.dispose);
  return (container, store);
}

/// Loads everything a screen may watch, so nothing first resolves during a
/// build.
Future<void> warm(ProviderContainer container) async {
  await container.read(seedProvider.future);
  await container.read(homesProvider.future);
  await container.read(agentsProvider.future);
  await container.read(cityMapProvider.future);
  await container.read(cardsProvider.future);
  await container.read(authRepositoryProvider.future);
  await container.read(savedProvider.future);
  await container.read(recentProvider.future);
  await container.read(savedSearchesProvider.future);
  await container.read(documentsProvider.future);
  await container.read(viewingsProvider.future);
  await container.read(threadsProvider.future);
  await container.read(applicationsProvider.future);
  await container.read(profileProvider.future);
}

/// Pumps [child] in a themed MaterialApp inside [container], with the
/// data already loaded. Reduce motion is on, so shader and particle
/// effects take their plain paths and everything settles.
Future<void> pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await warm(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        // Tab pages live inside the shell's Scaffold in the app; give them
        // one here so toasts have somewhere to show.
        home: Scaffold(resizeToAvoidBottomInset: false, body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Taps something that may be off screen in a list.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The seeded home with [id], once the homes have loaded.
ProviderListenable<Home> homeProviderFor(String id) =>
    homeProvider(id).select((h) => h!);
