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

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildVaultHarness({
    required ProviderContainer container,
    Size viewportSize = const Size(390, 844),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: viewportSize),
          child: child!,
        ),
        home: const VaultScreen(),
      ),
    );
  }

  group('Milestone 4 - Feature 20: Vault AppBar Relocation in "All Cards"', () {
    testWidgets('in "All Cards" mode, search & filter buttons render in AppBar directly left of Import with unique keys', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => true), // All Cards mode
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      final searchButtonFinder = find.byKey(const Key('vault_search_expand_button'));
      final filterButtonFinder = find.byKey(const Key('vault_mtg_filter_button'));
      final importButtonFinder = find.byKey(const Key('vault_import_button'));
      final appBarFinder = find.byType(AppBar);

      // Exactly 1 instance of each button exists in the entire widget tree
      expect(searchButtonFinder, findsOneWidget);
      expect(filterButtonFinder, findsOneWidget);
      expect(importButtonFinder, findsOneWidget);

      // Both buttons are descendants of AppBar
      expect(find.descendant(of: appBarFinder, matching: searchButtonFinder), findsOneWidget);
      expect(find.descendant(of: appBarFinder, matching: filterButtonFinder), findsOneWidget);
      expect(find.descendant(of: appBarFinder, matching: importButtonFinder), findsOneWidget);

      // Verify horizontal arrangement: search < filter < import
      final searchX = tester.getTopLeft(searchButtonFinder).dx;
      final filterX = tester.getTopLeft(filterButtonFinder).dx;
      final importX = tester.getTopLeft(importButtonFinder).dx;

      expect(searchX < filterX, isTrue, reason: 'Search button must be left of filter button');
      expect(filterX < importX, isTrue, reason: 'Filter button must be directly left of import button');

      // Tapping search expands the search text field
      await tester.tap(searchButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);

      // Subtab AnimatedOpacity remains with opacity 0.0 and duration 200ms
      final animatedOpacityFinder = find.byWidgetPredicate(
        (w) => w is AnimatedOpacity && w.opacity == 0.0 && w.duration == const Duration(milliseconds: 200),
      );
      expect(animatedOpacityFinder, findsOneWidget);
    });

    testWidgets('in "Owned" mode, search & filter render in body controls bar, not in AppBar', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => false), // Owned mode
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      final searchButtonFinder = find.byKey(const Key('vault_search_expand_button'));
      final filterButtonFinder = find.byKey(const Key('vault_mtg_filter_button'));
      final importButtonFinder = find.byKey(const Key('vault_import_button'));
      final appBarFinder = find.byType(AppBar);

      // Exactly 1 instance of each button exists in the widget tree
      expect(searchButtonFinder, findsOneWidget);
      expect(filterButtonFinder, findsOneWidget);
      expect(importButtonFinder, findsOneWidget);

      // Search & filter are NOT in AppBar
      expect(find.descendant(of: appBarFinder, matching: searchButtonFinder), findsNothing);
      expect(find.descendant(of: appBarFinder, matching: filterButtonFinder), findsNothing);
      expect(find.descendant(of: appBarFinder, matching: importButtonFinder), findsOneWidget);
    });
  });

  group('Milestone 4 - Feature 23: Pill Bar ↑↓ Sort Selector', () {
    testWidgets('renders sort button on pill bar with ↑↓ and swap icon', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      final sortButtonFinder = find.byKey(const Key('vault_sort_button'));
      expect(sortButtonFinder, findsOneWidget);

      // Check text and icon inside sort button
      expect(find.descendant(of: sortButtonFinder, matching: find.text('↑↓')), findsOneWidget);
      expect(find.descendant(of: sortButtonFinder, matching: find.byIcon(Icons.swap_vert_rounded)), findsOneWidget);

      // Positioned adjacent to layout switcher
      final layoutListFinder = find.byKey(const Key('vault_layout_list_button'));
      expect(layoutListFinder, findsOneWidget);

      final sortX = tester.getTopLeft(sortButtonFinder).dx;
      final layoutX = tester.getTopLeft(layoutListFinder).dx;
      expect(layoutX < sortX, isTrue, reason: 'Sort button is pinned directly to right of layout switcher');
    });

    testWidgets('tapping sort button opens bottom modal with all 7 sort options', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      // Tap sort button
      await tester.tap(find.byKey(const Key('vault_sort_button')));
      await tester.pumpAndSettle();

      // Check all 7 sort options in the modal
      expect(find.byKey(const Key('vault_sort_reputation_highest')), findsOneWidget);
      expect(find.byKey(const Key('vault_sort_reputation_lowest')), findsOneWidget);
      expect(find.byKey(const Key('vault_sort_price_high_low')), findsOneWidget);
      expect(find.byKey(const Key('vault_sort_price_low_high')), findsOneWidget);
      expect(find.byKey(const Key('vault_sort_name_a_z')), findsOneWidget);
      expect(find.byKey(const Key('vault_sort_mana_value_cmc')), findsOneWidget);
      expect(find.byKey(const Key('vault_sort_release_date')), findsOneWidget);

      expect(find.text('Reputation (Highest Upvoted)'), findsOneWidget);
      expect(find.text('Reputation (Lowest/Controversial)'), findsOneWidget);
      expect(find.text('Price: High-Low'), findsOneWidget);
      expect(find.text('Price: Low-High'), findsOneWidget);
      expect(find.text('Name: A-Z'), findsOneWidget);
      expect(find.text('Mana Value (CMC)'), findsOneWidget);
      expect(find.text('Release Date'), findsOneWidget);

      // Tap Reputation (Highest Upvoted)
      await tester.tap(find.byKey(const Key('vault_sort_reputation_highest')));
      await tester.pumpAndSettle();

      // Modal is dismissed
      expect(find.byKey(const Key('vault_sort_reputation_highest')), findsNothing);

      // Provider state is updated
      expect(container.read(vaultSortOptionProvider), equals(VaultSortOption.reputationHighest));

      // Re-open and select Reputation (Lowest/Controversial)
      await tester.tap(find.byKey(const Key('vault_sort_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vault_sort_reputation_lowest')));
      await tester.pumpAndSettle();

      expect(container.read(vaultSortOptionProvider), equals(VaultSortOption.reputationLowest));
    });
  });
}
