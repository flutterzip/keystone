import 'dart:ui';

import 'home.dart';

/// The stylised city the map draws: water, parks and streets on a unit
/// square, with the bounds that place a coordinate on it.
class CityMap {
  const CityMap({
    required this.north,
    required this.south,
    required this.west,
    required this.east,
    required this.water,
    required this.parks,
    required this.avenues,
    required this.streets,
    required this.areas,
    required this.waterName,
  });

  final double north, south, west, east;
  final List<Offset> water;
  final List<List<Offset>> parks;
  final List<List<Offset>> avenues;
  final List<List<Offset>> streets;

  /// The neighbourhoods, by name.
  final List<({String name, GeoPoint at})> areas;
  final String waterName;

  /// Where [p] falls on the unit square (x east, y south).
  Offset project(GeoPoint p) =>
      Offset((p.lng - west) / (east - west), (north - p.lat) / (north - south));

  GeoPoint? areaNamed(String name) {
    for (final a in areas) {
      if (a.name == name) return a.at;
    }
    return null;
  }

  factory CityMap.fromJson(Map<String, dynamic> j) {
    List<Offset> line(dynamic l) => [
      for (final p in l as List)
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
    List<List<Offset>> lines(String k) => [
      for (final l in j[k] as List) line(l),
    ];
    final b = j['bounds'] as Map<String, dynamic>;
    double n(String k) => (b[k] as num).toDouble();
    return CityMap(
      north: n('north'),
      south: n('south'),
      west: n('west'),
      east: n('east'),
      water: line(j['water']),
      parks: lines('parks'),
      avenues: lines('avenues'),
      streets: lines('streets'),
      areas: [
        for (final a in (j['areas'] as List).cast<Map<String, dynamic>>())
          (name: a['name'] as String, at: GeoPoint.fromJson(a)),
      ],
      waterName: j['waterName'] as String? ?? '',
    );
  }
}
