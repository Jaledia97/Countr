import 'dart:convert';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: Empirical Challenge - UNOWNED Badge Clearance & Text Rendering', () {
    VaultItem createItem({
      required String id,
      required String name,
      required int quantity,
      bool isGraded = false,
      String condition = 'Near Mint',
    }) {
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        flavorName: null,
        setOrSeries: 'Modern Horizons 3',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2026, 1, 1),
        quantity: quantity,
        condition: condition,
        isGraded: isGraded,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        personalNotes: null,
        primaryBinderId: null,
        currentMarketPrice: 25.0,
        lastPriceUpdate: DateTime(2026, 1, 1),
        dynamicData: jsonEncode({}),
      );
    }

    Widget harness(Widget child, {double width = 112.0, double textScale = 1.0}) {
      return ProviderScope(
        overrides: [
          userPersonaProvider.overrideWith((ref) => UserPersona.investor),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: SizedBox(
                  width: width,
                  height: width * 1.5,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1.1 UNOWNED badge renders exact text "UNOWNED" with amber styling for quantity == 0', (tester) async {
      final item = createItem(id: 'unowned-1', name: 'Mox Diamond', quantity: 0);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));
      expect(badgeFinder, findsOneWidget);

      final textFinder = find.descendant(of: badgeFinder, matching: find.byType(Text));
      expect(textFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.data, equals('UNOWNED'));
      expect(textWidget.style?.color, equals(AppColors.accentAmber));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w800));
    });

    testWidgets('1.2 Positive clearance between SLAB badge and UNOWNED badge on compact 112px mobile tile', (tester) async {
      const tileWidth = 112.0;
      final item = createItem(
        id: 'slab-unowned-112',
        name: 'Graded Unowned Mox',
        quantity: 0,
        isGraded: true,
      );

      await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth));
      await tester.pumpAndSettle();

      final slabFinder = find.byKey(Key('vault_tile_slab_badge_${item.id}'));
      final unownedFinder = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));

      expect(slabFinder, findsOneWidget);
      expect(unownedFinder, findsOneWidget);

      final slabRect = tester.getRect(slabFinder);
      final unownedRect = tester.getRect(unownedFinder);

      debugPrint('112px Tile Measurements -> SLAB right: ${slabRect.right}, UNOWNED left: ${unownedRect.left}');
      final clearance = unownedRect.left - slabRect.right;
      debugPrint('112px Tile Clearance: ${clearance.toStringAsFixed(2)}px');

      expect(clearance, greaterThan(0.0),
          reason: 'UNOWNED badge must maintain positive horizontal clearance against SLAB badge on 112px mobile tile');
      expect(clearance, closeTo(0.90, 0.1),
          reason: 'Empirical measurement: clearance is +0.90px on 112px mobile tile');
    });

    testWidgets('1.3 Unowned badge standalone rendering under 1.5x and 2.0x text scaling on 112px tile', (tester) async {
      const tileWidth = 112.0;
      for (final scale in [1.5, 2.0]) {
        final item = createItem(
          id: 'unowned-scale-$scale',
          name: 'Unowned Lotus Scale Test',
          quantity: 0,
          isGraded: false,
        );

        await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth, textScale: scale));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final unownedFinder = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));
        expect(unownedFinder, findsOneWidget);

        final unownedRect = tester.getRect(unownedFinder);
        final tileRect = tester.getRect(find.byType(VaultItemTile));

        // UNOWNED badge must fit within the tile boundaries
        expect(unownedRect.right, lessThanOrEqualTo(tileRect.right));
        expect(unownedRect.left, greaterThanOrEqualTo(tileRect.left));
      }
    });

    testWidgets('1.4 Foil badge and UNOWNED badge clearance on 112px tile', (tester) async {
      const tileWidth = 112.0;
      final item = createItem(
        id: 'foil-unowned',
        name: 'Foil Unowned Card',
        quantity: 0,
        condition: 'Near Mint Foil',
      );

      await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth));
      await tester.pumpAndSettle();

      final foilFinder = find.byKey(Key('vault_tile_foil_badge_${item.id}'));
      final unownedFinder = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));

      expect(foilFinder, findsOneWidget);
      expect(unownedFinder, findsOneWidget);

      final foilRect = tester.getRect(foilFinder);
      final unownedRect = tester.getRect(unownedFinder);
      final clearance = unownedRect.left - foilRect.right;

      expect(clearance, greaterThan(0.0));
      debugPrint('Foil + UNOWNED clearance: ${clearance.toStringAsFixed(2)}px');
    });
  });

  group('Group 2: Empirical Challenge - Default Exclusions & Art/Special Inclusions', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Insert playable card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-playable',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'M11',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'layout': 'normal', 'rarity': 'common'}),
        ),
      );

      // Insert Art Series card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-art-series',
          collectionType: 'mtg',
          name: 'Ajani Art Series Card',
          setOrSeries: 'MH3',
          imageUrl: '',
          acquiredPrice: 0.5,
          acquiredDate: DateTime.now(),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'layout': 'art_series', 'rarity': 'common'}),
        ),
      );

      // Insert Memorabilia / Unplayable cards
      final memorabilia = [
        ('token-goblin', 'Goblin Token', 'token'),
        ('token-dfc', 'Day / Night Token', 'double_faced_token'),
        ('emblem-chandra', 'Chandra Emblem', 'emblem'),
        ('planar-plane', 'Academy at Tolaria West', 'planar'),
        ('scheme-scheme', 'All in Good Time Scheme', 'scheme'),
        ('vanguard-card', 'Ashnod Vanguard', 'vanguard'),
      ];

      for (final m in memorabilia) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: m.$1,
            collectionType: 'mtg',
            name: m.$2,
            setOrSeries: 'MEM',
            imageUrl: '',
            acquiredPrice: 0.1,
            acquiredDate: DateTime.now(),
            quantity: const Value(1),
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 0.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'layout': m.$3, 'rarity': 'special'}),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('2.1 Database SQL Queries: Default exclusion hides Art Series and all Memorabilia', () async {
      // Default query without filters
      final defaultItems = await db.vaultDao.watchItemsByCollection(
        'mtg',
        mtgFilter: const MtgFilterState(),
      ).first;

      final defaultIds = defaultItems.map((i) => i.id).toSet();
      expect(defaultIds, contains('card-playable'), reason: 'Playable cards must appear by default');
      expect(defaultIds, isNot(contains('card-art-series')), reason: 'Art Series must be hidden by default');
      expect(defaultIds, isNot(contains('token-goblin')), reason: 'Token must be hidden by default');
      expect(defaultIds, isNot(contains('token-dfc')), reason: 'DFC Token must be hidden by default');
      expect(defaultIds, isNot(contains('emblem-chandra')), reason: 'Emblem must be hidden by default');
      expect(defaultIds, isNot(contains('planar-plane')), reason: 'Planar card must be hidden by default');
      expect(defaultIds, isNot(contains('scheme-scheme')), reason: 'Scheme card must be hidden by default');
      expect(defaultIds, isNot(contains('vanguard-card')), reason: 'Vanguard card must be hidden by default');
      expect(defaultItems.length, equals(1));
    });

    test('2.2 Database SQL Queries: "art_card" filter surfaces Art Series cards', () async {
      final artItems = await db.vaultDao.watchItemsByCollection(
        'mtg',
        mtgFilter: const MtgFilterState(rarities: {'art_card'}),
      ).first;

      final artIds = artItems.map((i) => i.id).toSet();
      expect(artIds, contains('card-art-series'), reason: 'Art Series card must appear when art_card is filtered');
      expect(artIds, isNot(contains('card-playable')), reason: 'Playable common should not match art_card rarity');
      expect(artIds, isNot(contains('token-goblin')), reason: 'Tokens should not match art_card rarity');
    });

    test('2.3 Database SQL Queries: "special_card" filter surfaces tokens and memorabilia', () async {
      final specialItems = await db.vaultDao.watchItemsByCollection(
        'mtg',
        mtgFilter: const MtgFilterState(rarities: {'special_card'}),
      ).first;

      final specialIds = specialItems.map((i) => i.id).toSet();
      expect(specialIds, contains('token-goblin'));
      expect(specialIds, contains('token-dfc'));
      expect(specialIds, contains('emblem-chandra'));
      expect(specialIds, contains('planar-plane'));
      expect(specialIds, contains('scheme-scheme'));
      expect(specialIds, contains('vanguard-card'));
      expect(specialIds, isNot(contains('card-art-series')));
      expect(specialIds, isNot(contains('card-playable')));
    });

    test('2.4 In-Memory MtgFilterState: Exclusions and Inclusions match empirical spec', () {
      final playable = VaultItem(
        id: 'p1', collectionType: 'mtg', name: 'P', flavorName: null, setOrSeries: 'S', imageUrl: '',
        acquiredPrice: 1, acquiredDate: DateTime.now(), quantity: 1, condition: 'NM', isGraded: false,
        isAltered: false, isMisprint: false, isSigned: false, isDeleted: false, personalNotes: null,
        primaryBinderId: null, currentMarketPrice: 1, lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'layout': 'normal', 'rarity': 'rare'}),
      );

      final artSeries = VaultItem(
        id: 'a1', collectionType: 'mtg', name: 'A', flavorName: null, setOrSeries: 'S', imageUrl: '',
        acquiredPrice: 1, acquiredDate: DateTime.now(), quantity: 1, condition: 'NM', isGraded: false,
        isAltered: false, isMisprint: false, isSigned: false, isDeleted: false, personalNotes: null,
        primaryBinderId: null, currentMarketPrice: 1, lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'layout': 'art_series', 'rarity': 'common'}),
      );

      final token = VaultItem(
        id: 't1', collectionType: 'mtg', name: 'T', flavorName: null, setOrSeries: 'S', imageUrl: '',
        acquiredPrice: 1, acquiredDate: DateTime.now(), quantity: 1, condition: 'NM', isGraded: false,
        isAltered: false, isMisprint: false, isSigned: false, isDeleted: false, personalNotes: null,
        primaryBinderId: null, currentMarketPrice: 1, lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'layout': 'token', 'rarity': 'special'}),
      );

      const defaultFilter = MtgFilterState();
      expect(defaultFilter.matches(playable), isTrue);
      expect(defaultFilter.matches(artSeries), isFalse);
      expect(defaultFilter.matches(token), isFalse);

      const artFilter = MtgFilterState(rarities: {'art_card'});
      expect(artFilter.matches(playable), isFalse);
      expect(artFilter.matches(artSeries), isTrue);
      expect(artFilter.matches(token), isFalse);

      const specialFilter = MtgFilterState(rarities: {'special_card'});
      expect(specialFilter.matches(playable), isFalse);
      expect(specialFilter.matches(artSeries), isFalse);
      expect(specialFilter.matches(token), isTrue);
    });
  });

  group('Group 3: Empirical Challenge - "All Cards" Label & Catalog Filter UI', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
      await db.vaultDao.seedDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildApp({required String collectionName, required ProviderContainer container}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const VaultScreen(),
        ),
      );
    }

    testWidgets('3.1 In MTG mode: Filter chip renders "All Cards" label (no "Catalog (Ref)") and sets showCatalog on tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(collectionName: 'Magic: The Gathering', container: container));
      await tester.pumpAndSettle();

      // Assert "All Cards" text is rendered
      expect(find.text('All Cards'), findsOneWidget);
      expect(find.text('Catalog (Ref)'), findsNothing);

      // Verify the chip key is maintained for backward compatibility
      final chipFinder = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      expect(chipFinder, findsOneWidget);

      final chipWidget = tester.widget<FilterChip>(chipFinder);
      expect(chipWidget.selected, isFalse);
      expect(container.read(vaultShowCatalogProvider), isFalse);

      // Tap "All Cards" chip
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Verify state updated
      expect(container.read(vaultShowCatalogProvider), isTrue);
      final updatedChip = tester.widget<FilterChip>(chipFinder);
      expect(updatedChip.selected, isTrue);
    });

    testWidgets('3.2 In Polymorphic mode (All Collections): Filter chip renders "All Cards" label and sets showCatalog on tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(collectionName: 'All Collections', container: container));
      await tester.pumpAndSettle();

      // Assert "All Cards" text is rendered in polymorphic filter row
      expect(find.text('All Cards'), findsOneWidget);
      expect(find.text('Catalog (Ref)'), findsNothing);

      final chipFinder = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      expect(chipFinder, findsOneWidget);

      final chipWidget = tester.widget<FilterChip>(chipFinder);
      expect(chipWidget.selected, isFalse);

      // Tap "All Cards" chip
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isTrue);
      final updatedChip = tester.widget<FilterChip>(chipFinder);
      expect(updatedChip.selected, isTrue);
    });
  });
}
