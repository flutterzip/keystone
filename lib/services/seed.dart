import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/app_brand.dart';
import '../models/account.dart';
import '../models/money.dart';

/// Everything bundled under assets/data/, decoded once.
///
/// Seed is read-only and edited by whoever uses the template; one JSON file
/// per entity, in the shape an API would send. What the user changes is
/// state, kept in [Store], never written back here. Only the Local and Demo
/// repositories read it.
class Seed {
  const Seed(this._raw);

  final Map<String, dynamic> _raw;

  static const files = [
    'homes',
    'agents',
    'map',
    'viewings',
    'threads',
    'applications',
    'saved_searches',
    'documents',
    'cards',
    'profile',
    'demo',
  ];

  /// The rows of one file. Rows with relative times ("3 days ago") are
  /// turned into dates by the repository that owns them.
  List<Map<String, dynamic>> rows(String file) =>
      (_raw[file] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> object(String file) =>
      _raw[file] as Map<String, dynamic>;

  UserProfile get profile => UserProfile.fromJson(object('profile'));
  String get demoEmail => object('demo')['demoEmail'] as String;

  /// Typing this password shows the wrong-password state; any other
  /// well-formed sign-in succeeds, so a demo never dead-ends.
  String get wrongPassword => object('demo')['wrongPassword'] as String;

  /// Paying with a card ending in these digits is declined, so the failure
  /// path can be seen.
  String get decliningCardLast4 =>
      object('demo')['decliningCardLast4'] as String;

  List<String> get saved => (object('demo')['saved'] as List).cast<String>();
  List<String> get recentlyViewed =>
      (object('demo')['recentlyViewed'] as List).cast<String>();

  /// What reserving a home for sale costs.
  Money get reservationFee =>
      Money.fromJson(object('demo')['reservationFee'] as Map<String, dynamic>);

  /// Builds a seed from raw file contents keyed by file name (no extension).
  /// `{app}` becomes the product name.
  factory Seed.fromSources(Map<String, String> raw) => Seed({
    for (final f in files)
      f: jsonDecode(raw[f]!.replaceAll('{app}', AppBrand.name)),
  });

  static Future<Seed> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final raw = <String, String>{};
    for (final f in files) {
      raw[f] = await b.loadString('assets/data/$f.json');
    }
    return Seed.fromSources(raw);
  }
}
