import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/application.dart';
import '../models/home.dart';
import '../services/account_repository.dart';
import '../services/store.dart';
import 'core_providers.dart';

/// Rent or Buy, remembered.
class ListingKindNotifier extends Notifier<ListingKind> {
  @override
  ListingKind build() =>
      ListingKind.values.asNameMap()[ref
          .watch(storeProvider)
          .string(Store.listingKind)] ??
      ListingKind.rent;

  Future<void> set(ListingKind kind) async {
    state = kind;
    await ref.read(storeProvider).setString(Store.listingKind, kind.name);
  }
}

final listingKindProvider = NotifierProvider<ListingKindNotifier, ListingKind>(
  ListingKindNotifier.new,
);

/// The neighbourhood the person is looking around, or null for the whole
/// city.
class AreaNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(storeProvider).string(Store.area);

  Future<void> set(String? area) async {
    state = area;
    await ref.read(storeProvider).setString(Store.area, area);
  }
}

final areaProvider = NotifierProvider<AreaNotifier, String?>(AreaNotifier.new);

/// Homes of the chosen kind, in the order the market sends them.
final kindHomesProvider = Provider<List<Home>>((ref) {
  final kind = ref.watch(listingKindProvider);
  return [
    for (final h in ref.watch(homesProvider).valueOrNull ?? const <Home>[])
      if (h.kind == kind) h,
  ];
});

/// The chosen kind's homes, nearest first: to the chosen neighbourhood, or
/// to the middle of the city when none is chosen.
final nearbyHomesProvider = Provider<List<Home>>((ref) {
  final map = ref.watch(cityMapProvider).valueOrNull;
  final homes = [...ref.watch(kindHomesProvider)];
  if (map == null) return homes;
  final area = ref.watch(areaProvider);
  final from =
      (area == null ? null : map.areaNamed(area)) ??
      GeoPoint((map.north + map.south) / 2, (map.west + map.east) / 2);
  return homes..sort((a, b) => a.at.kmTo(from).compareTo(b.at.kmTo(from)));
});

/// A list of home ids kept through the account repository.
abstract class _IdsNotifier extends AsyncNotifier<List<String>> {
  Future<List<String>> _read(AccountRepository repo);
  Future<void> _write(AccountRepository repo, List<String> ids);

  Future<AccountRepository> get _repo =>
      ref.read(accountRepositoryProvider.future);

  @override
  Future<List<String>> build() async =>
      _read(await ref.watch(accountRepositoryProvider.future));

  Future<void> _set(List<String> next) async {
    state = AsyncData(next);
    await _write(await _repo, next);
  }

  List<String> get _now => state.valueOrNull ?? const [];
}

/// The shortlist, most recently saved first.
class SavedNotifier extends _IdsNotifier {
  @override
  Future<List<String>> _read(AccountRepository r) => r.savedHomes();
  @override
  Future<void> _write(AccountRepository r, List<String> ids) =>
      r.setSavedHomes(ids);

  Future<void> add(String id) async {
    if (!_now.contains(id)) await _set([id, ..._now]);
  }

  Future<void> remove(String id) => _set([..._now]..remove(id));

  /// Puts a removed home back where it was.
  Future<void> restore(String id, int index) async {
    if (_now.contains(id)) return;
    await _set([..._now]..insert(index.clamp(0, _now.length), id));
  }
}

final savedProvider = AsyncNotifierProvider<SavedNotifier, List<String>>(
  SavedNotifier.new,
);

final savedIdsProvider = Provider<List<String>>(
  (ref) => ref.watch(savedProvider).valueOrNull ?? const [],
);

final isSavedProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(savedIdsProvider).contains(id),
);

/// Homes opened lately, newest first, at most eight.
class RecentNotifier extends _IdsNotifier {
  @override
  Future<List<String>> _read(AccountRepository r) => r.recentlyViewed();
  @override
  Future<void> _write(AccountRepository r, List<String> ids) =>
      r.setRecentlyViewed(ids);

  Future<void> viewed(String id) async {
    if (_now.isNotEmpty && _now.first == id) return;
    await _set([id, ..._now.where((x) => x != id)].take(8).toList());
  }

  Future<void> clear() => _set(const []);
}

final recentProvider = AsyncNotifierProvider<RecentNotifier, List<String>>(
  RecentNotifier.new,
);

/// Resolves ids to homes, dropping any that have left the market.
List<Home> homesById(List<Home> all, List<String> ids) => [
  for (final id in ids)
    for (final h in all)
      if (h.id == id) h,
];

/// What Search is asking for right now.
final searchFilterProvider = StateProvider<HomeFilter>(
  (ref) => HomeFilter(kind: ref.read(listingKindProvider)),
);

final searchResultsProvider = Provider<List<Home>>(
  (ref) => ref
      .watch(searchFilterProvider)
      .apply(ref.watch(homesProvider).valueOrNull ?? const []),
);

class SavedSearchesNotifier extends AsyncNotifier<List<SavedSearch>> {
  @override
  Future<List<SavedSearch>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).savedSearches();

  Future<void> _after(Future<void> Function(AccountRepository) change) async {
    final repo = await ref.read(accountRepositoryProvider.future);
    await change(repo);
    state = AsyncData(await repo.savedSearches());
  }

  Future<void> save(SavedSearch s, {int? at}) =>
      _after((r) => r.saveSearch(s, at: at));
  Future<void> remove(String id) => _after((r) => r.deleteSearch(id));
}

final savedSearchesProvider =
    AsyncNotifierProvider<SavedSearchesNotifier, List<SavedSearch>>(
      SavedSearchesNotifier.new,
    );

class DocumentsNotifier extends AsyncNotifier<List<Document>> {
  @override
  Future<List<Document>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).documents();

  Future<void> _after(Future<void> Function(AccountRepository) change) async {
    final repo = await ref.read(accountRepositoryProvider.future);
    await change(repo);
    state = AsyncData(await repo.documents());
  }

  Future<void> save(Document d, {int? at}) =>
      _after((r) => r.saveDocument(d, at: at));
  Future<void> remove(String id) => _after((r) => r.deleteDocument(id));
}

final documentsProvider =
    AsyncNotifierProvider<DocumentsNotifier, List<Document>>(
      DocumentsNotifier.new,
    );
