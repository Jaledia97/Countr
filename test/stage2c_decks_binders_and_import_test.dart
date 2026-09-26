import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/edit_binder_modal.dart';
import 'package:countr/features/vault/presentation/widgets/vault_import_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = VaultDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createHarness({
    required Widget child,
    List<Override> overrides = const [],
    Size size = const Size(1080, 2400),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        ...overrides,
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Stage 2C: Decks Screen Architecture & DecksDao Querying', () {
    test('1.1: watchDeckSummaries queries Commander art_crop, color identity, card count, completeness & filters soft-deleted', () async {
      final now = DateTime.now();

      // 1. Insert Deck 1 (Active Commander Deck)
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-1'),
          name: const Value('Edgar Markov Aristocrats'),
          format: const Value('Commander'),
          description: const Value('Vampire token drain deck'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );

      // Version 1 (Active)
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const Value('version-1'),
          deckId: const Value('deck-1'),
          versionNumber: const Value(1),
          versionNote: const Value('v1.0'),
          isActive: const Value(true),
          createdAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Vault Item: Edgar Markov (Commander)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-edgar'),
          collectionType: const Value('mtg'),
          name: const Value('Edgar Markov'),
          setOrSeries: const Value('C17'),
          imageUrl: const Value('https://cards.scryfall.io/normal/edgar.jpg'),
          currentMarketPrice: const Value(45.0),
          acquiredPrice: const Value(40.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          isDeleted: const Value(false),
          dynamicData: Value(jsonEncode({
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/edgar.jpg',
            },
            'color_identity': ['W', 'B', 'R'],
          })),
        ),
      );

      // Deck Version Item: Commander Zone
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-1'),
          versionId: const Value('version-1'),
          vaultItemId: const Value('card-edgar'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isDeleted: const Value(false),
        ),
      );

      // Vault Item: Blood Artist (Mainboard)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-blood-artist'),
          collectionType: const Value('mtg'),
          name: const Value('Blood Artist'),
          setOrSeries: const Value('AVR'),
          imageUrl: const Value('https://cards.scryfall.io/normal/blood.jpg'),
          currentMarketPrice: const Value(3.5),
          acquiredPrice: const Value(2.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          isDeleted: const Value(false),
          dynamicData: const Value('{}'),
        ),
      );

      // Deck Version Item: Mainboard
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-2'),
          versionId: const Value('version-1'),
          vaultItemId: const Value('card-blood-artist'),
          quantity: const Value(1),
          boardZone: const Value('mainboard'),
          isDeleted: const Value(false),
        ),
      );

      // 2. Insert Deck 2 (Soft-deleted deck - must be omitted)
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-deleted'),
          name: const Value('Deleted Deck'),
          format: const Value('Modern'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(true),
        ),
      );

      // Query summaries
      final summaries = await dao.getDeckSummaries();

      // Verify soft-deleted deck is omitted
      expect(summaries.length, equals(1));
      final edgarSummary = summaries.first;

      expect(edgarSummary.id, equals('deck-1'));
      expect(edgarSummary.name, equals('Edgar Markov Aristocrats'));
      expect(edgarSummary.format, equals('Commander'));
      expect(edgarSummary.commanderName, equals('Edgar Markov'));
      expect(edgarSummary.commanderArtCrop, equals('https://cards.scryfall.io/art_crop/edgar.jpg'));
      expect(edgarSummary.colorIdentity, equals(['W', 'B', 'R']));
      expect(edgarSummary.cardCount, equals(2));
      expect(edgarSummary.targetCount, equals(100)); // Commander target is 100
      expect(edgarSummary.completeness, equals(0.02)); // 2 / 100
      expect(edgarSummary.assemblyStatus, equals('Draft'));
    });

    testWidgets('1.2: DecksScreen renders Commander card art, color pips, assembly status & format', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-summary-ui'),
          name: const Value('Urza Lord High Artificer'),
          format: const Value('Commander'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const Value('version-urza'),
          deckId: const Value('deck-summary-ui'),
          versionNumber: const Value(1),
          versionNote: const Value('v1.0'),
          isActive: const Value(true),
          createdAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-urza'),
          collectionType: const Value('mtg'),
          name: const Value('Urza, Lord High Artificer'),
          setOrSeries: const Value('MH1'),
          imageUrl: const Value('https://cards.scryfall.io/normal/urza.jpg'),
          currentMarketPrice: const Value(40.0),
          acquiredPrice: const Value(35.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          isDeleted: const Value(false),
          dynamicData: Value(jsonEncode({
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/urza.jpg',
            },
            'color_identity': ['U'],
          })),
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-urza'),
          versionId: const Value('version-urza'),
          vaultItemId: const Value('card-urza'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        createHarness(
          child: const DecksScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Deck Title
      expect(find.text('Urza Lord High Artificer'), findsOneWidget);

      // Verify Format
      expect(find.textContaining('Commander'), findsWidgets);

      // Verify Assembly Status Pill (Draft)
      expect(find.text('Draft'), findsWidgets);

      // Verify Deck Setup Wizard button exists in AppBar
      expect(find.byKey(const Key('deck_setup_wizard_button')), findsOneWidget);
    });
  });

  group('Stage 2C: Deck Setup Wizard (DeckSetupWizardModal)', () {
    testWidgets('2.1: Blank deck creation inserts into SQLite and closes modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DeckSetupWizardModal.show(context),
              child: const Text('Open Wizard'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Wizard
      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Verify Form inputs
      expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_format_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_mode_selector')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_create_button')), findsOneWidget);

      // Fill in Name
      await tester.enterText(find.byKey(const Key('deck_wizard_name_input')), 'Atraxa Proliferation');
      await tester.pumpAndSettle();

      // Tap Create Button
      await tester.tap(find.byKey(const Key('deck_wizard_create_button')));
      await tester.pumpAndSettle();

      // Verify Deck inserted into database
      final decks = await dao.getAllDecks();
      expect(decks.any((d) => d.name == 'Atraxa Proliferation'), isTrue);

      final createdDeck = decks.firstWhere((d) => d.name == 'Atraxa Proliferation');
      expect(createdDeck.format, equals('Commander'));

      // Verify active version was created
      final versions = await dao.getDeckVersions(createdDeck.id);
      expect(versions.length, equals(1));
      expect(versions.first.isActive, isTrue);
    });

    testWidgets('2.2: Import Decklist mode parses text list and creates deck with version items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DeckSetupWizardModal.show(context),
              child: const Text('Open Wizard'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Wizard
      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Enter Deck Name
      await tester.enterText(find.byKey(const Key('deck_wizard_name_input')), 'Burn Aggro');

      // Switch to Import Decklist mode
      await tester.tap(find.text('Import Decklist'));
      await tester.pumpAndSettle();

      // Verify text input appears
      expect(find.byKey(const Key('deck_wizard_import_text_input')), findsOneWidget);

      // Enter card list
      const decklistText = '''
4 Lightning Bolt
4 Lava Spike
2 Eidolon of the Great Revel
''';
      await tester.enterText(find.byKey(const Key('deck_wizard_import_text_input')), decklistText);
      await tester.pumpAndSettle();

      // Tap Create Button
      await tester.tap(find.byKey(const Key('deck_wizard_create_button')));
      await tester.pumpAndSettle();

      // Verify Deck and Items inserted
      final decks = await dao.getAllDecks();
      final burnDeck = decks.firstWhere((d) => d.name == 'Burn Aggro');
      expect(burnDeck, isNotNull);

      final versionItems = await dao.getDeckItems(burnDeck.id);
      expect(versionItems.length, equals(3));
      final totalImportedCards = versionItems.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalImportedCards, equals(10));
    });
  });

  group('Stage 2C: Vault Import Flow ([ Import + ] & VaultImportBottomSheet)', () {
    testWidgets('3.1: VaultScreen features [ Import + ] button (vault_import_button)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createHarness(
          child: const VaultScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check [ Import + ] button exists
      expect(find.byKey(const Key('vault_import_button')), findsOneWidget);
      // Retains backward-compatible add item button
      expect(find.byKey(const Key('vault_add_item_button')), findsOneWidget);
    });

    testWidgets('3.2: VaultImportBottomSheet parses bulk text into destination binder', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed a binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion(
          id: const Value('binder-dest-1'),
          name: const Value('Modern Staples Binder'),
          collectionType: const Value('mtg'),
          createdAt: Value(DateTime.now()),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VaultImportBottomSheet.show(context, targetBinderId: 'binder-dest-1'),
              child: const Text('Open Vault Import'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Vault Import'));
      await tester.pumpAndSettle();

      // Form controls
      expect(find.byKey(const Key('vault_import_text_input')), findsOneWidget);
      expect(find.byKey(const Key('vault_import_binder_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('vault_import_submit_button')), findsOneWidget);

      // Enter bulk cards
      const importText = '''
2 Thoughtseize
4 Fatal Push
1 Ragavan, Nimble Pilferer
''';
      await tester.enterText(find.byKey(const Key('vault_import_text_input')), importText);
      await tester.pumpAndSettle();

      // Live preview count: 3 entries, 7 total cards
      expect(find.textContaining('7 total cards'), findsOneWidget);

      // Submit import
      await tester.tap(find.byKey(const Key('vault_import_submit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 3));

      // Verify cards in database anchored to binder-dest-1
      final binderCards = await dao.getItemsByBinder('binder-dest-1');
      expect(binderCards.length, equals(3));
      final totalCount = binderCards.fold<int>(0, (sum, c) => sum + c.quantity);
      expect(totalCount, equals(7));

      // Outbox SyncQueue entries generated
      final syncQueue = await db.select(db.syncQueue).get();
      expect(syncQueue.where((s) => s.entityType == 'vault_item').length, equals(3));
    });
  });

  group('Stage 2C: Binder Customization & Views (EditBinderModal & BinderDetailScreen)', () {
    testWidgets('4.1: EditBinderModal updates binder name, description, cover art & logs sync entry', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final binder = VaultBinder(
        id: 'binder-custom-test',
        name: 'Legacy Staples',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
        isDeleted: false,
      );
      await db.into(db.vaultBinders).insert(binder);

      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EditBinderModal.show(context, binder),
              child: const Text('Open Edit Binder'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Edit Binder'));
      await tester.pumpAndSettle();

      // Verify inputs
      expect(find.byKey(const Key('edit_binder_name_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_binder_description_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_binder_cover_art_picker')), findsOneWidget);
      expect(find.byKey(const Key('edit_binder_save_button')), findsOneWidget);

      // Update name and description
      await tester.enterText(find.byKey(const Key('edit_binder_name_input')), 'Vintage Power 9 & Duals');
      await tester.enterText(find.byKey(const Key('edit_binder_description_input')), 'Dual lands, Moxen, and high-end vintage pieces.');
      await tester.enterText(find.byKey(const Key('edit_binder_cover_art_input')), 'https://cards.scryfall.io/art_crop/lotus.jpg');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.byKey(const Key('edit_binder_save_button')));
      await tester.pumpAndSettle();

      // Verify database update
      final binders = await dao.getAllBinders();
      final updatedBinder = binders.firstWhere((b) => b.id == 'binder-custom-test');
      expect(updatedBinder.name, equals('Vintage Power 9 & Duals'));

      // Verify SyncQueue outbox entry
      final syncQueue = await db.select(db.syncQueue).get();
      final binderSync = syncQueue.where((s) => s.entityType == 'binder' && s.entityId == 'binder-custom-test').firstOrNull;
      expect(binderSync, isNotNull);
      expect(binderSync!.operation, equals('UPDATE'));

      // Verify metadata getters
      expect(dao.getBinderDescription('binder-custom-test'), equals('Dual lands, Moxen, and high-end vintage pieces.'));
      expect(dao.getBinderCoverArt('binder-custom-test'), equals('https://cards.scryfall.io/art_crop/lotus.jpg'));
    });

    testWidgets('4.2: BinderDetailScreen toggles between 3x3 Grid view (5:7 ratio) and List view', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final binder = VaultBinder(
        id: 'binder-view-toggle',
        name: 'Commander Arsenal',
        collectionType: 'mtg',
        createdAt: now,
        isDeleted: false,
      );
      await db.into(db.vaultBinders).insert(binder);

      // Seed cards into binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-sol-ring'),
          collectionType: const Value('mtg'),
          name: const Value('Sol Ring'),
          setOrSeries: const Value('C21'),
          imageUrl: const Value('https://cards.scryfall.io/normal/solring.jpg'),
          currentMarketPrice: const Value(2.5),
          acquiredPrice: const Value(2.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(3), // > 1 to test quantity badge
          primaryBinderId: const Value('binder-view-toggle'),
          isDeleted: const Value(false),
          dynamicData: Value(jsonEncode({'finish': 'foil'})),
        ),
      );

      // Set description in dao
      await dao.updateBinder('binder-view-toggle', description: 'Essential rocks and staples');

      await tester.pumpWidget(
        createHarness(
          child: BinderDetailScreen(binder: binder),
        ),
      );
      await tester.pumpAndSettle();

      // Check header description
      expect(find.byKey(const Key('binder_detail_description')), findsOneWidget);
      expect(find.text('Essential rocks and staples'), findsOneWidget);

      // Check Edit button exists
      expect(find.byKey(const Key('binder_edit_button')), findsOneWidget);

      // Check View mode toggle button exists
      expect(find.byKey(const Key('binder_view_mode_toggle')), findsOneWidget);

      // Default is 3x3 Grid view: SliverGrid must be present
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(SliverList), findsNothing);

      // Quantity badge on grid tile (3x)
      expect(find.text('3x'), findsOneWidget);

      // Toggle to List view
      await tester.tap(find.byKey(const Key('binder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Now SliverList must be present, SliverGrid absent
      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);

      // Toggle back to 3x3 Grid view
      await tester.tap(find.byKey(const Key('binder_view_mode_toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(SliverList), findsNothing);
    });
  });
}
