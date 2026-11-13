import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/models/home.dart';
import 'package:keystone/providers/browse_providers.dart';
import 'package:keystone/screens/home/home_tab.dart';
import 'package:keystone/screens/property/brochure_screen.dart';
import 'package:keystone/screens/property/gallery_screen.dart';
import 'package:keystone/screens/property/property_screen.dart';
import 'package:keystone/screens/saved/compare_screen.dart';
import 'package:keystone/screens/saved/saved_tab.dart';
import 'package:keystone/screens/search/filter_sheet.dart';
import 'package:keystone/screens/search/search_screen.dart';
import 'package:keystone/widgets/city_map_view.dart';
import 'package:keystone/widgets/floor_plan.dart';
import 'package:keystone/widgets/viewing_island.dart';

import '../helpers.dart';

const tall = Size(390, 2600);

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  group('home', () {
    testWidgets('sections come in the order of the brief', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      expect(find.text('Welcome, Olympicson'), findsOneWidget);
      expect(find.text('Lisbon, Portugal'), findsOneWidget);
      final tops = [
        for (final k in [
          HomeKeys.location,
          HomeKeys.search,
          const Key('kind-Rent'),
          HomeKeys.featured,
          HomeKeys.newThisWeek,
          HomeKeys.nearYou,
          HomeKeys.recent,
        ])
          t.getTopLeft(find.byKey(k)).dy,
      ];
      expect(tops, [...tops]..sort());
      for (final title in [
        'Featured',
        'New this week',
        'Near you',
        'Recently viewed',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('a viewing within the hour shows a live countdown', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      expect(find.byType(ViewingIsland), findsOneWidget);
      expect(find.text('Viewing in 45 min'), findsOneWidget);
    });

    testWidgets('Rent or Buy swaps every list, and is remembered', (t) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      expect(find.text('The Printworks Loft'), findsWidgets);
      expect(find.text('Casa do Jacarandá'), findsNothing);
      await t.tap(find.byKey(const Key('kind-Buy')));
      await t.pumpAndSettle();
      expect(c.read(listingKindProvider), ListingKind.sale);
      expect(find.text('Casa do Jacarandá'), findsWidgets);
      expect(store.string('listing_kind'), 'sale');
    });

    testWidgets('choosing an area re-sorts what is near', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      await t.tap(find.byKey(HomeKeys.location));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('area-Alfama')));
      await t.pumpAndSettle();
      expect(find.text('Alfama, Lisbon'), findsOneWidget);
      expect(find.text('Near Alfama'), findsOneWidget);
      expect(c.read(nearbyHomesProvider).first.id, 'alfama');
    });

    testWidgets('the heart saves a home', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      expect(c.read(savedIdsProvider), isNot(contains('alfama')));
      await t.tap(find.byKey(const Key('save-alfama')).last);
      await t.pumpAndSettle();
      expect(c.read(savedIdsProvider).first, 'alfama');
      await t.tap(find.byKey(const Key('save-alfama')).last);
      await t.pumpAndSettle();
      expect(c.read(savedIdsProvider), isNot(contains('alfama')));
    });
  });

  group('search', () {
    testWidgets('text narrows the list as it is typed', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      expect(find.text('5 homes'), findsOneWidget);
      await t.enterText(find.byKey(SearchKeys.field), 'alfama');
      await t.pumpAndSettle();
      expect(find.text('1 home'), findsOneWidget);
      expect(find.text('Alfama Light Apartment'), findsOneWidget);
    });

    testWidgets('nothing matching is a named state with a way out', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      await t.enterText(find.byKey(SearchKeys.field), 'castle');
      await t.pumpAndSettle();
      expect(find.text('No homes match that'), findsOneWidget);
      await t.tap(find.text('Clear filters'));
      await t.pumpAndSettle();
      expect(find.text('5 homes'), findsOneWidget);
    });

    testWidgets('filters are tried on a draft and counted on the button', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      await t.tap(find.byKey(SearchKeys.filters));
      await t.pumpAndSettle();
      expect(find.text('Show 5 homes'), findsOneWidget);
      await tapVisible(t, find.byKey(const Key('filter-Bedrooms-2')));
      expect(find.text('Show 4 homes'), findsOneWidget);
      await tapVisible(t, find.byKey(const Key('filter-amenity-Garden')));
      expect(find.text('Show 1 home'), findsOneWidget);
      // Nothing has changed behind the sheet yet.
      expect(c.read(searchResultsProvider).length, 5);
      // The button is pinned inside the screen, not below the fold.
      expect(
        t.getRect(find.byKey(FilterKeys.apply)).bottom,
        lessThanOrEqualTo(844),
      );
      await t.tap(find.byKey(FilterKeys.apply));
      await t.pumpAndSettle();
      expect(c.read(searchFilterProvider).count, 2);
      expect(find.text('Ourique Garden Flat'), findsOneWidget);
      expect(find.text('1 home'), findsOneWidget);
    });

    testWidgets('the map shows the same homes as the list, as pins', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      await t.tap(find.byKey(const Key('view-Map')));
      await t.pumpAndSettle();
      final map = t.widget<CityMapView>(find.byType(CityMapView));
      expect(
        {for (final p in map.pins) p.id},
        {for (final h in c.read(searchResultsProvider)) h.id},
      );
      expect(find.byKey(SearchKeys.selected), findsNothing);
      await t.tap(find.byKey(const Key('pin-loft')));
      await t.pumpAndSettle();
      expect(find.byKey(SearchKeys.selected), findsOneWidget);
      expect(find.text('The Printworks Loft'), findsOneWidget);
    });

    testWidgets('a search can be saved', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      await t.tap(find.byKey(SearchKeys.save));
      await t.pumpAndSettle();
      final saved = c.read(savedSearchesProvider).value!;
      expect(saved.length, 3);
      expect(saved.last.name, 'Rent');
      expect(saved.last.alerts, isTrue);
    });
  });

  group('property', () {
    testWidgets('shows everything, and counts as recently viewed', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const PropertyScreen(homeId: 'quinta'));
      expect(find.text('Quinta da Serra'), findsOneWidget);
      expect(find.text('Calçada do Galvão 120, Ajuda'), findsOneWidget);
      expect(find.text('1 / 7'), findsOneWidget);
      for (final s in [
        'About this home',
        'Amenities',
        'Floor plan',
        'Where it is',
        'Shown by',
        'What would it cost a month?',
        'Similar homes',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.byType(FloorPlan), findsOneWidget);
      expect(find.byType(CityMapView), findsOneWidget);
      expect(find.text('Leonor Matos'), findsOneWidget);
      expect(find.byKey(PropertyKeys.book), findsOneWidget);
      expect(c.read(recentProvider).value!.first, 'quinta');
    });

    testWidgets('a rental shows the rent calculator instead', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const PropertyScreen(homeId: 'alfama'));
      expect(find.text('Can you afford the rent?'), findsOneWidget);
      // Income starts at three times the rent: a third of it goes on rent.
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('Comfortable'), findsOneWidget);
      expect(find.text('€4,950'), findsOneWidget);
    });

    testWidgets('a viewed home offers the way to apply', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const PropertyScreen(homeId: 'chiado'));
      expect(find.byKey(PropertyKeys.apply), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      // One never viewed does not.
      await pumpScreen(t, c, const PropertyScreen(homeId: 'alfama'));
      expect(find.byKey(PropertyKeys.apply), findsNothing);
    });

    testWidgets('a home that has gone says so', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const PropertyScreen(homeId: 'nowhere'));
      expect(find.text('This home has left the market'), findsOneWidget);
    });

    testWidgets('the gallery swipes through every photo', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await warm(c);
      final home = c.read(homeProviderFor('loft'));
      await pumpScreen(t, c, GalleryScreen(home: home, initial: 1));
      expect(find.text('2 of 6'), findsOneWidget);
      await t.drag(
        find.byKey(const Key('gallery-pages')),
        const Offset(-300, 0),
      );
      await t.pumpAndSettle();
      expect(find.text('3 of 6'), findsOneWidget);
    });

    testWidgets('the brochure has five pages that turn', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const BrochureScreen(homeId: 'jacaranda'));
      expect(find.text('1 of 5'), findsOneWidget);
      await t.drag(find.byType(PageView), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('THE HOME'), findsOneWidget);
    });
  });

  group('saved', () {
    testWidgets('remove blows a home away, and undo brings it back', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SavedTab());
      expect(find.text('3 homes on your shortlist'), findsOneWidget);
      await t.tap(find.byKey(SavedKeys.remove('jacaranda')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(c.read(savedIdsProvider), ['loft', 'belem']);
      expect(find.text('2 homes on your shortlist'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(savedIdsProvider), ['loft', 'jacaranda', 'belem']);
    });

    testWidgets(
      'any two can be compared, and the button says what is missing',
      (t) async {
        phone(t);
        final (c, _) = await makeContainer(seed, signedIn: seed.profile);
        await pumpScreen(t, c, const SavedTab());
        await t.tap(find.byKey(SavedKeys.compare));
        await t.pumpAndSettle();
        expect(find.text('Choose two homes'), findsOneWidget);
        await t.tap(find.byKey(SavedKeys.pick('jacaranda')));
        await t.pumpAndSettle();
        expect(find.text('Choose one more'), findsOneWidget);
        await t.tap(find.byKey(SavedKeys.pick('belem')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(SavedKeys.go));
        await t.pumpAndSettle();
        expect(find.byType(CompareScreen), findsOneWidget);
        expect(find.text('Per m²'), findsOneWidget);
        expect(find.text('€2,450,000'), findsWidgets);
      },
    );

    testWidgets('an empty shortlist names the situation', (t) async {
      phone(t);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {'saved': <String>[]},
      );
      await pumpScreen(t, c, const SavedTab());
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.byKey(SavedKeys.compare), findsNothing);
    });
  });
}
