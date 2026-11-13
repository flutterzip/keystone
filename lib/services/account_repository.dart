import '../models/account.dart';
import '../models/application.dart';
import '../models/home.dart';
import 'seed.dart';
import 'store.dart';

/// The signed-in person's side of the app: their details, cards, shortlist,
/// saved searches and documents. Async throughout, so a backend drops in
/// without touching a widget.
abstract interface class AccountRepository {
  Future<UserProfile> profile();
  Future<UserProfile> updateProfile(UserProfile profile);

  Future<List<PaymentCard>> cards();

  /// Home ids, most recently saved first.
  Future<List<String>> savedHomes();
  Future<void> setSavedHomes(List<String> ids);

  /// Home ids, most recently opened first.
  Future<List<String>> recentlyViewed();
  Future<void> setRecentlyViewed(List<String> ids);

  Future<List<SavedSearch>> savedSearches();

  /// Adds the search, or replaces the one with the same id.
  Future<void> saveSearch(SavedSearch search, {int? at});
  Future<void> deleteSearch(String id);

  Future<List<Document>> documents();
  Future<void> saveDocument(Document document, {int? at});
  Future<void> deleteDocument(String id);
}

class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(
    this._seed,
    this._store, {
    required DateTime firstLaunch,
  }) : _searches = StoredList(
         _store,
         Store.savedSearches,
         seed: () => [
           for (final j in _seed.rows('saved_searches'))
             SavedSearch.fromJson(j),
         ],
         decode: SavedSearch.fromJson,
         encode: (s) => s.toJson(),
       ),
       _documents = StoredList(
         _store,
         Store.documents,
         seed: () => [
           for (final j in _seed.rows('documents'))
             Document.fromJson(j, stamp: firstLaunch),
         ],
         decode: Document.fromJson,
         encode: (d) => d.toJson(),
       );

  final Seed _seed;
  final Store _store;
  final StoredList<SavedSearch> _searches;
  final StoredList<Document> _documents;

  @override
  Future<UserProfile> profile() async {
    final saved = _store.json<Map<String, dynamic>>(Store.profile);
    return saved == null ? _seed.profile : UserProfile.fromJson(saved);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _store.setJson(Store.profile, profile.toJson());
    return profile;
  }

  @override
  Future<List<PaymentCard>> cards() async => [
    for (final j in _seed.rows('cards')) PaymentCard.fromJson(j),
  ];

  @override
  Future<List<String>> savedHomes() async =>
      _store.strings(Store.saved) ?? _seed.saved;

  @override
  Future<void> setSavedHomes(List<String> ids) =>
      _store.setStrings(Store.saved, ids);

  @override
  Future<List<String>> recentlyViewed() async =>
      _store.strings(Store.recent) ?? _seed.recentlyViewed;

  @override
  Future<void> setRecentlyViewed(List<String> ids) =>
      _store.setStrings(Store.recent, ids);

  static List<T> _put<T>(
    List<T> list,
    T item,
    bool Function(T) same, {
    int? at,
  }) {
    if (list.any(same)) return [for (final x in list) same(x) ? item : x];
    return [...list]..insert((at ?? list.length).clamp(0, list.length), item);
  }

  @override
  Future<List<SavedSearch>> savedSearches() async => _searches.read();

  @override
  Future<void> saveSearch(SavedSearch search, {int? at}) => _searches.write(
    _put(_searches.read(), search, (s) => s.id == search.id, at: at),
  );

  @override
  Future<void> deleteSearch(String id) => _searches.write([
    for (final s in _searches.read())
      if (s.id != id) s,
  ]);

  @override
  Future<List<Document>> documents() async => _documents.read();

  @override
  Future<void> saveDocument(Document document, {int? at}) => _documents.write(
    _put(_documents.read(), document, (d) => d.id == document.id, at: at),
  );

  @override
  Future<void> deleteDocument(String id) => _documents.write([
    for (final d in _documents.read())
      if (d.id != id) d,
  ]);
}

// A network implementation. The JSON shapes match the seed files, so every
// model's fromJson is reused as it is: nothing else in the app changes.
//
// class RemoteAccountRepository implements AccountRepository {
//   RemoteAccountRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<UserProfile> profile() async =>
//       UserProfile.fromJson((await _dio.get('/me')).data);
//
//   @override
//   Future<void> setSavedHomes(List<String> ids) =>
//       _dio.put('/me/saved', data: ids);
//
//   // A real document is uploaded as a file; MediaStore is the place for that.
//   ...
// }
