import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';

/// Spy VaultDao to record search queries and monitor race conditions / duplicate queries
class SpyVaultDao extends VaultDao {
  final List<String> recordedQueries = [];
  int simulatedDelayMs = 0;

  SpyVaultDao(super.db);

  @override
  Future<List<VaultItem>> searchCatalogCards(
    String query, {
    String? collectionType,
    int limit = 50,
  }) async {
    recordedQueries.add(query);
    if (simulatedDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: simulatedDelayMs));
    }
    return super.searchCatalogCards(query, collectionType: collectionType, limit: limit);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SpyVaultDao spyDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    spyDao = SpyVaultDao(db);
    await spyDao.seedDatabase();

    // Insert multiple catalog cards for multi-item stress testing
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-sol-ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander Masters',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 2.50,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'rarity': 'uncommon',
              'type': 'Artifact',
            }),
          ),
        );

    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-black-lotus',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'Limited Edition Alpha',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'rarity': 'rare',
              'type': 'Artifact',
            }),
          ),
        );

    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-mox-pearl',
            collectionType: 'mtg',
            name: 'Mox Pearl',
            setOrSeries: 'Limited Edition Beta',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 4500.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'rarity': 'rare',
              'type': 'Artifact',
            }),
          ),
        );

    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-lightning-bolt',
            collectionType: 'mtg',
            name: 'Lightning Bolt',
            setOrSeries: 'Magic 2010',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 1.25,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'rarity': 'common',
              'type': 'Instant',
            }),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    Widget? child,
    String activeGame = 'Magic: The Gathering',
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(spyDao),
        activeGameContextProvider.overrideWith((ref) => activeGame),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child ?? const ManualAddBottomSheet(),
        ),
      ),
    );
  }

  group('Adversarial Interaction Challenge 1: Rapid Stepper Stress & Concurrency', () {
    testWidgets('Rapidly taps + and - steppers on single item (25 increments, 10 decrements)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final incBtn = find.byKey(const Key('stepper_increment_catalog-sol-ring'));
      final decBtn = find.byKey(const Key('stepper_decrement_catalog-sol-ring'));

      expect(incBtn, findsOneWidget);
      expect(decBtn, findsOneWidget);

      // Rapidly tap increment 25 times
      for (int i = 0; i < 25; i++) {
        await tester.tap(incBtn);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // Verify count is exactly 25
      expect(find.text('25'), findsOneWidget);
      expect(find.text('Add 25 Items to Vault'), findsOneWidget);

      // Rapidly tap decrement 10 times
      for (int i = 0; i < 10; i++) {
        await tester.tap(decBtn);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // Verify count is exactly 15
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Add 15 Items to Vault'), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Rapidly alternates taps across multiple items without state collision or negative counts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final incSolRing = find.byKey(const Key('stepper_increment_catalog-sol-ring'));
      final decSolRing = find.byKey(const Key('stepper_decrement_catalog-sol-ring'));
      final incLotus = find.byKey(const Key('stepper_increment_catalog-black-lotus'));
      final decLotus = find.byKey(const Key('stepper_decrement_catalog-black-lotus'));
      final incMox = find.byKey(const Key('stepper_increment_catalog-mox-pearl'));
      final decMox = find.byKey(const Key('stepper_decrement_catalog-mox-pearl'));

      // Interleaved rapid additions
      for (int i = 0; i < 10; i++) {
        await tester.tap(incSolRing);
        await tester.tap(incLotus);
        await tester.tap(incMox);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // 10 Sol Ring + 10 Black Lotus + 10 Mox Pearl = 30 total
      expect(find.text('Add 30 Items to Vault'), findsOneWidget);

      // Rapidly decrement Lotus by 15 (more than 10)
      for (int i = 0; i < 15; i++) {
        await tester.tap(decLotus);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpAndSettle();

      // Lotus must be clamped at 0 (not negative). Total remaining: 10 + 0 + 10 = 20
      expect(find.text('Add 20 Items to Vault'), findsOneWidget);
      expect(find.byKey(const Key('stepper_count_catalog-black-lotus')), findsOneWidget);

      // Decrement Sol Ring by 10 and Mox by 10 -> all reach 0
      for (int i = 0; i < 10; i++) {
        await tester.tap(decSolRing);
        await tester.tap(decMox);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpAndSettle();

      // Staged count is 0 -> sticky action bar must be hidden
      expect(find.byKey(const Key('bulk_add_submit_button')), findsNothing);

      // Tapping decrement when 0 does not throw exception or decrement to -1
      await tester.tap(decSolRing);
      await tester.tap(decLotus);
      await tester.tap(decMox);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk_add_submit_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Staged counts persist across search queries and reappear when search clears',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // 1. Stage 4 Sol Rings
      final incSolRing = find.byKey(const Key('stepper_increment_catalog-sol-ring'));
      for (int i = 0; i < 4; i++) {
        await tester.tap(incSolRing);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      expect(find.text('Add 4 Items to Vault'), findsOneWidget);

      // 2. Search for 'Lotus' -> Sol Ring disappears from visible list
      await tester.enterText(find.byType(SearchField), 'Lotus');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Sol Ring'), findsNothing);
      expect(find.text('Black Lotus'), findsOneWidget);
      // Sticky action bar still displays 4 staged items!
      expect(find.text('Add 4 Items to Vault'), findsOneWidget);

      // 3. Stage 2 Black Lotus
      final incLotus = find.byKey(const Key('stepper_increment_catalog-black-lotus'));
      await tester.tap(incLotus);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(incLotus);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      // Total is now 4 + 2 = 6 items
      expect(find.text('Add 6 Items to Vault'), findsOneWidget);

      // 4. Clear search query
      await tester.tap(find.byKey(const Key('search_field_clear_button')));
      await tester.pumpAndSettle();

      // Both Sol Ring and Black Lotus are visible with their exact staged counts
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.byKey(const Key('stepper_count_catalog-sol-ring')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byKey(const Key('stepper_count_catalog-black-lotus')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Add 6 Items to Vault'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Double-tapping + stepper without intervening frame pump increments properly without stale closure loss',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final incSolRing = find.byKey(const Key('stepper_increment_catalog-sol-ring'));

      // Tapping + twice rapidly in the same frame tick (without intervening pump)
      await tester.tap(incSolRing);
      await tester.tap(incSolRing);
      await tester.pumpAndSettle();

      // Since _buildStepper queries live `_stagedQuantities[card.id]` dynamically,
      // consecutive taps increment properly without dropping inputs.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Add 2 Items to Vault'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Adversarial Interaction Challenge 2: Debounce & Search Keystroke Concurrency', () {
    testWidgets('Typing rapidly within 300ms debounce window triggers exactly ONE search query (no duplicate queries)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Initial search was called on initState
      expect(spyDao.recordedQueries, ['']);
      spyDao.recordedQueries.clear();

      final searchField = find.byType(SearchField);

      // Rapidly simulate 5 keystrokes spaced 40ms apart (total elapsed: 200ms < 300ms)
      await tester.enterText(searchField, 'B');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(searchField, 'Bl');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(searchField, 'Bla');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(searchField, 'Blac');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(searchField, 'Black');
      await tester.pump(const Duration(milliseconds: 40));

      // At this point, 200ms elapsed since last keystroke. Debounce timer should NOT have fired yet.
      expect(spyDao.recordedQueries, isEmpty);

      // Advance by another 150ms (total 190ms since last key) -> still < 300ms
      await tester.pump(const Duration(milliseconds: 150));
      expect(spyDao.recordedQueries, isEmpty);

      // Now advance past the 300ms debounce threshold (e.g. 200ms more)
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Exactly ONE search query was triggered with the final query "Black"
      expect(spyDao.recordedQueries, ['Black']);
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Sol Ring'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Backspacing and rapid replacement cancels intermediate timer cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      spyDao.recordedQueries.clear();

      final searchField = find.byType(SearchField);

      // Type "Sol"
      await tester.enterText(searchField, 'Sol');
      await tester.pump(const Duration(milliseconds: 150));

      // Backspace before debounce expires
      await tester.enterText(searchField, 'So');
      await tester.pump(const Duration(milliseconds: 150));

      // Replace with "Lightning"
      await tester.enterText(searchField, 'Lightning');

      // Now wait 350ms for debounce to expire
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // "Sol" and "So" should NEVER have queried SQLite!
      expect(spyDao.recordedQueries, ['Lightning']);
      expect(find.text('Lightning Bolt'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Adversarial Interaction Challenge 3: Dismissal & Fresh State Integrity', () {
    testWidgets('Dismissing sheet without adding discards staged items and keeps database pristine',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(spyDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('trigger_open_sheet'),
                  onPressed: () => ManualAddBottomSheet.show(context),
                  child: const Text('Open Manual Add'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const Key('trigger_open_sheet')));
      await tester.pumpAndSettle();

      expect(find.byType(ManualAddBottomSheet), findsOneWidget);

      // Stage 3 Sol Rings and 2 Black Lotuses
      final incSol = find.byKey(const Key('stepper_increment_catalog-sol-ring'));
      final incLotus = find.byKey(const Key('stepper_increment_catalog-black-lotus'));

      for (int i = 0; i < 3; i++) {
        await tester.tap(incSol);
        await tester.pump(const Duration(milliseconds: 10));
      }
      for (int i = 0; i < 2; i++) {
        await tester.tap(incLotus);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(find.text('Add 5 Items to Vault'), findsOneWidget);

      // Dismiss sheet via close button
      await tester.tap(find.byKey(const Key('manual_add_close_button')));
      await tester.pumpAndSettle();

      // Bottom sheet is dismissed
      expect(find.byType(ManualAddBottomSheet), findsNothing);

      // Verify SQLite state: database was NOT modified!
      final solRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-sol-ring')))
          .getSingle();
      final lotus = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-black-lotus')))
          .getSingle();

      expect(solRing.quantity, 0);
      expect(lotus.quantity, 0);

      // Re-open the sheet
      await tester.tap(find.byKey(const Key('trigger_open_sheet')));
      await tester.pumpAndSettle();

      // Fresh state verification:
      // 1. Sheet is open
      expect(find.byType(ManualAddBottomSheet), findsOneWidget);
      // 2. Sticky action bar is NOT visible
      expect(find.byKey(const Key('bulk_add_submit_button')), findsNothing);
      // 3. Stepper counts are reset to 0
      expect(find.byKey(const Key('stepper_count_catalog-sol-ring')), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      // 4. Default cards are reloaded
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);

      // Dismiss and clean up
      await tester.tap(find.byKey(const Key('manual_add_close_button')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Adversarial Interaction Challenge 4: Narrow Viewport Responsiveness & Layout Constraint Stress', () {
    testWidgets('Narrow viewport (360x740) renders cleanly with ZERO RenderFlex overflows',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Stage an item so sticky action bar is active
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk_add_submit_button')), findsOneWidget);

      // Verify that Flutter caught ZERO RenderFlex overflow errors on 360px viewport
      final overflowErrors = caughtErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(overflowErrors, isEmpty,
          reason: '360px viewport must have zero RenderFlex overflows');

      expect(find.text('Add Cards to Vault'), findsOneWidget);
      expect(find.text('Unsorted (Main Vault)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Ultra-narrow viewport (320x640) renders cleanly with ZERO RenderFlex overflows on standard items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Add Cards to Vault'), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);

      // Stage an item to display action bar at 320px width
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk_add_submit_button')), findsOneWidget);

      // Verify that Flutter caught ZERO RenderFlex overflow errors on 320px viewport
      final overflowErrors = caughtErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(overflowErrors, isEmpty,
          reason: '320px viewport must have zero RenderFlex overflows');

      expect(find.text('Add Cards to Vault'), findsOneWidget);
      expect(find.text('Unsorted (Main Vault)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Narrow viewport (320x640) with custom long binder name renders cleanly with ZERO RenderFlex overflows and hit-tests successfully',
        (WidgetTester tester) async {
      // Insert a binder with a long name
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-long-name',
              name: 'Vintage Masterpieces & Reserved List Collector Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Stage an item so sticky action bar and binder selector appear
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();

      // Verify ZERO layout overflow occurred despite long binder name
      final overflowErrors = caughtErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(overflowErrors, isEmpty,
          reason: 'Long binder name must not trigger RenderFlex overflow in selector');

      // Dropdown button should be tappable within viewport bounds
      expect(find.text('Unsorted (Main Vault)'), findsOneWidget);
      await tester.tap(find.text('Unsorted (Main Vault)'));
      await tester.pumpAndSettle();

      expect(find.text('Vintage Masterpieces & Reserved List Collector Binder').last, findsOneWidget);
      await tester.tap(find.text('Vintage Masterpieces & Reserved List Collector Binder').last);
      await tester.pumpAndSettle();

      expect(find.text('Vintage Masterpieces & Reserved List Collector Binder'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
