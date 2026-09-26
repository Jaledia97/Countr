import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildVaultApp({
    String activeGame = 'Magic: The Gathering',
    ProviderContainer? container,
  }) {
    final overrides = [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => activeGame),
      vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
    ];

    final app = MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: const VaultScreen(),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(container: container, child: app);
    }
    return ProviderScope(overrides: overrides, child: app);
  }

  group('Feature 16: Context-Aware Category Filter Pills Tests', () {
    testWidgets('1. MTG context renders MTG pills and strictly suppresses Comics and Sports Cards', (tester) async {
      await tester.pumpWidget(buildVaultApp(activeGame: 'Magic: The Gathering'));
      await tester.pumpAndSettle();

      // Universal base pills
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_catalog_(ref)')), findsOneWidget);

      // MTG specific pills
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_card_types')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_formats')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_rarity')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_sets')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_foils')), findsOneWidget);

      // Suppressed non-TCG category pills
      expect(find.byKey(const Key('vault_filter_chip_comics')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_sports_cards')), findsNothing);
    });

    testWidgets('2. Polymorphic context renders full category pills and suppresses MTG pills', (tester) async {
      await tester.pumpWidget(buildVaultApp(activeGame: 'All Collections'));
      await tester.pumpAndSettle();

      // Universal base pills
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_catalog_(ref)')), findsOneWidget);

      // Polymorphic category pills
      expect(find.byKey(const Key('vault_filter_chip_graded_slabs')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_raw_singles')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_comics')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_sports_cards')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_high_p/l')), findsOneWidget);

      // Suppressed MTG pills
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_formats')), findsNothing);
    });

    testWidgets('3. Colors quick modal opens, toggles color, updates label, and clears', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container));
      await tester.pumpAndSettle();

      // Open Colors quick modal
      await tester.tap(find.byKey(const Key('vault_filter_chip_colors')));
      await tester.pumpAndSettle();

      expect(find.text('Colors & Identity'), findsOneWidget);

      // Tap Blue (U)
      await tester.tap(find.byKey(const Key('quick_filter_color_U')));
      await tester.pumpAndSettle();

      // Verify provider updated
      expect(container.read(mtgFilterProvider).colors, contains('U'));

      // Dismiss modal by tapping Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Verify pill label updated
      expect(find.text('Colors (U)'), findsOneWidget);

      // Tap clear 'X' icon to reset
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify colors reset in provider and pill label
      expect(container.read(mtgFilterProvider).colors, isEmpty);
      expect(find.text('Colors ▾'), findsOneWidget);
    });

    testWidgets('4. Formats legality evaluation matches in MtgFilterState', (tester) async {
      const state = MtgFilterState(formats: {'commander'});
      expect(state.isActive, isTrue);
      expect(state.activeCount, equals(1));

      final legalCard = VaultItem(
        id: 'legal-1',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: '',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"legalities":{"commander":"legal","standard":"not_legal"}}',
      );

      final illegalCard = VaultItem(
        id: 'illegal-1',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'Alpha',
        imageUrl: '',
        acquiredPrice: 1000.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 50000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"legalities":{"commander":"banned","vintage":"restricted"}}',
      );

      expect(state.matches(legalCard), isTrue);
      expect(state.matches(illegalCard), isFalse);
    });
  });
}
