import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/motion.dart';
import '../models/account.dart';
import '../models/city_map.dart';
import '../models/home.dart';
import '../services/account_repository.dart';
import '../services/application_repository.dart';
import '../services/auth_repository.dart';
import '../services/listing_repository.dart';
import '../services/message_repository.dart';
import '../services/seed.dart';
import '../services/store.dart';
import '../services/viewing_repository.dart';

// ---------------------------------------------------------------------------
// The data switchboard.
//
// Every screen gets its data from one of the six repositories below, and
// nothing else in lib/ reads the seed. To connect a real backend, write the
// Remote* class sketched at the bottom of each repository file (they reuse
// every model's fromJson, because the seed files already use the API's JSON
// shapes) and return it here instead of the Local or Demo one. No widget,
// provider or model changes.
// ---------------------------------------------------------------------------

/// Overridden in `main` with the loaded instance, and in tests with one
/// backed by `SharedPreferences.setMockInitialValues`.
final storeProvider = Provider<Store>(
  (_) => throw UnimplementedError('storeProvider must be overridden'),
);

/// The bundled demo data. Only the Local and Demo repositories read it.
final seedProvider = FutureProvider<Seed>((_) => Seed.load());

/// The time, as a provider, so tests can stand at any minute.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Ticks twice a minute while the app is in use, so countdowns and anything
/// else worked out from the clock stay current. Still in tests.
final tickProvider = StreamProvider<int>((ref) {
  if (!Motion.ambient) return const Stream.empty();
  return Stream.periodic(const Duration(seconds: 30), (i) => i);
});

/// The time now, re-read on every tick.
final nowProvider = Provider<DateTime>((ref) {
  ref.watch(tickProvider);
  return ref.watch(clockProvider)();
});

/// When the seed's relative times became dates: first launch, or the last
/// reset. Seeded viewings and messages age from here and never go stale.
class SeedStampNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final store = ref.watch(storeProvider);
    final saved = int.tryParse(store.string(Store.seedStamp) ?? '');
    if (saved != null) return DateTime.fromMillisecondsSinceEpoch(saved);
    final now = ref.read(clockProvider)();
    store.setString(Store.seedStamp, '${now.millisecondsSinceEpoch}');
    return now;
  }
}

final seedStampProvider = NotifierProvider<SeedStampNotifier, DateTime>(
  SeedStampNotifier.new,
);

final listingRepositoryProvider = FutureProvider<ListingRepository>(
  (ref) async => LocalListingRepository(
    await ref.watch(seedProvider.future),
    firstLaunch: ref.watch(seedStampProvider),
  ),
);

final authRepositoryProvider = FutureProvider<AuthRepository>(
  (ref) async => DemoAuthRepository(await ref.watch(seedProvider.future)),
);

final accountRepositoryProvider = FutureProvider<AccountRepository>(
  (ref) async => LocalAccountRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
    firstLaunch: ref.watch(seedStampProvider),
  ),
);

final viewingRepositoryProvider = FutureProvider<ViewingRepository>(
  (ref) async => DemoViewingRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
    firstLaunch: ref.watch(seedStampProvider),
    clock: ref.watch(clockProvider),
  ),
);

final messageRepositoryProvider = FutureProvider<MessageRepository>(
  (ref) async => DemoMessageRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
    firstLaunch: ref.watch(seedStampProvider),
    clock: ref.watch(clockProvider),
  ),
);

final applicationRepositoryProvider = FutureProvider<ApplicationRepository>(
  (ref) async => DemoApplicationRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
    firstLaunch: ref.watch(seedStampProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Every home on the market.
final homesProvider = FutureProvider<List<Home>>(
  (ref) async => (await ref.watch(listingRepositoryProvider.future)).homes(),
);

final agentsProvider = FutureProvider<List<Agent>>(
  (ref) async => (await ref.watch(listingRepositoryProvider.future)).agents(),
);

final cityMapProvider = FutureProvider<CityMap>(
  (ref) async => (await ref.watch(listingRepositoryProvider.future)).map(),
);

final cardsProvider = FutureProvider<List<PaymentCard>>(
  (ref) async => (await ref.watch(accountRepositoryProvider.future)).cards(),
);

final homeProvider = Provider.family<Home?, String>((ref, id) {
  for (final h in ref.watch(homesProvider).valueOrNull ?? const <Home>[]) {
    if (h.id == id) return h;
  }
  return null;
});

final agentProvider = Provider.family<Agent?, String>((ref, id) {
  for (final a in ref.watch(agentsProvider).valueOrNull ?? const <Agent>[]) {
    if (a.id == id) return a;
  }
  return null;
});
