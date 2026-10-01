import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone Challenger 1: Vault State & Connection Empirical Stress', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestWidget({
      AppDatabase? customDb,
      List<Override> overrides = const [],
    }) {
      final activeDb = customDb ?? db;
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(activeDb),
          vaultDaoProvider.overrideWithValue(activeDb.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...overrides,
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    // ------------------------------------------------------------------------
    // Group 1: Initial Navigation & Database State Rendering
    // ------------------------------------------------------------------------
    group('1. Initial Navigation & Database State Rendering', () {
      testWidgets('Initial navigation to /vault renders cards immediately on seeded DB', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Verify default view mode is Singles (Cards sliver grid is mounted)
        expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsOneWidget);

        // 2. Verify no perpetual loading indicator is present
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // 3. Verify starter MTG cards are displayed
        expect(find.textContaining('The One Ring'), findsWidgets);
        expect(find.textContaining('Sol Ring'), findsWidgets);
        expect(find.textContaining('Black Lotus'), findsWidgets);
        expect(find.textContaining('Lightning Bolt'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Pre-populated database with custom cards renders them immediately without delay', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final now = DateTime.now();
        // Insert custom cards without running standard seedDatabase
        for (var i = 1; i <= 5; i++) {
          await db.into(db.vaultItems).insert(
                VaultItemsCompanion.insert(
                  id: 'custom-card-$i',
                  collectionType: 'mtg',
                  name: 'Custom Mythic Card #$i',
                  setOrSeries: 'Custom Set',
                  imageUrl: 'https://example.com/card$i.jpg',
                  acquiredPrice: 10.0 * i,
                  acquiredDate: now,
                  quantity: const drift.Value(1),
                  condition: 'NM',
                  currentMarketPrice: 15.0 * i,
                  lastPriceUpdate: now,
                  dynamicData: '{"cmc": $i.0}',
                ),
              );
        }

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify custom cards render immediately
        expect(find.textContaining('Custom Mythic Card #1'), findsWidgets);
        expect(find.textContaining('Custom Mythic Card #5'), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // ------------------------------------------------------------------------
    // Group 2: Empty States vs Active Loading Isolation
    // ------------------------------------------------------------------------
    group('2. Empty States vs Active Loading Isolation', () {
      testWidgets('Empty state renders ONLY when the database genuinely contains 0 cards', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Ensure database is completely empty
        await db.vaultDao.clearAllItems();

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Verify genuine empty state is shown
        expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);
        expect(find.text('Tap below to seed initial mock ledger records or hydrate catalog.'), findsOneWidget);
        expect(find.text('Seed Database'), findsOneWidget);
        expect(find.text('Hydrate MTG Catalog'), findsOneWidget);

        // 2. Tap Seed Database button
        await tester.tap(find.text('Seed Database'));
        await tester.pumpAndSettle();

        // 3. Verify empty state vanishes and cards populate immediately
        expect(find.text('No owned items in Magic: The Gathering'), findsNothing);
        expect(find.textContaining('The One Ring'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Active loading state NEVER flashes empty state before data arrives', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final streamController = StreamController<List<VaultItem>>.broadcast();
        addTearDown(streamController.close);

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
            ],
          ),
        );

        // Pump initial frame while stream has not emitted any data
        await tester.pump();

        // Verify active loading spinner is visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading collection...'), findsOneWidget);

        // Verify empty state is NOT rendered (no false positives while loading)
        expect(find.text('No owned items in Magic: The Gathering'), findsNothing);
        expect(find.text('No catalog cards found'), findsNothing);

        // Now emit cards from the stream
        final now = DateTime.now();
        streamController.add([
          VaultItem(
            id: 'streamed-card-1',
            collectionType: 'mtg',
            name: 'Streamed Mox',
            setOrSeries: 'Vintage Masters',
            imageUrl: 'https://example.com/mox.jpg',
            acquiredPrice: 500.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: false,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            updatedAt: now,
            currentMarketPrice: 600.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        ]);

        await tester.pump();
        await tester.pumpAndSettle();

        // Spinner is gone, card is rendered, empty state is absent
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('Streamed Mox'), findsWidgets);
        expect(find.text('No owned items in Magic: The Gathering'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // ------------------------------------------------------------------------
    // Group 3: Catalog Filter Stress & REF Badges
    // ------------------------------------------------------------------------
    group('3. Catalog Filter Stress & REF Badges', () {
      testWidgets('Toggling between Owned and Catalog (Ref) reveals reference cards with amber REF badges', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // In default Owned mode:
        // Reference cards (quantity == 0) like Mox Diamond or Mana Crypt must NOT be shown
        expect(find.text('Mox Diamond'), findsNothing);
        expect(find.text('Mana Crypt'), findsNothing);
        expect(find.text('UNOWNED'), findsNothing);

        // Find Catalog (Ref) filter chip and tap it
        final catalogChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
        expect(catalogChip, findsOneWidget);
        await tester.tap(catalogChip);
        await tester.pumpAndSettle();

        // In Catalog mode:
        // Reference cards must now appear!
        expect(find.text('Mox Diamond'), findsWidgets);
        expect(find.text('Mana Crypt'), findsWidgets);

        // Verify amber UNOWNED badges appear for unowned reference cards
        final moxBadge = find.byKey(const Key('vault_tile_unowned_badge_item-catalog-mox-diamond'));
        expect(moxBadge, findsOneWidget);
        expect(find.text('UNOWNED'), findsWidgets);

        // Switch back to Owned mode
        final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
        expect(ownedChip, findsOneWidget);
        await tester.tap(ownedChip);
        await tester.pumpAndSettle();

        // Reference cards are filtered out again
        expect(find.text('Mox Diamond'), findsNothing);
        expect(find.text('UNOWNED'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Adversarial discovery: Expanding unowned reference card in List layout surfaces 12px RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Switch to Catalog mode
        final catalogChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
        await tester.tap(catalogChip);
        await tester.pumpAndSettle();

        // 2. Switch to List layout
        final listLayoutButton = find.byKey(const Key('vault_layout_list_button'));
        await tester.tap(listLayoutButton);
        await tester.pumpAndSettle();

        // Verify Mox Diamond card is mounted in list layout
        expect(find.textContaining('Mox Diamond'), findsWidgets);

        // 3. Capture layout overflow exception when expanding the unowned reference card
        final List<FlutterErrorDetails> caughtErrors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details);
        };

        try {
          // Tap the reference card to expand it and reveal the investor/catalog financial row
          await tester.tap(find.textContaining('Mox Diamond').first);
          await tester.pumpAndSettle();

          // Assert the CATALOG / UNOWNED badge rendered
          expect(find.text('CATALOG / UNOWNED'), findsWidgets);

          // Assert that RenderFlex overflow occurred in vault_item_card.dart line 585
          final overflowError = caughtErrors.firstWhere(
            (e) => e.toString().contains('RenderFlex overflowed by 12 pixels'),
            orElse: () => FlutterErrorDetails(exception: Exception('No overflow')),
          );
          expect(overflowError.toString(), contains('RenderFlex overflowed by 12 pixels'));
        } finally {
          FlutterError.onError = originalOnError;
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Rapid stress switching between Owned, Catalog (Ref), and Binders does not crash or corrupt state', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final singlesToggle = find.byKey(const Key('vault_view_singles_toggle'));
        final bindersToggle = find.byKey(const Key('vault_view_binders_toggle'));
        final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
        final catalogChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));

        // Stress toggle 15 cycles (60 UI transitions)
        for (int i = 0; i < 15; i++) {
          await tester.tap(catalogChip);
          await tester.pump(const Duration(milliseconds: 16));

          await tester.tap(bindersToggle);
          await tester.pump(const Duration(milliseconds: 16));

          await tester.tap(singlesToggle);
          await tester.pump(const Duration(milliseconds: 16));

          await tester.tap(ownedChip);
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.pumpAndSettle();

        // Verify application is intact in Singles mode displaying owned cards
        expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsOneWidget);
        expect(find.textContaining('The One Ring'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // ------------------------------------------------------------------------
    // Group 4: Timeout Safeguard & Connection Retry
    // ------------------------------------------------------------------------
    group('4. Timeout Safeguard & Connection Retry', () {
      testWidgets('Delayed or stalled stream gracefully displays Retry Connection button after 5 seconds', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Create a stalled stream that does not emit immediately
        final stalledController = StreamController<List<VaultItem>>.broadcast();
        addTearDown(stalledController.close);

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              vaultItemsStreamProvider.overrideWith((ref) => stalledController.stream),
            ],
          ),
        );

        // Initial pump: loading indicator is shown
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading collection...'), findsOneWidget);
        expect(find.text('Retry Connection'), findsNothing);

        // Advance timer by 4 seconds (under 5s threshold)
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Retry Connection'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Advance timer by 2 more seconds (total 6s, exceeding 5s threshold)
        await tester.pump(const Duration(seconds: 2));

        // Verify timeout safeguard UI has activated
        expect(find.text('Loading is taking longer than usual'), findsOneWidget);
        expect(find.text('The database ledger query or isolate initialization is experiencing delays.'), findsOneWidget);
        final retryButton = find.text('Retry Connection');
        expect(retryButton, findsOneWidget);

        // Tap Retry Connection: verify screen resets to loading spinner
        await tester.tap(retryButton);
        await tester.pump();

        expect(find.text('Loading is taking longer than usual'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading collection...'), findsOneWidget);

        // Now simulate delayed database recovery: emit data
        final now = DateTime.now();
        stalledController.add([
          VaultItem(
            id: 'recovered-card',
            collectionType: 'mtg',
            name: 'Recovered Black Lotus',
            setOrSeries: 'Vintage',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 10000.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: true,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            updatedAt: now,
            currentMarketPrice: 20000.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        ]);

        await tester.pump();
        await tester.pumpAndSettle();

        // Verify data renders cleanly and retry screen disappears
        expect(find.textContaining('Recovered Black Lotus'), findsWidgets);
        expect(find.text('Loading is taking longer than usual'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // ------------------------------------------------------------------------
    // Group 5: Polymorphic Context Switch & Catalog Filtering
    // ------------------------------------------------------------------------
    group('5. Polymorphic Context Switch & Catalog Filtering', () {
      testWidgets('Polymorphic mode shows correct title, category chips, and toggles catalog mode', (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              activeGameContextProvider.overrideWith((ref) => 'Pokémon TCG'),
            ],
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Verify title
        expect(find.text('Pokémon Vault'), findsOneWidget);

        // 2. Verify polymorphic chips are present
        expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
        expect(find.byKey(const Key('vault_filter_chip_catalog_(ref)')), findsOneWidget);
        expect(find.byKey(const Key('vault_filter_chip_graded_slabs')), findsOneWidget);
        expect(find.byKey(const Key('vault_filter_chip_raw_singles')), findsOneWidget);

        // 3. Verify seeded Pokemon card is visible
        expect(find.textContaining('Charizard ex'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  });
}
