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
    Size size = const Size(1200, 900),
    double textScaleFactor = 1.0,
    WidgetTester? tester,
  }) {
    if (tester != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    final overrides = [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => activeGame),
      vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
    ];

    final app = MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: const VaultScreen(),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(container: container, child: app);
    }
    return ProviderScope(overrides: overrides, child: app);
  }

  group('Feature 16: Empirical Adversarial Challenge Suite', () {
    testWidgets('AC1 & AC2: In MTG context, Owned and Catalog chips exist, non-TCG chips are strictly suppressed', (tester) async {
      await tester.pumpWidget(buildVaultApp(activeGame: 'Magic: The Gathering'));
      await tester.pumpAndSettle();

      // Invariants: Owned and Catalog (Ref) MUST exist
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_catalog_(ref)')), findsOneWidget);

      // Invariant: Non-TCG and polymorphic specific chips MUST NOT exist
      expect(find.byKey(const Key('vault_filter_chip_comics')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_sports_cards')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_graded_slabs')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_raw_singles')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_high_p/l')), findsNothing);

      // Invariant: All MTG filter pills MUST exist
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_card_types')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_formats')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_rarity')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_sets')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_foils')), findsOneWidget);
    });

    testWidgets('AC3: In Polymorphic All Collections context, polymorphic chips are rendered and MTG pills suppressed', (tester) async {
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
      expect(find.byKey(const Key('vault_filter_chip_card_types')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_formats')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_rarity')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_sets')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_foils')), findsNothing);
    });

    testWidgets('Alias and Casing Invariance: lowercase mtg and Magic recognize MTG context', (tester) async {
      final aliases = ['mtg', 'Magic', 'MAGIC: THE GATHERING', 'Magic: The Gathering'];
      for (final alias in aliases) {
        await tester.pumpWidget(buildVaultApp(activeGame: alias));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('vault_filter_chip_colors')),
          findsOneWidget,
          reason: 'Failed for alias: $alias',
        );
        expect(
          find.byKey(const Key('vault_filter_chip_comics')),
          findsNothing,
          reason: 'Failed for alias: $alias',
        );
      }
    });

    testWidgets('Non-MTG context (Pokémon TCG, Comic Books) suppresses MTG filters and renders polymorphic filters', (tester) async {
      final nonMtgContexts = ['Pokémon TCG', 'Comic Books', 'Sports Cards'];
      for (final ctx in nonMtgContexts) {
        await tester.pumpWidget(buildVaultApp(activeGame: ctx));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('vault_filter_chip_colors')),
          findsNothing,
          reason: 'MTG color filter leaked in context: $ctx',
        );
        expect(
          find.byKey(const Key('vault_filter_chip_owned')),
          findsOneWidget,
          reason: 'Universal owned filter missing in context: $ctx',
        );
        expect(
          find.byKey(const Key('vault_filter_chip_catalog_(ref)')),
          findsOneWidget,
          reason: 'Universal catalog filter missing in context: $ctx',
        );
      }
    });

    testWidgets('Owned and Catalog (Ref) toggling reliably toggles vaultShowCatalogProvider in MTG mode', (tester) async {
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

      // Initially owned is selected
      expect(container.read(vaultShowCatalogProvider), isFalse);

      // Tap Catalog (Ref)
      await tester.tap(find.byKey(const Key('vault_filter_chip_catalog_(ref)')));
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isTrue);

      // Tap Owned
      await tester.tap(find.byKey(const Key('vault_filter_chip_owned')));
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isFalse);
    });

    testWidgets('Owned and Catalog (Ref) toggling reliably toggles vaultShowCatalogProvider in Polymorphic mode', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container));
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isFalse);

      // Tap Catalog (Ref)
      await tester.tap(find.byKey(const Key('vault_filter_chip_catalog_(ref)')));
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isTrue);

      // Tap Comics (index 4) - should switch showCatalog back to false
      await tester.tap(find.byKey(const Key('vault_filter_chip_comics')));
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isFalse);
    });

    testWidgets('Collection switching via PopupMenu resets filter index and synchronizes game context', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container));
      await tester.pumpAndSettle();

      // Select Comics chip in All Collections mode
      await tester.tap(find.byKey(const Key('vault_filter_chip_comics')));
      await tester.pumpAndSettle();

      // Open collection selector popup menu
      await tester.tap(find.byTooltip('Select Vault Collection'));
      await tester.pumpAndSettle();

      // Select Magic: The Gathering
      await tester.tap(find.text('Magic: The Gathering').last);
      await tester.pumpAndSettle();

      // Game context switched
      expect(container.read(activeGameContextProvider), equals('Magic: The Gathering'));

      // Filter chips now render MTG pills
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_comics')), findsNothing);

      // Owned chip is selected
      expect(container.read(vaultShowCatalogProvider), isFalse);
    });

    testWidgets('Quick Modals: Mana Value range selection, active pill styling, and clear action', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container, size: const Size(1200, 800), tester: tester));
      await tester.pumpAndSettle();

      // Tap Mana Value pill
      await tester.tap(find.byKey(const Key('vault_filter_chip_mana_value')));
      await tester.pumpAndSettle();

      expect(find.text('Mana Value (CMC)'), findsOneWidget);

      // Tap choice chip '3'
      await tester.tap(find.widgetWithText(ChoiceChip, '3'));
      await tester.pumpAndSettle();

      // Close modal by tapping Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Pill label updated
      expect(find.text('CMC 3-3'), findsOneWidget);
      expect(container.read(mtgFilterProvider).cmcRange, equals(const RangeValues(3, 3)));

      // Tap clear 'X' icon specifically on mana value pill
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault_filter_chip_mana_value')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mana Value ▾'), findsOneWidget);
      expect(container.read(mtgFilterProvider).cmcRange, equals(const RangeValues(0, 16)));
    });

    testWidgets('Quick Modals: Card Types selection, active pill styling, and clear action', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container, size: const Size(1200, 800), tester: tester));
      await tester.pumpAndSettle();

      // Tap Card Types pill
      await tester.tap(find.byKey(const Key('vault_filter_chip_card_types')));
      await tester.pumpAndSettle();

      expect(find.text('Card Types'), findsOneWidget);

      // Tap 'Instant' chip
      await tester.tap(find.widgetWithText(FilterChip, 'Instant'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Type: Instant'), findsOneWidget);
      expect(container.read(mtgFilterProvider).typeLine, equals('Instant'));

      // Tap clear specifically on card types pill
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault_filter_chip_card_types')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card Types ▾'), findsOneWidget);
      expect(container.read(mtgFilterProvider).typeLine, isEmpty);
    });

    testWidgets('Quick Modals: Format Legality selection, active pill styling, and clear action', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container, size: const Size(1200, 800), tester: tester));
      await tester.pumpAndSettle();

      // Tap Formats pill
      await tester.tap(find.byKey(const Key('vault_filter_chip_formats')));
      await tester.pumpAndSettle();

      expect(find.text('Format Legality'), findsOneWidget);

      // Tap 'Commander' chip
      await tester.tap(find.widgetWithText(FilterChip, 'Commander'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Format: commander'), findsOneWidget);
      expect(container.read(mtgFilterProvider).formats, contains('commander'));

      // Tap clear specifically on formats pill
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault_filter_chip_formats')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Formats ▾'), findsOneWidget);
      expect(container.read(mtgFilterProvider).formats, isEmpty);
    });

    testWidgets('Quick Modals: Rarity, Sets, and Foils selection and clear actions', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultApp(container: container, size: const Size(1400, 900), tester: tester));
      await tester.pumpAndSettle();

      // Rarity
      await tester.tap(find.byKey(const Key('vault_filter_chip_rarity')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Rare'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Rarity (1)'), findsOneWidget);
      expect(container.read(mtgFilterProvider).rarities, contains('rare'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault_filter_chip_rarity')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rarity ▾'), findsOneWidget);

      // Sets
      await tester.tap(find.byKey(const Key('vault_filter_chip_sets')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'MH3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Set: MH3'), findsOneWidget);
      expect(container.read(mtgFilterProvider).setCode, equals('MH3'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault_filter_chip_sets')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sets ▾'), findsOneWidget);

      // Foils
      await tester.tap(find.byKey(const Key('vault_filter_chip_foils')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Foil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Foils (foil)'), findsOneWidget);
      expect(container.read(mtgFilterProvider).finishes, contains('foil'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault_filter_chip_foils')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foils ▾'), findsOneWidget);
    });

    testWidgets('Ultra-Narrow 320x568 Viewport with 2.0x font scaling: zero overflows', (tester) async {
      await tester.pumpWidget(
        buildVaultApp(
          activeGame: 'Magic: The Gathering',
          size: const Size(320, 568),
          textScaleFactor: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Drag horizontally across the filter chips row
      await tester.drag(find.byKey(const Key('vault_filter_chip_colors')), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
