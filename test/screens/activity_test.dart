import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/models/viewing.dart';
import 'package:keystone/providers/activity_providers.dart';
import 'package:keystone/providers/core_providers.dart';
import 'package:keystone/screens/application/application_screen.dart';
import 'package:keystone/screens/booking/book_viewing_screen.dart';
import 'package:keystone/screens/messages/messages_screen.dart';
import 'package:keystone/screens/messages/thread_screen.dart';
import 'package:keystone/screens/viewings/viewings_tab.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  group('book a viewing', () {
    testWidgets('a taken time explains itself, and confirm asks for a time', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const BookViewingScreen(homeId: 'alfama'));
      await t.tap(find.byKey(BookingKeys.confirm));
      await t.pumpAndSettle();
      expect(find.text('Choose a time first.'), findsOneWidget);

      // 09:00 today has gone (it is 10:00).
      final gone = DateTime(testNow.year, testNow.month, testNow.day, 9);
      await t.tap(find.byKey(BookingKeys.slot(gone)));
      await t.pumpAndSettle();
      expect(find.text('That time has passed.'), findsOneWidget);
      expect(find.text('No time chosen yet'), findsOneWidget);
    });

    testWidgets('Sunday has no viewings and says so', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const BookViewingScreen(homeId: 'alfama'));
      await t.tap(find.byKey(BookingKeys.day(4)));
      await t.pumpAndSettle();
      expect(
        find.text('There are no viewings on a Sunday. Choose another day.'),
        findsOneWidget,
      );
    });

    testWidgets('a day, a free time and video books it', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const BookViewingScreen(homeId: 'alfama'));
      await t.tap(find.byKey(BookingKeys.day(2)));
      await t.pumpAndSettle();
      final day = testNow.add(const Duration(days: 2));
      final free = (await (await c.read(
        viewingRepositoryProvider.future,
      )).slots('alfama', day)).firstWhere((s) => s.free);
      await t.tap(find.byKey(BookingKeys.slot(free.at)));
      await tapVisible(t, find.byKey(BookingKeys.mode(ViewingMode.video)));
      expect(find.textContaining('video call'), findsOneWidget);
      await t.tap(find.byKey(BookingKeys.confirm));
      await t.pumpAndSettle();
      expect(find.text('Viewing booked'), findsOneWidget);
      final mine = c
          .read(viewingsProvider)
          .value!
          .where((v) => v.homeId == 'alfama');
      expect(mine.single.at, free.at);
      expect(mine.single.mode, ViewingMode.video);
    });

    testWidgets('rescheduling moves the viewing rather than adding one', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await warm(c);
      final v = c
          .read(viewingsProvider)
          .value!
          .firstWhere((v) => v.id == 'v-next');
      await pumpScreen(
        t,
        c,
        BookViewingScreen(homeId: v.homeId, reschedule: v),
      );
      expect(find.text('Move your viewing'), findsOneWidget);
      await t.tap(find.byKey(BookingKeys.day(1)));
      await t.pumpAndSettle();
      final free =
          (await (await c.read(viewingRepositoryProvider.future)).slots(
            v.homeId,
            testNow.add(const Duration(days: 1)),
          )).firstWhere((s) => s.free);
      await t.tap(find.byKey(BookingKeys.slot(free.at)));
      await t.tap(find.byKey(BookingKeys.confirm));
      await t.pumpAndSettle();
      final all = c.read(viewingsProvider).value!;
      expect(all.length, 5);
      expect(all.firstWhere((x) => x.id == 'v-next').at, free.at);
    });
  });

  group('viewings', () {
    testWidgets('upcoming and past are told apart, soonest first', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ViewingsTab());
      expect(find.text('Upcoming, 2'), findsOneWidget);
      expect(find.text('Past, 3'), findsOneWidget);
      expect(find.byKey(ViewingKeys.card('v-soon')), findsOneWidget);
      expect(find.text('IN 45 MIN'), findsOneWidget);
      expect(find.byKey(ViewingKeys.card('v-past')), findsNothing);
      await t.tap(find.byKey(const Key('viewings-Past, 3')));
      await t.pumpAndSettle();
      expect(find.byKey(ViewingKeys.card('v-past')), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      // The viewed rental already has an application, and says where it is.
      expect(find.text('Rental application: Approved'), findsOneWidget);
    });

    testWidgets('cancel asks first, then can be undone', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ViewingsTab());
      await t.tap(find.byKey(ViewingKeys.cancel('v-next')));
      await t.pumpAndSettle();
      expect(find.text('Cancel this viewing?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm-remove')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      Viewing next() =>
          c.read(viewingsProvider).value!.firstWhere((v) => v.id == 'v-next');
      expect(next().status(testNow), ViewingStatus.cancelled);
      expect(find.text('Upcoming, 1'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(next().status(testNow), ViewingStatus.upcoming);
      expect(find.text('Upcoming, 2'), findsOneWidget);
    });

    testWidgets('with nothing booked it says so', (t) async {
      phone(t);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {'viewings': '[]'},
      );
      await pumpScreen(t, c, const ViewingsTab());
      expect(find.text('No viewings booked'), findsOneWidget);
    });
  });

  group('messages', () {
    testWidgets('an unread thread carries a dot, and opening it reads it', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const MessagesScreen());
      expect(c.read(unreadCountProvider), 1);
      expect(find.byKey(const Key('unread-t-ines')), findsOneWidget);
      expect(find.byKey(const Key('unread-t-tomas')), findsNothing);
      await t.tap(find.byKey(MessageKeys.thread('t-ines')));
      await t.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(c.read(unreadCountProvider), 0);
    });

    testWidgets('sending adds the message, and the agent answers', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ThreadScreen(threadId: 't-tomas'));
      expect(c.read(threadProvider('t-tomas'))!.messages.length, 3);
      await t.enterText(find.byKey(MessageKeys.field), 'Any news?');
      await t.pump();
      await t.tap(find.byKey(MessageKeys.send));
      await t.pumpAndSettle();
      final messages = c.read(threadProvider('t-tomas'))!.messages;
      expect(messages.length, 5);
      expect(messages[3].text, 'Any news?');
      expect(messages[3].fromMe, isTrue);
      expect(messages[4].fromMe, isFalse);
      expect(find.text('Any news?'), findsOneWidget);
      // It was read as it arrived, because the thread is open.
      expect(c.read(unreadCountProvider), 1);
      expect(c.read(threadProvider('t-tomas'))!.unread, 0);
    });

    testWidgets('swiping deletes a thread, with an undo', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const MessagesScreen());
      await t.drag(
        find.byKey(MessageKeys.thread('t-leonor')),
        const Offset(-360, 0),
      );
      await t.pumpAndSettle();
      expect(c.read(threadsProvider).value!.length, 2);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(threadsProvider).value!.length, 3);
    });
  });

  group('application', () {
    testWidgets('applying to rent sends it and shows the timeline', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ApplicationScreen(homeId: 'alfama'));
      expect(find.text('Apply to rent'), findsOneWidget);
      expect(
        find.text('2 from your profile go with this, 1 verified.'),
        findsOneWidget,
      );
      await t.enterText(find.byKey(ApplicationKeys.note), 'Just me.');
      await t.tap(find.byKey(ApplicationKeys.submit));
      await t.pumpAndSettle();
      final a = c.read(applicationForHomeProvider('alfama'))!;
      expect(a.note, 'Just me.');
      expect(a.moveIn, isNotNull);
      expect(find.text('Application sent'), findsOneWidget);
      // Not approved yet, so nothing to pay.
      expect(find.byKey(ApplicationKeys.pay), findsNothing);
    });

    testWidgets('an offer starts at the asking price', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ApplicationScreen(homeId: 'restelo'));
      expect(find.text('Make an offer'), findsOneWidget);
      expect(find.text('€1,690,000'), findsWidgets);
      expect(find.text('The asking price'), findsOneWidget);
      await t.tap(find.byKey(ApplicationKeys.submit));
      await t.pumpAndSettle();
      expect(
        c.read(applicationForHomeProvider('restelo'))!.offer!.amount,
        169000000,
      );
      expect(find.text('Offer sent'), findsOneWidget);
    });

    testWidgets('a declined card says so, another card pays', (t) async {
      phone(t, size: const Size(390, 1400));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ApplicationScreen(homeId: 'chiado'));
      expect(find.text('Pay €969 deposit'), findsOneWidget);
      await t.tap(find.byKey(ApplicationKeys.card('mc')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ApplicationKeys.pay));
      await t.pumpAndSettle();
      expect(find.byKey(ApplicationKeys.declined), findsOneWidget);
      expect(c.read(applicationProvider('a-chiado'))!.depositPaidAt, isNull);

      await t.tap(find.byKey(ApplicationKeys.card('visa')));
      await t.pumpAndSettle();
      expect(find.byKey(ApplicationKeys.declined), findsNothing);
      await t.tap(find.byKey(ApplicationKeys.pay));
      await t.pumpAndSettle();
      expect(c.read(applicationProvider('a-chiado'))!.depositPaidAt, testNow);
      expect(find.byKey(ApplicationKeys.pay), findsNothing);
      expect(find.text('DEPOSIT PAID'), findsOneWidget);
      // Once paid it can no longer be withdrawn.
      expect(find.byKey(ApplicationKeys.withdraw), findsNothing);
    });

    testWidgets('withdrawing asks first and can be undone', (t) async {
      phone(t, size: const Size(390, 1400));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ApplicationScreen(homeId: 'belem'));
      await t.tap(find.byKey(ApplicationKeys.withdraw));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-remove')));
      await t.pumpAndSettle();
      expect(c.read(applicationForHomeProvider('belem')), isNull);
      expect(find.text('Make an offer'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(applicationForHomeProvider('belem')), isNotNull);
    });
  });
}
