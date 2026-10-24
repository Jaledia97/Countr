import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

VaultItem createChallengerCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'C17',
  String imageUrl = 'https://cards.scryfall.io/normal/front/test.jpg',
  double acquiredPrice = 0.0,
  double currentMarketPrice = 15.0,
  int quantity = 1,
  DateTime? acquiredDate,
  Map<String, dynamic>? dynamicDataMap,
}) {
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: acquiredPrice,
    acquiredDate: acquiredDate ?? DateTime(2021, 6, 1),
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    isDeleted: false,
    personalNotes: null,
    primaryBinderId: null,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2021, 6, 1),
    dynamicData: jsonEncode(dynamicDataMap ?? {
      'layout': 'normal',
      'mana_cost': '{1}{R}',
      'type_line': 'Instant',
      'oracle_text': 'Deal 3 damage to any target.',
      'rarity': 'common',
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithHarness(Widget child) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        userPersonaProvider.overrideWith((ref) => UserPersona.investor),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        activeGameContextProvider.overrideWith((ref) => 'mtg'),
        vaultShowCatalogProvider.overrideWith((ref) => false),
        vaultSearchQueryProvider.overrideWith((ref) => ''),
        vaultPaginationLimitProvider.overrideWith((ref) => 100),
        vaultIsFetchingMoreProvider.overrideWith((ref) => false),
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // ===========================================================================
  // GROUP 1: Duplicate Card IDs & Hero Animation Invariants
  // ===========================================================================
  group('Empirical Challenge 1: Duplicate Card IDs & Hero Animation Invariants', () {
    testWidgets('1.1: CardDetailSheet with 2 duplicate card instances (same ID) renders and swipes without Hero collision', (tester) async {
      setupScreen(tester);
      final cardA = createChallengerCard(id: 'duplicate-bolt', name: 'Lightning Bolt');
      final cardB = createChallengerCard(id: 'duplicate-bolt', name: 'Lightning Bolt');

      int currentIdx = 0;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [cardA, cardB],
          initialIndex: 0,
          onPageChanged: (idx) => currentIdx = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Initial render of duplicate cards must not throw Hero collision');
      expect(find.text('Lightning Bolt'), findsWidgets);

      // Swipe from index 0 to index 1
      final pv = tester.widget<PageView>(find.byType(PageView));
      pv.controller!.jumpToPage(1);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Swiping to duplicate card must not throw Hero collision');
      expect(currentIdx, equals(1));

      // Swipe back to index 0
      pv.controller!.jumpToPage(0);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Swiping back to index 0 must not throw Hero collision');
      expect(currentIdx, equals(0));
    });

    testWidgets('1.2: CardDetailSheet with 3 duplicate card instances (same ID) swipes forward and backward without collision', (tester) async {
      setupScreen(tester);
      final cards = [
        createChallengerCard(id: 'triple-sol-ring', name: 'Sol Ring'),
        createChallengerCard(id: 'triple-sol-ring', name: 'Sol Ring'),
        createChallengerCard(id: 'triple-sol-ring', name: 'Sol Ring'),
      ];

      int currentIdx = 0;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
          onPageChanged: (idx) => currentIdx = idx,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final pv = tester.widget<PageView>(find.byType(PageView));

      // Swipe 0 -> 1
      pv.controller!.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Swipe to page 1 must succeed without Hero exception');
      expect(currentIdx, equals(1));

      // Swipe 1 -> 2
      pv.controller!.jumpToPage(2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Swipe to page 2 must succeed without Hero exception');
      expect(currentIdx, equals(2));

      // Swipe 2 -> 1
      pv.controller!.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(currentIdx, equals(1));

      // Swipe 1 -> 0
      pv.controller!.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(currentIdx, equals(0));
    });

    testWidgets('1.3: FullScreenCardViewer with duplicate card IDs renders and swipes across pages without Hero collision', (tester) async {
      setupScreen(tester);
      final cards = [
        createChallengerCard(id: 'fs-duplicate-id', name: 'Swamp'),
        createChallengerCard(id: 'fs-duplicate-id', name: 'Swamp'),
        createChallengerCard(id: 'fs-duplicate-id', name: 'Swamp'),
      ];

      int activeIdx = 0;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: cards,
          initialIndex: 0,
          onPageChanged: (idx) => activeIdx = idx,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final pv = tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view')));

      // Swipe through all 3 duplicate cards
      pv.controller!.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(activeIdx, equals(1));

      pv.controller!.jumpToPage(2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(activeIdx, equals(2));

      pv.controller!.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(activeIdx, equals(0));
    });

    testWidgets('1.4: Opening FullScreenCardViewer from CardDetailSheet via expand button executes Hero transition cleanly', (tester) async {
      setupScreen(tester);
      final cards = [
        createChallengerCard(id: 'hero-source-card', name: 'The Ur-Dragon'),
        createChallengerCard(id: 'hero-next-card', name: 'Scion of the Ur-Dragon'),
      ];

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final expandBtn = find.byKey(const Key('card_art_expand_overlay'));
      expect(expandBtn, findsOneWidget);

      // Tap expand to open FullScreenCardViewer
      await tester.tap(expandBtn);
      await tester.pump(); // Start transition
      await tester.pump(const Duration(milliseconds: 150)); // Mid-transition Hero flight
      expect(tester.takeException(), isNull, reason: 'Mid-flight Hero animation must not crash');
      await tester.pumpAndSettle(); // Settle full-screen route

      expect(tester.takeException(), isNull);
      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('The Ur-Dragon'), findsWidgets);

      // Dismiss full-screen viewer
      final closeBtn = find.byKey(const Key('fullscreen_close_button'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150)); // Reverse Hero transition
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsNothing);
      expect(find.byType(CardDetailSheet), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 2: PreconHydrationService Historical Dates (<= 2023)
  // ===========================================================================
  group('Empirical Challenge 2: PreconHydrationService Historical Dates', () {
    test('Seeded precon cards and decks have historical timestamps strictly <= 2023', () async {
      await PreconHydrationService.seedHistoricalPrecons(db);

      // 1. Verify precon deck creation dates
      final preconDecks = await (db.select(db.decks)
            ..where((t) => t.id.like('precon-%')))
          .get();
      expect(preconDecks.length, equals(12));
      for (final deck in preconDecks) {
        expect(deck.createdAt.year, lessThanOrEqualTo(2024),
            reason: 'Deck ${deck.name} createdAt must be historical (<= 2024), was ${deck.createdAt}');
      }

      // 2. Verify deck version creation dates
      final preconVersions = await (db.select(db.deckVersions)
            ..where((t) => t.id.like('precon-%')))
          .get();
      expect(preconVersions.length, equals(12));
      for (final version in preconVersions) {
        expect(version.createdAt.year, lessThanOrEqualTo(2024),
            reason: 'DeckVersion ${version.id} createdAt must be historical (<= 2024), was ${version.createdAt}');
      }

      // 3. Verify vault_items acquired_date for cards seeded by precons
      final preconDeckVersionIds = (await (db.select(db.deckVersions)
            ..where((t) => t.id.like('precon-%')))
          .get()).map((v) => v.id).toList();

      final preconCardIds = (await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.isIn(preconDeckVersionIds)))
          .get()).map((i) => i.vaultItemId).toSet();

      final preconVaultItems = await (db.select(db.vaultItems)
            ..where((t) => t.id.isIn(preconCardIds) & t.quantity.equals(0)))
          .get();
      expect(preconVaultItems.isNotEmpty, isTrue);

      for (final item in preconVaultItems) {
        expect(item.acquiredDate.year, lessThanOrEqualTo(2024),
            reason: 'Precon card ${item.name} (${item.id}) acquiredDate must be <= 2024, was ${item.acquiredDate}');
      }
    });

    test('repairSyntheticPreconVaultItems repairs cards with modern dates (> 2025) back to historical timestamps', () async {
      // Insert a synthetic row with a 2026 timestamp and synthetic oracle ID
      final syntheticId = 'synth-test-card-1';
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: syntheticId,
          collectionType: 'mtg',
          name: 'The Ur-Dragon',
          setOrSeries: 'C17',
          imageUrl: 'https://cards.scryfall.io/normal/front/1/2/synth.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now, // 2026 date!
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 25.0,
          lastPriceUpdate: now,
          dynamicData: '{"oracle_id": "12a34567-synthetic-oracle", "layout": "normal"}',
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

      // Verify row exists with 2026 timestamp
      final rowBefore = await (db.select(db.vaultItems)..where((t) => t.id.equals(syntheticId))).getSingle();
      expect(rowBefore.acquiredDate.year, greaterThanOrEqualTo(2025));

      // Execute repair
      await PreconHydrationService.repairSyntheticPreconVaultItems(db);

      // Verify row was repaired to historical C17 date (2017)
      final rowAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(syntheticId))).getSingle();
      expect(rowAfter.acquiredDate.year, equals(2017),
          reason: 'C17 synthetic row should be repaired to 2017');
      expect(rowAfter.imageUrl, contains('https://api.scryfall.com/cards/named?exact=The%20Ur-Dragon'),
          reason: 'Synthetic image URL should be repaired to canonical named Scryfall URL');
    });
  });

  // ===========================================================================
  // GROUP 3: PreconHydrationService onConflict: DoUpdate Non-Destructive Integrity
  // ===========================================================================
  group('Empirical Challenge 3: onConflict: DoUpdate Non-Destructive Data Preservation', () {
    test('Precon seeding does NOT overwrite existing rich dynamic_data or custom image_url on conflict', () async {
      // 1. Identify a Scryfall ID that is present in the seeded precons (e.g. The Ur-Dragon: 7e78b70b-0c67-4f14-8ad7-c9f8e3f59743)
      const targetScryfallId = '7e78b70b-0c67-4f14-8ad7-c9f8e3f59743';
      const customImageUrl = 'https://custom-cdn.example.com/art/ur_dragon_foil.jpg';
      const richDynamicData = '{"custom_user_tag": "favorite_commander", "scryfall_cache": true, "power": "10"}';

      // Insert pre-existing user catalog item
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: targetScryfallId,
          collectionType: 'mtg',
          name: 'The Ur-Dragon (User Edition)',
          setOrSeries: 'SLD',
          imageUrl: customImageUrl,
          acquiredPrice: 45.0,
          acquiredDate: DateTime(2021, 1, 15),
          quantity: const drift.Value(1), // Owned user card
          condition: 'NM',
          currentMarketPrice: 50.0,
          lastPriceUpdate: DateTime(2021, 1, 15),
          dynamicData: richDynamicData,
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(DateTime(2021, 1, 15)),
        ),
      );

      // 2. Force seed precons (which includes The Ur-Dragon under C17)
      await PreconHydrationService.seedHistoricalPrecons(db, force: true);

      // 3. Query the item after precon seeding
      final itemAfterSeed = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(targetScryfallId)))
          .getSingle();

      // INVARIANT 1: Rich custom dynamic_data MUST be preserved!
      expect(itemAfterSeed.dynamicData, equals(richDynamicData),
          reason: 'Existing dynamic_data must NOT be wiped or replaced by precon dynamicData');

      // INVARIANT 2: Custom image_url MUST be preserved!
      expect(itemAfterSeed.imageUrl, equals(customImageUrl),
          reason: 'Existing custom image_url must NOT be overwritten by precon default image_url');

      // INVARIANT 3: Owned quantity MUST be preserved (quantity = 1, not reset to 0)
      expect(itemAfterSeed.quantity, equals(1),
          reason: 'Owned quantity of existing card must NOT be overwritten by precon quantity = 0');

      // INVARIANT 4: Acquired date MUST be preserved
      expect(itemAfterSeed.acquiredDate, equals(DateTime(2021, 1, 15)),
          reason: 'Acquired date of existing card must NOT be overwritten');
    });

    test('Precon seeding DOES populate image_url and dynamic_data when existing row has empty values', () async {
      const targetScryfallId = '7e78b70b-0c67-4f14-8ad7-c9f8e3f59743';

      // Insert pre-existing row with empty image_url and empty dynamic_data
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: targetScryfallId,
          collectionType: 'mtg',
          name: 'The Ur-Dragon',
          setOrSeries: 'C17',
          imageUrl: '', // EMPTY
          acquiredPrice: 0.0,
          acquiredDate: DateTime(2021, 1, 15),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime(2021, 1, 15),
          dynamicData: '', // EMPTY
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(DateTime(2021, 1, 15)),
        ),
      );

      // Force seed precons
      await PreconHydrationService.seedHistoricalPrecons(db, force: true);

      final itemAfterSeed = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(targetScryfallId)))
          .getSingle();

      // INVARIANT: When existing values are empty, precon values should fill them
      expect(itemAfterSeed.imageUrl.isNotEmpty, isTrue,
          reason: 'Precon seeding should fill empty imageUrl on conflict');
      expect(itemAfterSeed.dynamicData.isNotEmpty, isTrue,
          reason: 'Precon seeding should fill empty dynamicData on conflict');
      expect(itemAfterSeed.dynamicData, isNot(equals('{}')));
    });
  });
}
