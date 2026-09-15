import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/polymorphic_attribute_chip.dart';

void main() {
  group('Countr Comprehensive System & Integration Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.seedDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
        'VaultScreen interactive search dynamically filters cards and restores on clear',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 4 seeded cards should be visible initially
      expect(find.textContaining('The One Ring'), findsOneWidget);
      expect(find.textContaining('Charizard ex'), findsOneWidget);
      expect(find.textContaining('Ultimate Fallout #4'), findsOneWidget);
      expect(find.textContaining('T.J. Watt'), findsOneWidget);

      // Search for "Charizard"
      await tester.enterText(find.byType(TextField), 'Charizard');
      await tester.pumpAndSettle();

      // Only Charizard ex is displayed
      expect(find.textContaining('Charizard ex'), findsOneWidget);
      expect(find.textContaining('The One Ring'), findsNothing);
      expect(find.textContaining('Ultimate Fallout #4'), findsNothing);
      expect(find.textContaining('T.J. Watt'), findsNothing);

      // Search for nonexistent card
      await tester.enterText(find.byType(TextField), 'Nonexistent Card Name XYZ');
      await tester.pumpAndSettle();

      expect(find.text('No owned items in All Collections'), findsOneWidget);

      // Tap clear button on TextField
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All 4 cards restored
      expect(find.textContaining('The One Ring'), findsOneWidget);
      expect(find.textContaining('Charizard ex'), findsOneWidget);

      // Flush test timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
        'VaultScreen filter chips accurately isolate Graded Slabs, Raw Singles, and High P/L',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter: Graded Slabs (Index 2)
      await tester.ensureVisible(find.text('Graded Slabs'));
      await tester.tap(find.text('Graded Slabs'));
      await tester.pumpAndSettle();

      // Only graded items: Ultimate Fallout #4 (CGC 9.8) and T.J. Watt (PSA 10)
      expect(find.textContaining('Ultimate Fallout #4'), findsOneWidget);
      expect(find.textContaining('T.J. Watt'), findsOneWidget);
      expect(find.textContaining('The One Ring'), findsNothing);
      expect(find.textContaining('Charizard ex'), findsNothing);

      // Filter: Raw Singles (Index 3)
      await tester.ensureVisible(find.text('Raw Singles'));
      await tester.tap(find.text('Raw Singles'));
      await tester.pumpAndSettle();

      // Only raw items: The One Ring and Charizard ex
      expect(find.textContaining('The One Ring'), findsOneWidget);
      expect(find.textContaining('Charizard ex'), findsOneWidget);
      expect(find.textContaining('Ultimate Fallout #4'), findsNothing);
      expect(find.textContaining('T.J. Watt'), findsNothing);

      // Filter: High P/L (Index 5)
      // Ultimate Fallout (+40%), One Ring (+203%), TJ Watt (+800%) are profit.
      // Charizard ex (-27.8%) is loss.
      await tester.ensureVisible(find.text('High P/L'));
      await tester.tap(find.text('High P/L'));
      await tester.pumpAndSettle();

      expect(find.textContaining('The One Ring'), findsOneWidget);
      expect(find.textContaining('Ultimate Fallout #4'), findsOneWidget);
      expect(find.textContaining('T.J. Watt'), findsOneWidget);
      expect(find.textContaining('Charizard ex'), findsNothing);

      // Flush test timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ScannerModal toggles flash and switches scan modes cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScannerModal(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially flash is off
      expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flash_on_rounded), findsNothing);

      // Toggle flash on
      await tester.tap(find.byIcon(Icons.flash_off_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);

      // Toggle flash off
      await tester.tap(find.byIcon(Icons.flash_on_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);

      // Switch scan modes: ChoiceChips
      expect(find.text('RAW CARD'), findsOneWidget);
      expect(find.text('SLAB / GRADED'), findsOneWidget);
      expect(find.text('COMIC BOOK'), findsOneWidget);
      expect(find.text('BARCODE'), findsOneWidget);

      // Select 'SLAB / GRADED'
      await tester.tap(find.text('SLAB / GRADED'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select 'BARCODE'
      await tester.tap(find.text('BARCODE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PostActionBar handles hype and wishlist toggles with state updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostActionBar(
              initialHypeCount: 10,
              commentCount: 5,
              initialIsHyped: false,
              initialIsWishlisted: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HYPE (10)'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Tap HYPE -> count increments to 11
      await tester.tap(find.text('HYPE (10)'));
      await tester.pumpAndSettle();

      expect(find.text('HYPE (11)'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Tap WISHLIST -> toggles bookmark and shows SnackBar
      await tester.tap(find.text('WISHLIST'));
      await tester.pumpAndSettle();

      expect(find.text('Added to Wishlist'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    test('VaultDao supports pagination with limit and offset', () async {
      // 4 items exist. Query limit 2, offset 0
      final page1 = await db.vaultDao.watchItemsByCollection(
        'all',
        limit: 2,
        offset: 0,
      ).first;

      expect(page1.length, 2);

      // Query limit 2, offset 2
      final page2 = await db.vaultDao.watchItemsByCollection(
        'all',
        limit: 2,
        offset: 2,
      ).first;

      expect(page2.length, 2);

      // Verify no overlap between page 1 and page 2
      final page1Ids = page1.map((i) => i.id).toSet();
      final page2Ids = page2.map((i) => i.id).toSet();
      expect(page1Ids.intersection(page2Ids).isEmpty, isTrue);
    });

    test('VaultDao clearAllItems deletes all items and seedDatabase restores them',
        () async {
      final initial = await db.vaultDao.watchItemsByCollection('all').first;
      expect(initial.length, 4);

      // Clear all
      final deleted = await db.vaultDao.clearAllItems();
      expect(deleted, 4);

      final empty = await db.vaultDao.watchItemsByCollection('all').first;
      expect(empty.isEmpty, isTrue);

      // Reseed
      await db.vaultDao.seedDatabase();
      final restored = await db.vaultDao.watchItemsByCollection('all').first;
      expect(restored.length, 4);
    });

    testWidgets('PolymorphicAttributeChip handles empty or malformed JSON gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PolymorphicAttributeChip(
                  collectionType: 'mtg',
                  dynamicDataJson: 'invalid json syntax',
                ),
                PolymorphicAttributeChip(
                  collectionType: 'pokemon',
                  dynamicDataJson: '{}',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Malformed MTG JSON renders placeholder cleanly without throw
      expect(find.text('MTG STATS: '), findsOneWidget);
      expect(find.text('N/A • Card'), findsOneWidget);

      // Empty Pokemon JSON renders placeholder cleanly
      expect(find.text('POKÉMON STATS: '), findsOneWidget);
      expect(find.text('HP N/A • Stage: Standard'), findsOneWidget);
    });

    test('ScryfallStreamingParser parseStream handles empty stream and split chunks',
        () async {
      final parser = ScryfallStreamingParser();

      // 1. Empty stream
      final emptyStream = Stream<List<int>>.fromIterable([]);
      final emptyChunks = await parser.parseStream(emptyStream).toList();
      expect(emptyChunks.isEmpty, isTrue);

      // 2. Split JSON chunk stream across multi-character boundaries
      final cardJson = jsonEncode({
        'id': 'split-01',
        'name': 'Black Lotus',
        'set_name': 'Alpha',
        'prices': {'usd': '50000.0'},
      });
      final jsonArray = '[$cardJson]';

      // Split into 3-byte slices to test parser token assembly across chunk boundaries
      final bytes = utf8.encode(jsonArray);
      final chunks = <List<int>>[];
      for (var i = 0; i < bytes.length; i += 3) {
        final end = (i + 3 < bytes.length) ? i + 3 : bytes.length;
        chunks.add(bytes.sublist(i, end));
      }

      final splitStream = Stream<List<int>>.fromIterable(chunks);
      final emittedChunks = await parser.parseStream(splitStream).toList();
      final companions = emittedChunks.expand((c) => c).toList();

      expect(companions.length, 1);
      expect(companions.first.name.value, 'Black Lotus');
      expect(companions.first.currentMarketPrice.value, 50000.0);
    });
  });
}
