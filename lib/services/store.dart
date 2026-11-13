import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User state on top of the seed: the session, saved homes, viewings,
/// messages, applications and the rest.
///
/// A thin wrapper so every key is named in one place. Reads are synchronous
/// (the instance is loaded before `runApp`), so screens never flash empty
/// state on launch. Not secure storage: no secrets go here.
class Store {
  Store(this._prefs);

  final SharedPreferences _prefs;

  /// Who is signed in: just their email. Never the profile itself.
  static const session = 'session';
  static const profile = 'profile';
  static const onboarded = 'onboarded';
  static const themeMode = 'theme_mode';

  /// When the seed's relative times were turned into dates: first launch,
  /// or the last reset.
  static const seedStamp = 'seed_stamp';
  static const listingKind = 'listing_kind';
  static const area = 'area';
  static const saved = 'saved';
  static const recent = 'recent';
  static const viewings = 'viewings';
  static const threads = 'threads';
  static const applications = 'applications';
  static const savedSearches = 'saved_searches';
  static const documents = 'documents';

  static const all = [
    session,
    profile,
    onboarded,
    themeMode,
    seedStamp,
    listingKind,
    area,
    saved,
    recent,
    viewings,
    threads,
    applications,
    savedSearches,
    documents,
  ];

  String? string(String key) => _prefs.getString(key);

  Future<void> setString(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);

  T? json<T>(String key) {
    final s = _prefs.getString(key);
    return s == null ? null : jsonDecode(s) as T;
  }

  Future<void> setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  List<String>? strings(String key) => _prefs.getStringList(key);

  Future<void> setStrings(String key, Iterable<String> v) =>
      _prefs.setStringList(key, v.toList());

  /// Back to a first launch: the seed shows through again.
  Future<void> reset() async {
    for (final k in all) {
      await _prefs.remove(k);
    }
  }
}

/// A list that starts as the seed's and becomes the person's own the first
/// time it is changed.
class StoredList<T> {
  StoredList(
    this._store,
    this._key, {
    required List<T> Function() seed,
    required T Function(Map<String, dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  }) : _seed = seed,
       _decode = decode,
       _encode = encode;

  final Store _store;
  final String _key;
  final List<T> Function() _seed;
  final T Function(Map<String, dynamic>) _decode;
  final Map<String, dynamic> Function(T) _encode;

  List<T> read() {
    final saved = _store.json<List<dynamic>>(_key);
    if (saved == null) return _seed();
    return [for (final j in saved) _decode(j as Map<String, dynamic>)];
  }

  Future<void> write(List<T> items) =>
      _store.setJson(_key, [for (final i in items) _encode(i)]);
}
