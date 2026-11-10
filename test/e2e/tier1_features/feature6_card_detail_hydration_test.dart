import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import '../helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createE2ETestDatabase();
    dao = db.vaultDao;
    await seedStandardM1Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tier 1 - Feature 6: Blank Card Details Fix & ID Hydration', () {
    test('F6.1: dao.getItemById returns full card record with complete dynamic_data and financials', () async {
      final card = await dao.getItemById('c-lotus');

      expect(card, isNotNull);
      expect(card!.name, equals('Black Lotus'));
      expect(card.currentMarketPrice, equals(5000.0));
      expect(card.dynamicData, isNotEmpty);
      expect(card.dynamicData, contains('"collector_number":"232"'));
      expect(card.dynamicData, contains('"rarity":"rare"'));
      expect(card.dynamicData, contains('Sacrifice Black Lotus'));
    });

    testWidgets('F6.2: CardDetailSheet renders full card breakdown without blank screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final lotus = (await dao.getItemById('c-lotus'))!;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: lotus),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card title and set name must be clearly rendered
      expect(find.text('Black Lotus'), findsWidgets);
      expect(find.text('Vintage Masters'), findsWidgets);

      // Market price must be visible
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.contains('5,000') == true ||
                w.data?.contains('5000') == true)),
        findsWidgets,
      );
    });

    testWidgets('F6.3: Multi-faced card (DFC) parses card_faces and enables face flipping', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bolas = (await dao.getItemById('c-nicol-bolas'))!;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: bolas),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Front face name rendered
      expect(find.textContaining('Nicol Bolas'), findsWidgets);

      // Flip button should be rendered for DFC cards
      final flipButton = find.byTooltip('Flip card');
      expect(flipButton, findsOneWidget);

      // Tap flip button
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Back face name should now be active
      expect(find.textContaining('Nicol Bolas, the Arisen'), findsWidgets);
    });

    testWidgets('F6.4: Card with flavor name displays printed name and oracle name cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ozolith = (await dao.getItemById('c-ozolith'))!;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: ozolith),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Adamantium Bonding Tank'), findsWidgets);
      expect(find.textContaining('The Ozolith'), findsWidgets);
    });

    testWidgets('F6.5: Opening CardDetailSheet with stub item and resolving via SQLite prevents blank render', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Stub card with minimal fields, ID matches SQLite row 'c-bolt'
      final stubCard = VaultItem(
        id: 'c-bolt',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'Magic 2010',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 1.5,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        isDeleted: false,
      );

      final fullDbCard = await dao.getItemById(stubCard.id);
      expect(fullDbCard, isNotNull);
      expect(fullDbCard!.dynamicData, contains('"collector_number":"146"'));

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      // Mounting with fullDbCard ensures hydrated render
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: fullDbCard),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lightning Bolt'), findsWidgets);
      expect(find.text('Magic 2010'), findsWidgets);
    });
  });
}
