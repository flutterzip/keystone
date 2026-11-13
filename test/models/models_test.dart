import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/models/application.dart';
import 'package:keystone/models/format.dart';
import 'package:keystone/models/home.dart';
import 'package:keystone/models/money.dart';
import 'package:keystone/models/thread.dart';
import 'package:keystone/models/viewing.dart';
import 'package:keystone/screens/property/calculator.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  final homes = [
    for (final j in seed.rows('homes')) Home.fromJson(j, stamp: testNow),
  ];

  group('money', () {
    test('is text in one place, from minor units', () {
      expect(formatMoney(290000, 'EUR'), '€2,900');
      expect(formatMoney(118000000, 'EUR'), '€1,180,000');
      expect(formatMoney(1250, 'EUR'), '€12.50');
      expect(formatMoney(-500, 'USD'), r'-$5');
      expect(formatMoney(245000000, 'EUR', compact: true), '€2.45M');
      expect(formatMoney(320000000, 'EUR', compact: true), '€3.2M');
      expect(formatMoney(290000, 'EUR', compact: true), '€2,900');
      expect(formatMoney(89000000, 'GBP', compact: true), '£890K');
    });

    test('a rent says it is monthly, a price does not', () {
      expect(
        homes.firstWhere((h) => h.id == 'loft').priceText,
        '€2,900 a month',
      );
      expect(homes.firstWhere((h) => h.id == 'belem').priceText, '€1,180,000');
    });

    test('a repayment follows the annuity formula', () {
      // 944,000 over 30 years at 3.6%: 4,291.86 a month.
      expect(monthlyRepayment(94400000, 3.6, 30), closeTo(429186, 60));
      expect(monthlyRepayment(1200000, 0, 10), 10000);
    });
  });

  group('filter', () {
    test('an empty filter matches every home', () {
      expect(const HomeFilter().apply(homes).length, homes.length);
      expect(const HomeFilter().count, 0);
    });

    test('every word of the text must match', () {
      const f = HomeFilter(query: 'garden belém');
      expect(f.apply(homes).map((h) => h.id), ['belem']);
    });

    test('kind, beds, price, type and amenities all narrow it', () {
      const f = HomeFilter(
        kind: ListingKind.sale,
        minBeds: 4,
        maxPrice: 300000000,
        types: {'House'},
        amenities: {'Garden', 'Fireplace'},
      );
      expect(f.count, 4);
      expect(f.apply(homes).map((h) => h.id).toSet(), {'jacaranda', 'restelo'});
    });

    test('sorts by price both ways', () {
      const low = HomeFilter(kind: ListingKind.rent, sort: HomeSort.priceLow);
      expect(low.apply(homes).first.id, 'alfama');
      expect(
        low.copyWith(sort: HomeSort.priceHigh).apply(homes).first.id,
        'chiado',
      );
    });

    test('survives a round trip, and says what it is', () {
      const f = HomeFilter(
        kind: ListingKind.rent,
        minBeds: 2,
        maxPrice: 300000,
      );
      final back = HomeFilter.fromJson(f.toJson());
      expect(back.kind, ListingKind.rent);
      expect(back.maxPrice, 300000);
      expect(back.summary('EUR'), 'Rent, 2+ beds, up to €3,000');
      expect(f.copyWith(maxPrice: () => null).maxPrice, isNull);
    });
  });

  group('viewing', () {
    final v = Viewing(
      id: 'v',
      homeId: 'loft',
      at: testNow.add(const Duration(hours: 3)),
      mode: ViewingMode.inPerson,
    );

    test('its status is worked out from the clock', () {
      expect(v.status(testNow), ViewingStatus.upcoming);
      expect(
        v.status(testNow.add(const Duration(hours: 2, minutes: 1))),
        ViewingStatus.soon,
      );
      expect(
        v.status(testNow.add(const Duration(hours: 3, minutes: 10))),
        ViewingStatus.soon,
      );
      expect(
        v.status(testNow.add(const Duration(hours: 3, minutes: 30))),
        ViewingStatus.past,
      );
      expect(
        v.copyWith(cancelledAt: () => testNow).status(testNow),
        ViewingStatus.cancelled,
      );
    });

    test('says when in plain words', () {
      expect(whenLabel(v.at, testNow), 'Today at 13:00');
      expect(untilLabel(v.at, testNow), 'in 3 h');
      expect(
        untilLabel(testNow.add(const Duration(minutes: 38)), testNow),
        'in 38 min',
      );
      expect(
        dayLabel(testNow.add(const Duration(days: 3)), testNow),
        'Sat 14 Nov',
      );
    });
  });

  test('unread is any message from the agent since the thread was read', () {
    final threads = [
      for (final j in seed.rows('threads'))
        MessageThread.fromJson(j, stamp: testNow),
    ];
    expect(threads.firstWhere((t) => t.id == 't-ines').unread, 1);
    expect(threads.firstWhere((t) => t.id == 't-tomas').unread, 0);
    final read = threads.first.copyWith(readAt: testNow);
    expect(read.unread, 0);
    expect(MessageThread.fromJson(read.toJson()).messages.length, 4);
  });

  group('application', () {
    final a = Application(
      id: 'a',
      homeId: 'chiado',
      kind: ApplicationKind.application,
      submittedAt: testNow,
    );

    test('moves from sent to review to approved with the clock', () {
      expect(a.statusLabel(testNow), 'Sent');
      expect(
        a.statusLabel(testNow.add(const Duration(hours: 3))),
        'Under review',
      );
      final later = testNow.add(const Duration(days: 2, minutes: 1));
      expect(a.statusLabel(later), 'Approved');
      expect(a.depositDue(later), isTrue);
      expect(a.depositDue(testNow), isFalse);
    });

    test('a paid deposit closes that step and dates the contract', () {
      final later = testNow.add(const Duration(days: 3));
      final paid = a.copyWith(
        depositPaidAt: later,
        depositCard: 'Visa ending 4242',
      );
      expect(paid.depositDue(later), isFalse);
      expect(paid.statusLabel(later), 'Deposit paid');
      final stages = paid.stages(later);
      expect(stages.map((s) => s.done), [true, true, true, true, false]);
      expect(stages[3].note, contains('Visa ending 4242'));
      expect(
        Application.fromJson(paid.toJson()).depositCard,
        'Visa ending 4242',
      );
    });

    test('a withdrawn one is neither approved nor due', () {
      final later = testNow.add(const Duration(days: 5));
      final gone = a.copyWith(withdrawnAt: () => later);
      expect(gone.statusLabel(later), 'Withdrawn');
      expect(gone.depositDue(later), isFalse);
    });

    test('a new document is checked before it is verified', () {
      final d = Document(
        id: 'd',
        name: 'ID',
        kind: 'Identity',
        addedAt: testNow,
      );
      expect(d.verified(testNow.add(const Duration(minutes: 30))), isFalse);
      expect(d.verified(testNow.add(const Duration(hours: 1))), isTrue);
    });
  });
}
