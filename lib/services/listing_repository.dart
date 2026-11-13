import '../models/city_map.dart';
import '../models/home.dart';
import 'seed.dart';

/// The market's side of the app: homes, the agents who show them, and the
/// map they sit on. Async throughout, so a backend drops in without
/// touching a widget.
abstract interface class ListingRepository {
  Future<List<Home>> homes();
  Future<List<Agent>> agents();
  Future<CityMap> map();
}

class LocalListingRepository implements ListingRepository {
  LocalListingRepository(this._seed, {required this.firstLaunch});

  final Seed _seed;
  final DateTime firstLaunch;

  @override
  Future<List<Home>> homes() async => [
    for (final j in _seed.rows('homes')) Home.fromJson(j, stamp: firstLaunch),
  ];

  @override
  Future<List<Agent>> agents() async => [
    for (final j in _seed.rows('agents')) Agent.fromJson(j),
  ];

  @override
  Future<CityMap> map() async => CityMap.fromJson(_seed.object('map'));
}

// A network implementation. The JSON shapes match the seed files, so every
// model's fromJson is reused as it is.
//
// class RemoteListingRepository implements ListingRepository {
//   RemoteListingRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<List<Home>> homes() async =>
//       [for (final j in (await _dio.get('/homes')).data) Home.fromJson(j)];
//
//   @override
//   Future<List<Agent>> agents() async =>
//       [for (final j in (await _dio.get('/agents')).data) Agent.fromJson(j)];
//
//   // Keep the drawn map bundled, or swap CityMapView for a map SDK.
//   @override
//   Future<CityMap> map() async => CityMap.fromJson((await _dio.get('/map')).data);
// }
