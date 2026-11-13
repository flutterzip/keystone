import '../config/app_timing.dart';
import '../models/account.dart';
import '../models/application.dart';
import '../models/home.dart';
import '../models/ids.dart';
import '../models/money.dart';
import 'seed.dart';
import 'store.dart';

/// The card was refused. Nothing is charged and the deposit stays due.
class PaymentDeclined implements Exception {
  const PaymentDeclined();
}

/// What the form hands over to be sent.
class ApplicationDraft {
  const ApplicationDraft({
    required this.home,
    this.offer,
    this.moveIn,
    this.note = '',
  });

  final Home home;
  final Money? offer;
  final DateTime? moveIn;
  final String note;
}

abstract interface class ApplicationRepository {
  /// Newest first.
  Future<List<Application>> applications();
  Future<Application> submit(ApplicationDraft draft);

  /// What holding [home] costs: a week's rent, or the reservation fee.
  Future<Money> holdingDeposit(Home home);

  /// Takes the deposit. Throws [PaymentDeclined] when the card is refused.
  Future<Application> payDeposit(String id, PaymentCard card);
  Future<Application> withdraw(String id);

  /// Undoes a withdrawal.
  Future<Application> restore(String id);
}

class DemoApplicationRepository implements ApplicationRepository {
  DemoApplicationRepository(
    this._seed,
    Store store, {
    required DateTime firstLaunch,
    required this.clock,
    Duration? latency,
  }) : _latency = latency,
       _list = StoredList(
         store,
         Store.applications,
         seed: () => [
           for (final j in _seed.rows('applications'))
             Application.fromJson(j, stamp: firstLaunch),
         ],
         decode: Application.fromJson,
         encode: (a) => a.toJson(),
       );

  final Seed _seed;
  final StoredList<Application> _list;
  final DateTime Function() clock;
  final Duration? _latency;

  @override
  Future<List<Application>> applications() async =>
      _list.read()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

  Future<Application> _update(
    String id,
    Application Function(Application) change,
  ) async {
    late Application out;
    await _list.write([
      for (final a in _list.read())
        if (a.id == id) out = change(a) else a,
    ]);
    return out;
  }

  @override
  Future<Application> submit(ApplicationDraft d) async {
    await AppTiming.wait(_latency ?? AppTiming.submitApplication);
    final a = Application(
      id: Ids.next('a'),
      homeId: d.home.id,
      kind: d.home.isRent ? ApplicationKind.application : ApplicationKind.offer,
      submittedAt: clock(),
      offer: d.offer,
      moveIn: d.moveIn,
      note: d.note.trim(),
    );
    await _list.write([a, ..._list.read()]);
    return a;
  }

  @override
  Future<Money> holdingDeposit(Home home) async {
    if (!home.isRent) return _seed.reservationFee;
    // A week's rent, to the whole unit.
    final week = (home.price.amount * 12 / 52 / 100).round() * 100;
    return home.price.copyWith(amount: week);
  }

  @override
  Future<Application> payDeposit(String id, PaymentCard card) async {
    await AppTiming.wait(_latency ?? AppTiming.payment);
    // A real app hands the card token to its payment provider here.
    if (card.last4 == _seed.decliningCardLast4) throw const PaymentDeclined();
    return _update(
      id,
      (a) => a.copyWith(depositPaidAt: clock(), depositCard: card.masked),
    );
  }

  @override
  Future<Application> withdraw(String id) =>
      _update(id, (a) => a.copyWith(withdrawnAt: clock));

  @override
  Future<Application> restore(String id) =>
      _update(id, (a) => a.copyWith(withdrawnAt: () => null));
}

// A network implementation:
//
// class RemoteApplicationRepository implements ApplicationRepository {
//   RemoteApplicationRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<Application> payDeposit(String id, PaymentCard card) async {
//     final r = await _dio.post('/applications/$id/deposit', data: {'card': card.id});
//     if (r.statusCode == 402) throw const PaymentDeclined();
//     return Application.fromJson(r.data);
//   }
//   ...
// }
