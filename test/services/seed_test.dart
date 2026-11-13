import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/models/application.dart';
import 'package:keystone/models/city_map.dart';
import 'package:keystone/models/home.dart';
import 'package:keystone/models/viewing.dart';
import 'package:keystone/providers/activity_providers.dart';
import 'package:keystone/providers/browse_providers.dart';
import 'package:keystone/providers/core_providers.dart';
import 'package:keystone/services/application_repository.dart';
import 'package:keystone/services/viewing_repository.dart';
import 'package:keystone/widgets/photo.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUp(quietMotion);
  final homes = [
    for (final j in seed.rows('homes')) Home.fromJson(j, stamp: testNow),
  ];

  group('the seed makes every state reachable', () {
    test('at least eight homes, to rent and to buy, each with six photos', () {
      expect(homes.length, greaterThanOrEqualTo(8));
      expect(homes.where((h) => h.isRent).length, greaterThanOrEqualTo(3));
      expect(homes.where((h) => !h.isRent).length, greaterThanOrEqualTo(3));
      expect({for (final h in homes) h.id}.length, homes.length);
      for (final h in homes) {
        expect(h.photos.length, greaterThanOrEqualTo(6), reason: h.id);
        for (final photo in h.photos) {
          expect(File(assetPathOf(photo)).existsSync(), isTrue, reason: photo);
        }
        expect(h.rooms.length, greaterThanOrEqualTo(4), reason: h.id);
      }
    });

    test('both kinds have featured homes and something new this week', () {
      for (final kind in ListingKind.values) {
        final of = homes.where((h) => h.kind == kind);
        expect(of.where((h) => h.featured), isNotEmpty);
        expect(of.where((h) => h.isNew(testNow)), isNotEmpty);
        expect(of.where((h) => !h.isNew(testNow)), isNotEmpty);
      }
    });

    test('every home has an agent with a photo, and sits on the map', () {
      final agents = {for (final j in seed.rows('agents')) j['id']: j};
      final map = CityMap.fromJson(seed.object('map'));
      for (final h in homes) {
        expect(agents, contains(h.agentId));
        final at = map.project(h.at);
        expect(at.dx, inInclusiveRange(0, 1), reason: h.id);
        expect(at.dy, inInclusiveRange(0, 1), reason: h.id);
        expect(map.areaNamed(h.area), isNotNull, reason: h.area);
      }
      for (final a in agents.values) {
        expect(File(assetPathOf(a['photo'] as String)).existsSync(), isTrue);
      }
    });

    test('viewings: one within the hour, one ahead, past and cancelled', () {
      final statuses = [
        for (final j in seed.rows('viewings'))
          Viewing.fromJson(j, stamp: testNow).status(testNow),
      ];
      expect(statuses, containsAll(ViewingStatus.values));
    });

    test('applications: one with a deposit due, one still being read', () {
      final all = [
        for (final j in seed.rows('applications'))
          Application.fromJson(j, stamp: testNow),
      ];
      expect(all.where((a) => a.depositDue(testNow)).length, 1);
      expect(all.where((a) => a.statusLabel(testNow) == 'Sent').length, 1);
      expect(all.map((a) => a.kind).toSet(), ApplicationKind.values.toSet());
    });

    test('a card that pays and a card that declines', () {
      final last4 = [for (final j in seed.rows('cards')) j['last4']];
      expect(last4, contains(seed.decliningCardLast4));
      expect(last4.where((l) => l != seed.decliningCardLast4), isNotEmpty);
    });

    test('the demo person is the house identity', () {
      expect(seed.profile.name, 'Olympicson');
      expect(seed.demoEmail, 'hello@flutterzip.com');
      expect(File(assetPathOf(seed.profile.avatar)).existsSync(), isTrue);
      expect(seed.wrongPassword, 'wrongpass');
    });

    test('documents: one verified and one still being checked', () {
      final docs = [
        for (final j in seed.rows('documents'))
          Document.fromJson(j, stamp: testNow),
      ];
      expect(docs.where((d) => d.verified(testNow)), isNotEmpty);
      expect(docs.where((d) => !d.verified(testNow)), isNotEmpty);
    });
  });

  group('viewing repository', () {
    test('a day offers free and taken times, the same every time', () async {
      final (c, _) = await makeContainer(seed);
      final repo = await c.read(viewingRepositoryProvider.future);
      final day = testNow.add(const Duration(days: 2));
      final a = await repo.slots('alfama', day);
      final b = await repo.slots('alfama', day);
      expect(a.length, DemoViewingRepository.times.length);
      expect([for (final s in a) s.free], [for (final s in b) s.free]);
      expect(a.where((s) => s.free), isNotEmpty);
      expect(a.where((s) => !s.free), isNotEmpty);
    });

    test('there are no viewings on a Sunday, and none in the past', () async {
      final (c, _) = await makeContainer(seed);
      final repo = await c.read(viewingRepositoryProvider.future);
      // testNow is a Wednesday; four days on is a Sunday.
      expect(
        await repo.slots('alfama', testNow.add(const Duration(days: 4))),
        isEmpty,
      );
      final today = await repo.slots('alfama', testNow);
      expect(today.first.taken, 'That time has passed.');
    });

    test(
      'a time you are already busy at says so, and cannot be booked',
      () async {
        final (c, _) = await makeContainer(seed);
        final repo = await c.read(viewingRepositoryProvider.future);
        // The seeded viewing of the loft is at 10:45 today.
        final clash = (await repo.slots(
          'alfama',
          testNow,
        )).firstWhere((s) => s.at.hour == 10 && s.at.minute == 30);
        expect(clash.taken, 'You have another viewing at that time.');
        await expectLater(
          c
              .read(viewingsProvider.notifier)
              .book('alfama', clash.at, ViewingMode.video),
          throwsA(isA<SlotTaken>()),
        );
      },
    );

    test('book, reschedule, cancel and undo', () async {
      final (c, _) = await makeContainer(seed);
      final repo = await c.read(viewingRepositoryProvider.future);
      final n = c.read(viewingsProvider.notifier);
      await c.read(viewingsProvider.future);
      final day = testNow.add(const Duration(days: 1));
      final free = (await repo.slots(
        'alfama',
        day,
      )).where((s) => s.free).toList();
      final v = await n.book('alfama', free[0].at, ViewingMode.video);
      expect(c.read(viewingsProvider).value!.map((x) => x.id), contains(v.id));
      // Its own time is now taken for that home.
      final after = await repo.slots('alfama', day);
      expect(after.firstWhere((s) => s.at == v.at).free, isFalse);
      // ...but not while it is the one being moved.
      final moving = await repo.slots('alfama', day, ignoring: v.id);
      expect(moving.firstWhere((s) => s.at == v.at).free, isTrue);

      final moved = await n.reschedule(v.id, free[1].at);
      expect(moved.at, free[1].at);
      expect((await n.cancel(v.id)).status(testNow), ViewingStatus.cancelled);
      expect((await n.restore(v.id)).status(testNow), ViewingStatus.upcoming);
    });
  });

  group('applications', () {
    test('the deposit is a week of rent, or the reservation fee', () async {
      final (c, _) = await makeContainer(seed);
      final repo = await c.read(applicationRepositoryProvider.future);
      final chiado = homes.firstWhere((h) => h.id == 'chiado');
      final belem = homes.firstWhere((h) => h.id == 'belem');
      expect((await repo.holdingDeposit(chiado)).text, '€969');
      expect((await repo.holdingDeposit(belem)).text, '€2,500');
    });

    test('the declining card is refused and nothing is recorded', () async {
      final (c, _) = await makeContainer(seed);
      final cards = await c.read(cardsProvider.future);
      final n = c.read(applicationsProvider.notifier);
      await c.read(applicationsProvider.future);
      final bad = cards.firstWhere((x) => x.last4 == seed.decliningCardLast4);
      await expectLater(
        n.payDeposit('a-chiado', bad),
        throwsA(isA<PaymentDeclined>()),
      );
      expect(c.read(applicationProvider('a-chiado'))!.depositPaidAt, isNull);
      final good = cards.firstWhere((x) => x.last4 != seed.decliningCardLast4);
      final paid = await n.payDeposit('a-chiado', good);
      expect(paid.depositCard, 'Visa ending 4242');
      // Only what a receipt shows is kept.
      expect(paid.toJson().toString(), isNot(contains('4242 4242')));
    });
  });

  group('browse state', () {
    test(
      'saved and recently viewed start from the seed, then are yours',
      () async {
        final (c, _) = await makeContainer(seed);
        expect(await c.read(savedProvider.future), seed.saved);
        await c.read(savedProvider.notifier).add('alfama');
        expect(c.read(savedIdsProvider).first, 'alfama');
        await c.read(savedProvider.notifier).remove('alfama');
        await c.read(savedProvider.notifier).restore('alfama', 2);
        expect(c.read(savedIdsProvider)[2], 'alfama');

        await c.read(recentProvider.future);
        await c.read(recentProvider.notifier).viewed('quinta');
        await c.read(recentProvider.notifier).viewed('alfama');
        expect(c.read(recentProvider).value!.take(2), ['alfama', 'quinta']);
        expect(c.read(recentProvider).value!.toSet().length, 4);
      },
    );

    test('near you is sorted by distance from the chosen area', () async {
      final (c, _) = await makeContainer(seed);
      await warm(c);
      await c.read(areaProvider.notifier).set('Alfama');
      expect(c.read(nearbyHomesProvider).first.id, 'alfama');
      await c.read(listingKindProvider.notifier).set(ListingKind.sale);
      await c.read(areaProvider.notifier).set('Belém');
      expect(c.read(nearbyHomesProvider).first.id, 'belem');
    });
  });
}
