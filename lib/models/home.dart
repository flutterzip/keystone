import 'dart:math' as math;

import 'money.dart';

enum ListingKind {
  rent('Rent'),
  sale('Buy');

  const ListingKind(this.label);
  final String label;
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Kilometres to [other]. Flat-earth maths, which is exact enough inside
  /// one city.
  double kmTo(GeoPoint other) {
    const perDegree = 111.32;
    final dy = (lat - other.lat) * perDegree;
    final dx = (lng - other.lng) * perDegree * math.cos(lat * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }

  factory GeoPoint.fromJson(Map<String, dynamic> j) =>
      GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
}

/// One room of the floor plan, in metres from the plan's top left corner.
class Room {
  const Room(this.name, this.x, this.y, this.w, this.h);

  final String name;
  final double x, y, w, h;

  double get sqm => w * h;

  factory Room.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num).toDouble();
    return Room(j['name'] as String, n('x'), n('y'), n('w'), n('h'));
  }
}

class Home {
  const Home({
    required this.id,
    required this.title,
    required this.address,
    required this.area,
    required this.at,
    required this.price,
    required this.kind,
    required this.beds,
    required this.baths,
    required this.sqm,
    required this.type,
    required this.yearBuilt,
    required this.listedAt,
    required this.featured,
    required this.amenities,
    required this.photos,
    required this.description,
    required this.rooms,
    required this.agentId,
  });

  final String id;
  final String title;
  final String address;

  /// The neighbourhood.
  final String area;
  final GeoPoint at;

  /// The asking price, or the rent for one month.
  final Money price;
  final ListingKind kind;
  final int beds;
  final int baths;
  final int sqm;
  final String type;
  final int yearBuilt;
  final DateTime listedAt;
  final bool featured;
  final List<String> amenities;

  /// Media references, the first being the cover.
  final List<String> photos;
  final String description;
  final List<Room> rooms;
  final String agentId;

  bool get isRent => kind == ListingKind.rent;
  String get cover => photos.first;

  /// "€2,900 a month" or "€1,180,000".
  String get priceText => isRent ? '${price.text} a month' : price.text;

  String get facts => '$beds bed, $baths bath, $sqm m²';

  bool isNew(DateTime now) => now.difference(listedAt).inDays < 7;

  /// [stamp] turns the seed's `listedDaysAgo` into a date; an API sends
  /// `listedAt` and needs none.
  factory Home.fromJson(Map<String, dynamic> j, {DateTime? stamp}) => Home(
    id: j['id'] as String,
    title: j['title'] as String,
    address: j['address'] as String,
    area: j['area'] as String,
    at: GeoPoint.fromJson(j['coordinates'] as Map<String, dynamic>),
    price: Money.fromJson(j['price'] as Map<String, dynamic>),
    kind: ListingKind.values.byName(j['listing'] as String),
    beds: j['beds'] as int,
    baths: j['baths'] as int,
    sqm: j['areaSqm'] as int,
    type: j['type'] as String,
    yearBuilt: j['yearBuilt'] as int,
    listedAt: j['listedAt'] != null
        ? DateTime.parse(j['listedAt'] as String)
        : (stamp ?? DateTime.now()).subtract(
            Duration(days: j['listedDaysAgo'] as int? ?? 0),
          ),
    featured: j['featured'] as bool? ?? false,
    amenities: (j['amenities'] as List).cast<String>(),
    photos: (j['photos'] as List).cast<String>(),
    description: j['description'] as String,
    rooms: [
      for (final r in j['rooms'] as List)
        Room.fromJson(r as Map<String, dynamic>),
    ],
    agentId: j['agentId'] as String,
  );
}

class Agent {
  const Agent({
    required this.id,
    required this.name,
    required this.agency,
    required this.phone,
    required this.email,
    required this.photo,
    required this.replyMinutes,
  });

  final String id;
  final String name;
  final String agency;
  final String phone;
  final String email;
  final String photo;

  /// How long they usually take to answer.
  final int replyMinutes;

  String get firstName => name.split(' ').first;

  factory Agent.fromJson(Map<String, dynamic> j) => Agent(
    id: j['id'] as String,
    name: j['name'] as String,
    agency: j['agency'] as String,
    phone: j['phone'] as String,
    email: j['email'] as String,
    photo: j['photo'] as String,
    replyMinutes: j['replyMinutes'] as int? ?? 30,
  );
}

enum HomeSort {
  newest('Newest'),
  priceLow('Price, low to high'),
  priceHigh('Price, high to low'),
  largest('Largest');

  const HomeSort(this.label);
  final String label;
}

/// What a search asks for. Everything is optional; an empty filter matches
/// every home.
class HomeFilter {
  const HomeFilter({
    this.query = '',
    this.kind,
    this.minPrice,
    this.maxPrice,
    this.minBeds = 0,
    this.minBaths = 0,
    this.types = const {},
    this.amenities = const {},
    this.sort = HomeSort.newest,
  });

  final String query;
  final ListingKind? kind;

  /// Minor units, in the listings' currency.
  final int? minPrice;
  final int? maxPrice;
  final int minBeds;
  final int minBaths;
  final Set<String> types;
  final Set<String> amenities;
  final HomeSort sort;

  /// How many of the sheet's filters are set (not the text or the sort).
  int get count =>
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (minBeds > 0 ? 1 : 0) +
      (minBaths > 0 ? 1 : 0) +
      (types.isNotEmpty ? 1 : 0) +
      (amenities.isNotEmpty ? 1 : 0);

  bool matches(Home h) {
    if (kind != null && h.kind != kind) return false;
    if (minPrice != null && h.price.amount < minPrice!) return false;
    if (maxPrice != null && h.price.amount > maxPrice!) return false;
    if (h.beds < minBeds || h.baths < minBaths) return false;
    if (types.isNotEmpty && !types.contains(h.type)) return false;
    if (!amenities.every(h.amenities.contains)) return false;
    final words = query.toLowerCase().split(RegExp(r'\s+'));
    final hay =
        '${h.title} ${h.area} ${h.address} ${h.type} ${h.amenities.join(' ')}'
            .toLowerCase();
    return words.every(hay.contains);
  }

  List<Home> apply(Iterable<Home> homes) {
    final out = homes.where(matches).toList();
    switch (sort) {
      case HomeSort.newest:
        out.sort((a, b) => b.listedAt.compareTo(a.listedAt));
      case HomeSort.priceLow:
        out.sort((a, b) => a.price.amount.compareTo(b.price.amount));
      case HomeSort.priceHigh:
        out.sort((a, b) => b.price.amount.compareTo(a.price.amount));
      case HomeSort.largest:
        out.sort((a, b) => b.sqm.compareTo(a.sqm));
    }
    return out;
  }

  /// A sentence for a saved search: "Rent, 2+ beds, up to €3,000".
  String summary(String currency) {
    final parts = <String>[
      if (kind != null) kind!.label,
      if (query.trim().isNotEmpty) '"${query.trim()}"',
      if (minBeds > 0) '$minBeds+ beds',
      if (minBaths > 0) '$minBaths+ baths',
      if (minPrice != null) 'from ${formatMoney(minPrice!, currency)}',
      if (maxPrice != null) 'up to ${formatMoney(maxPrice!, currency)}',
      ...types,
      ...amenities,
    ];
    return parts.isEmpty ? 'Every home' : parts.join(', ');
  }

  // A function so a field can be set back to null.
  HomeFilter copyWith({
    String? query,
    ListingKind? Function()? kind,
    int? Function()? minPrice,
    int? Function()? maxPrice,
    int? minBeds,
    int? minBaths,
    Set<String>? types,
    Set<String>? amenities,
    HomeSort? sort,
  }) => HomeFilter(
    query: query ?? this.query,
    kind: kind == null ? this.kind : kind(),
    minPrice: minPrice == null ? this.minPrice : minPrice(),
    maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
    minBeds: minBeds ?? this.minBeds,
    minBaths: minBaths ?? this.minBaths,
    types: types ?? this.types,
    amenities: amenities ?? this.amenities,
    sort: sort ?? this.sort,
  );

  factory HomeFilter.fromJson(Map<String, dynamic> j) => HomeFilter(
    query: j['query'] as String? ?? '',
    kind: ListingKind.values.asNameMap()[j['listing']],
    minPrice: j['minPrice'] as int?,
    maxPrice: j['maxPrice'] as int?,
    minBeds: j['minBeds'] as int? ?? 0,
    minBaths: j['minBaths'] as int? ?? 0,
    types: {...(j['types'] as List? ?? const []).cast<String>()},
    amenities: {...(j['amenities'] as List? ?? const []).cast<String>()},
  );

  Map<String, dynamic> toJson() => {
    'query': query,
    'listing': kind?.name,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'minBeds': minBeds,
    'minBaths': minBaths,
    'types': types.toList(),
    'amenities': amenities.toList(),
  };
}

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filter,
    required this.alerts,
  });

  final String id;
  final String name;
  final HomeFilter filter;

  /// Whether new matches send a notification.
  final bool alerts;

  SavedSearch copyWith({String? name, bool? alerts}) => SavedSearch(
    id: id,
    name: name ?? this.name,
    filter: filter,
    alerts: alerts ?? this.alerts,
  );

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
    id: j['id'] as String,
    name: j['name'] as String,
    filter: HomeFilter.fromJson(j['filter'] as Map<String, dynamic>),
    alerts: j['alerts'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'alerts': alerts,
    'filter': filter.toJson(),
  };
}
