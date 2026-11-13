import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/providers/browse_providers.dart';
import 'package:keystone/providers/session_providers.dart';
import 'package:keystone/screens/auth/auth_screen.dart';
import 'package:keystone/screens/onboarding/onboarding_screen.dart';
import 'package:keystone/screens/profile/documents_screen.dart';
import 'package:keystone/screens/profile/edit_profile_sheet.dart';
import 'package:keystone/screens/profile/key_card.dart';
import 'package:keystone/screens/profile/profile_tab.dart';
import 'package:keystone/screens/profile/saved_searches_screen.dart';
import 'package:keystone/screens/search/search_screen.dart';
import 'package:keystone/services/store.dart';

import '../helpers.dart';

const tall = Size(390, 1500);

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  group('profile', () {
    testWidgets('shows the person, the key card and what needs attention', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ProfileTab());
      expect(find.text('Olympicson'), findsWidgets);
      expect(find.text('hello@flutterzip.com'), findsOneWidget);
      expect(find.byType(KeyCard), findsOneWidget);
      expect(find.text('RESIDENT KEY'), findsOneWidget);
      expect(find.text('Deposit due'), findsOneWidget);
      expect(find.text('1 unread'), findsOneWidget);
    });

    testWidgets('details can be edited, and bad ones are named', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ProfileTab());
      await t.tap(find.byKey(ProfileKeys.edit));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(EditProfileKeys.name), '');
      await t.tap(find.byKey(EditProfileKeys.save));
      await t.pumpAndSettle();
      expect(c.read(profileProvider).value!.name, 'Olympicson');
      await t.enterText(find.byKey(EditProfileKeys.name), 'Ada Obi');
      await t.tap(find.byKey(EditProfileKeys.save));
      await t.pumpAndSettle();
      expect(c.read(profileProvider).value!.name, 'Ada Obi');
      expect(find.text('Ada Obi'), findsWidgets);
    });

    testWidgets('appearance is one tap and is remembered', (t) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ProfileTab());
      await t.tap(find.byKey(const Key('appearance-Dark')));
      await t.pumpAndSettle();
      expect(c.read(themeModeProvider), ThemeMode.dark);
      expect(store.string(Store.themeMode), 'dark');
    });

    testWidgets('sign out hands over to sign in', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ProfileTab());
      await t.tap(find.byKey(ProfileKeys.signOut));
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(c.read(sessionProvider), isNull);
    });

    testWidgets('reset asks first, then starts again from onboarding', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const ProfileTab());
      await c.read(savedProvider.notifier).add('quinta');
      await t.tap(find.byKey(ProfileKeys.reset));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-remove')));
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(store.strings(Store.saved), isNull);
      expect(c.read(sessionProvider), isNull);
    });
  });

  group('documents', () {
    testWidgets('one is verified, one is being checked, one is suggested', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const DocumentsScreen());
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Being checked'), findsOneWidget);
      expect(find.textContaining('Agents usually ask for'), findsNothing);
    });

    testWidgets('add, rename, remove and undo', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const DocumentsScreen());
      await t.tap(find.byKey(DocumentKeys.add));
      await t.pumpAndSettle();
      // A name is needed, and the sheet says so rather than closing.
      await t.tap(find.byKey(DocumentKeys.save));
      await t.pumpAndSettle();
      expect(find.text('Give it a name you will recognise'), findsOneWidget);
      await t.tap(find.byKey(DocumentKeys.kind('Reference')));
      await t.enterText(find.byKey(DocumentKeys.name), 'Letter from Ana');
      await t.tap(find.byKey(DocumentKeys.save));
      await t.pumpAndSettle();
      var docs = c.read(documentsProvider).value!;
      expect(docs.length, 3);
      expect(docs.last.kind, 'Reference');
      expect(find.text('Letter from Ana'), findsOneWidget);

      await t.tap(find.byKey(DocumentKeys.row(docs.last.id)));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(DocumentKeys.name), 'Reference, Ana');
      await t.tap(find.byKey(DocumentKeys.save));
      await t.pumpAndSettle();
      expect(c.read(documentsProvider).value!.last.name, 'Reference, Ana');

      await t.tap(find.byKey(DocumentKeys.remove('d-id')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(c.read(documentsProvider).value!.length, 2);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      docs = c.read(documentsProvider).value!;
      expect(docs.first.id, 'd-id');
    });
  });

  group('saved searches', () {
    testWidgets('each counts its matches, and alerts toggle', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SavedSearchesScreen());
      expect(find.text('Two beds near the river'), findsOneWidget);
      expect(find.text('3 HOMES'), findsOneWidget);
      expect(find.text('Alerts off'), findsOneWidget);
      await t.tap(find.byKey(SearchesKeys.alerts('s-buy')));
      await t.pumpAndSettle();
      expect(
        c.read(savedSearchesProvider).value!.every((s) => s.alerts),
        isTrue,
      );
    });

    testWidgets('tapping one runs it again', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SavedSearchesScreen());
      await t.tap(find.byKey(SearchesKeys.row('s-buy')));
      await t.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(c.read(searchFilterProvider).types, {'House'});
      expect(
        c
            .read(searchResultsProvider)
            .every((h) => h.amenities.contains('Garden')),
        isTrue,
      );
    });

    testWidgets('remove, and undo puts it back in place', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SavedSearchesScreen());
      await t.tap(find.byKey(SearchesKeys.remove('s-rent')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(c.read(savedSearchesProvider).value!.single.id, 's-buy');
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(savedSearchesProvider).value!.first.id, 's-rent');
    });
  });
}
