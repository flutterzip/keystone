import '../config/app_timing.dart';
import '../models/ids.dart';
import '../models/viewing.dart';
import 'seed.dart';
import 'store.dart';

/// The time was taken between being shown and being booked.
class SlotTaken implements Exception {
  const SlotTaken(this.reason);
  final String reason;
}

abstract interface class ViewingRepository {
  /// Soonest first.
  Future<List<Viewing>> viewings();

  /// The times on [day] for [homeId]. [ignoring] leaves one of the person's
  /// own viewings out of the clash check, for rescheduling it.
  Future<List<Slot>> slots(String homeId, DateTime day, {String? ignoring});

  Future<Viewing> book(String homeId, DateTime at, ViewingMode mode);
  Future<Viewing> reschedule(String id, DateTime at);
  Future<Viewing> cancel(String id);

  /// Undoes a cancel.
  Future<Viewing> restore(String id);
}

/// Viewings on this device: the seeded ones, dated from first launch, plus
/// whatever has been booked since.
class DemoViewingRepository implements ViewingRepository {
  DemoViewingRepository(
    Seed seed,
    Store store, {
    required DateTime firstLaunch,
    required this.clock,
    Duration? latency,
  }) : _latency = latency,
       _list = StoredList(
         store,
         Store.viewings,
         seed: () => [
           for (final j in seed.rows('viewings'))
             Viewing.fromJson(j, stamp: firstLaunch),
         ],
         decode: Viewing.fromJson,
         encode: (v) => v.toJson(),
       );

  final StoredList<Viewing> _list;
  final DateTime Function() clock;
  final Duration? _latency;

  /// Hours and minutes of each time offered in a day.
  static const times = [
    (9, 0), (9, 45), (10, 30), (11, 15), (12, 0), (14, 0), //
    (14, 45), (15, 30), (16, 15), (17, 0), (17, 45),
  ];

  Future<void> _wait() => AppTiming.wait(_latency ?? AppTiming.bookViewing);

  @override
  Future<List<Viewing>> viewings() async =>
      _list.read()..sort((a, b) => a.at.compareTo(b.at));

  @override
  Future<List<Slot>> slots(
    String homeId,
    DateTime day, {
    String? ignoring,
  }) async {
    // Agents do not show homes on a Sunday.
    if (day.weekday == DateTime.sunday) return const [];
    final now = clock();
    final mine = _list.read().where(
      (v) => v.cancelledAt == null && v.id != ignoring,
    );
    return [
      for (final (i, (h, m)) in times.indexed)
        _slot(
          homeId,
          DateTime(day.year, day.month, day.day, h, m),
          i,
          now,
          mine,
        ),
    ];
  }

  Slot _slot(
    String homeId,
    DateTime at,
    int index,
    DateTime now,
    Iterable<Viewing> mine,
  ) {
    if (!at.isAfter(now)) return Slot(at, taken: 'That time has passed.');
    for (final v in mine) {
      if (v.at.difference(at).abs() < Viewing.length) {
        return Slot(
          at,
          taken: v.homeId == homeId
              ? 'You already have this viewing booked.'
              : 'You have another viewing at that time.',
        );
      }
    }
    // Other people's bookings: a fixed pattern per home and day, so the same
    // times are taken every time the page is opened.
    final seed = _pattern(homeId, at, index);
    if (seed % 10 < 3) {
      return Slot(at, taken: 'Another viewer has booked that time.');
    }
    return Slot(at);
  }

  /// A hash that is the same on every run and every device, unlike
  /// `Object.hash`.
  static int _pattern(String homeId, DateTime at, int index) {
    var h = 17;
    for (final unit in homeId.codeUnits) {
      h = (h * 31 + unit) & 0x3fffffff;
    }
    h = (h * 31 + at.year * 372 + at.month * 31 + at.day) & 0x3fffffff;
    return (h * 31 + index * 7919) & 0x3fffffff;
  }

  Future<void> _mustBeFree(
    String homeId,
    DateTime at, {
    String? ignoring,
  }) async {
    final slot = (await slots(
      homeId,
      at,
      ignoring: ignoring,
    )).where((s) => s.at == at);
    if (slot.isEmpty) throw const SlotTaken('That time is not offered.');
    if (!slot.first.free) throw SlotTaken(slot.first.taken!);
  }

  Future<Viewing> _update(String id, Viewing Function(Viewing) change) async {
    late Viewing out;
    await _list.write([
      for (final v in _list.read())
        if (v.id == id) out = change(v) else v,
    ]);
    return out;
  }

  @override
  Future<Viewing> book(String homeId, DateTime at, ViewingMode mode) async {
    await _wait();
    // Checked again at the moment of booking, not only when it was shown.
    await _mustBeFree(homeId, at);
    final v = Viewing(id: Ids.next('v'), homeId: homeId, at: at, mode: mode);
    await _list.write([..._list.read(), v]);
    return v;
  }

  @override
  Future<Viewing> reschedule(String id, DateTime at) async {
    await _wait();
    final current = _list.read().firstWhere((v) => v.id == id);
    await _mustBeFree(current.homeId, at, ignoring: id);
    return _update(id, (v) => v.copyWith(at: at));
  }

  @override
  Future<Viewing> cancel(String id) =>
      _update(id, (v) => v.copyWith(cancelledAt: clock));

  @override
  Future<Viewing> restore(String id) =>
      _update(id, (v) => v.copyWith(cancelledAt: () => null));
}

// A network implementation:
//
// class RemoteViewingRepository implements ViewingRepository {
//   RemoteViewingRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<List<Viewing>> viewings() async =>
//       [for (final j in (await _dio.get('/viewings')).data) Viewing.fromJson(j)];
//
//   @override
//   Future<Viewing> book(String homeId, DateTime at, ViewingMode mode) async {
//     final r = await _dio.post('/viewings', data: {...});
//     if (r.statusCode == 409) throw SlotTaken(r.data['message']);
//     return Viewing.fromJson(r.data);
//   }
//   ...
// }
